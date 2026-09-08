import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database.dart';

/// PLAN Phase 8 — "Backup: ZIP = SQLite snapshot + JSON export; fully local,
/// no cloud lock-in."
///
/// The ZIP contains three entries:
///  * `checkfuchs.sqlite` — a consistent snapshot of the database, taken with
///    `VACUUM INTO` (never a copy of the live, open file). This is the restore
///    source: it re-opens as a normal drift database, so an *older* backup is
///    brought to the current schema by the ordinary migration path.
///  * `backup.json` — a human-readable dump of every table, so the data stays
///    inspectable without any sqlite tooling (no lock-in, honest-data ethos).
///  * `manifest.json` — app id, app version, DB schema version, timestamp.
///
/// The pure byte-level pieces ([buildBackupZipBytes], [restoreBackupZipBytes],
/// [checkBackupManifest]) have no platform-channel dependencies and are
/// exercised directly in tests; [BackupService] adds the share-sheet shell.

/// `app` value in the manifest — refuses foreign fuchs backups politely.
const backupAppId = 'checkfuchs';

/// Entry names inside the backup ZIP.
const backupManifestEntry = 'manifest.json';
const backupSqliteEntry = 'checkfuchs.sqlite';
const backupJsonEntry = 'backup.json';

/// Thrown when a backup was written by a newer app version than this build
/// can read. A [FormatException] subtype so generic format handling still
/// applies, while the import UI can catch it specifically and show a
/// localized "update the app" message instead of the raw exception text.
class BackupVersionException extends FormatException {
  BackupVersionException(int version, int supported)
    : super(
        'Backup schema version $version is newer than this app supports '
        '(max $supported). Update the app, then import again.',
      );
}

/// Build the backup ZIP as bytes. The sqlite snapshot comes from
/// `VACUUM INTO` a temp file — a transactionally consistent copy that is safe
/// to take while the database is open (copying the live file would tear
/// against the WAL).
Future<Uint8List> buildBackupZipBytes(
  AppDatabase db, {
  required DateTime now,
  String appVersion = 'unknown',
}) async {
  // 1) Consistent SQLite snapshot.
  final Uint8List sqliteBytes;
  final tmpDir = await Directory.systemTemp.createTemp('checkfuchs-backup-');
  try {
    final snapshot = File('${tmpDir.path}/$backupSqliteEntry');
    await db.customStatement('VACUUM INTO ?', [snapshot.path]);
    sqliteBytes = await snapshot.readAsBytes();
  } finally {
    await tmpDir.delete(recursive: true);
  }

  // 2) Human-readable JSON dump of every table (raw column values: dates are
  // epoch timestamps, value objects their stored JSON — lossless to read).
  final tables = <String, List<Map<String, Object?>>>{};
  for (final table in db.allTables) {
    final name = table.actualTableName;
    final rows = await db.customSelect('SELECT * FROM "$name"').get();
    tables[name] = [for (final r in rows) r.data];
  }
  final jsonBytes = utf8.encode(
    const JsonEncoder.withIndent('  ').convert({
      'app': backupAppId,
      'schemaVersion': db.schemaVersion,
      'exportedAt': now.toIso8601String(),
      'tables': tables,
    }),
  );

  // 3) Manifest.
  final manifestBytes = utf8.encode(
    jsonEncode({
      'app': backupAppId,
      'appVersion': appVersion,
      'schemaVersion': db.schemaVersion,
      'exportedAt': now.toIso8601String(),
    }),
  );

  final archive = Archive()
    ..addFile(
      ArchiveFile(backupManifestEntry, manifestBytes.length, manifestBytes),
    )
    ..addFile(ArchiveFile(backupSqliteEntry, sqliteBytes.length, sqliteBytes))
    ..addFile(ArchiveFile(backupJsonEntry, jsonBytes.length, jsonBytes));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Parse + validate a backup's manifest against this build. Throws
/// [FormatException] for foreign/damaged files and [BackupVersionException]
/// when the backup's schema is newer than [appSchemaVersion] — an *older*
/// schema passes, because the snapshot runs the normal drift migrations when
/// it is opened during restore.
void checkBackupManifest(
  Map<String, dynamic> manifest, {
  required int appSchemaVersion,
}) {
  if (manifest['app'] != backupAppId) {
    throw const FormatException('Not a Checkfuchs backup.');
  }
  final version = (manifest['schemaVersion'] as num?)?.toInt();
  if (version == null) {
    throw const FormatException('Backup manifest has no schema version.');
  }
  if (version > appSchemaVersion) {
    throw BackupVersionException(version, appSchemaVersion);
  }
}

Map<String, dynamic> _readManifest(Archive archive) {
  final entry = archive.findFile(backupManifestEntry);
  if (entry == null) {
    throw const FormatException('Not a valid backup (no manifest.json).');
  }
  final decoded = jsonDecode(utf8.decode(entry.content as List<int>));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Backup manifest is not a JSON object.');
  }
  return decoded;
}

/// Replace all data in [db] with the contents of a backup ZIP.
///
/// Restore-apply, step by step (no restart needed — the live file is never
/// swapped out from under the open connection):
///  1. Validate the manifest ([checkBackupManifest]) and the presence of the
///     `checkfuchs.sqlite` entry — nothing is touched before this passes.
///  2. Write the snapshot to a temp file and open it as a second, independent
///     drift [AppDatabase]. Opening runs the normal migration chain, so an
///     older backup arrives at the current schema before any row is read.
///  3. Read every table from the snapshot, then, in ONE transaction on the
///     live database, delete all rows and re-insert the snapshot's rows with
///     their original ids (the template/lens/view foreign-key graph survives
///     intact). A failure anywhere rolls the transaction back — the previous
///     data stays.
Future<void> restoreBackupZipBytes(AppDatabase db, List<int> zipBytes) async {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(zipBytes);
  } on ArchiveException {
    throw const FormatException('Not a valid backup (.zip expected).');
  }
  checkBackupManifest(
    _readManifest(archive),
    appSchemaVersion: db.schemaVersion,
  );
  final entry = archive.findFile(backupSqliteEntry);
  if (entry == null) {
    throw const FormatException('Not a valid backup (no checkfuchs.sqlite).');
  }

  final tmpDir = await Directory.systemTemp.createTemp('checkfuchs-restore-');
  try {
    final file = File('${tmpDir.path}/$backupSqliteEntry');
    await file.writeAsBytes(entry.content as List<int>, flush: true);

    // Open the snapshot as its own database: drift migrates an older schema
    // up before we read a single row.
    final src = AppDatabase(NativeDatabase(file));
    final List<TemplateRow> templates;
    final List<TaskRow> tasks;
    final List<LensRow> lenses;
    final List<ViewRow> views;
    final List<TaskLensRow> taskLens;
    final List<ViewLensRow> viewLens;
    final List<TemplateLensRow> templateLens;
    final List<VacationRow> vacations;
    final List<AppSettingsRow> appSettings;
    try {
      templates = await src.select(src.templates).get();
      tasks = await src.select(src.tasks).get();
      lenses = await src.select(src.lenses).get();
      views = await src.select(src.views).get();
      taskLens = await src.select(src.taskLens).get();
      viewLens = await src.select(src.viewLens).get();
      // Opening the backup as an AppDatabase migrated it, so a pre-v10 file
      // has template_lens seeded from its default_lens_id.
      templateLens = await src.select(src.templateLens).get();
      vacations = await src.select(src.vacations).get();
      appSettings = await src.select(src.appSettings).get();
    } finally {
      await src.close();
    }

    await db.transaction(() async {
      // Children before parents (foreign keys are enforced).
      await db.delete(db.taskLens).go();
      await db.delete(db.viewLens).go();
      await db.delete(db.templateLens).go();
      await db.delete(db.tasks).go();
      await db.delete(db.templates).go();
      await db.delete(db.lenses).go();
      await db.delete(db.views).go();
      await db.delete(db.vacations).go();
      await db.delete(db.appSettings).go();
      // Parents before children, original ids kept.
      await db.batch((b) {
        b.insertAll(db.lenses, [for (final r in lenses) r.toCompanion(false)]);
        b.insertAll(db.views, [for (final r in views) r.toCompanion(false)]);
        b.insertAll(db.templates, [
          for (final r in templates) r.toCompanion(false),
        ]);
        b.insertAll(db.tasks, [for (final r in tasks) r.toCompanion(false)]);
        b.insertAll(db.taskLens, [
          for (final r in taskLens) r.toCompanion(false),
        ]);
        b.insertAll(db.viewLens, [
          for (final r in viewLens) r.toCompanion(false),
        ]);
        b.insertAll(db.templateLens, [
          for (final r in templateLens) r.toCompanion(false),
        ]);
        b.insertAll(db.vacations, [
          for (final r in vacations) r.toCompanion(false),
        ]);
        b.insertAll(db.appSettings, [
          for (final r in appSettings) r.toCompanion(false),
        ]);
      });
    });
  } finally {
    await tmpDir.delete(recursive: true);
  }
}

/// Platform shell: builds the ZIP and hands it to the share sheet, or reads a
/// picked .zip back in. File *picking* stays in the UI (mirrors knabberfuchs).
class BackupService {
  BackupService(this.db);
  final AppDatabase db;

  Future<void> shareBackup({String? subject}) async {
    final now = DateTime.now();
    var appVersion = 'unknown';
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // Manifest metadata only — never block an export on it.
    }
    final bytes = await buildBackupZipBytes(
      db,
      now: now,
      appVersion: appVersion,
    );
    // systemTemp is the app cache dir on Android/iOS (the engine sets TMPDIR);
    // share_plus copies the file into its own share cache anyway.
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(now);
    final file = File(
      '${Directory.systemTemp.path}/checkfuchs-backup-$stamp.zip',
    );
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/zip')],
        subject: subject ?? 'Checkfuchs backup',
      ),
    );
  }

  /// Replace all data with the contents of a backup .zip at [path]. Throws
  /// [FormatException] / [BackupVersionException] — see [restoreBackupZipBytes].
  Future<void> restoreFromZip(String path) async {
    await restoreBackupZipBytes(db, await File(path).readAsBytes());
  }
}
