import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:checkfuchs/data/backup/backup_service.dart';
import 'package:checkfuchs/data/db/database.dart';
import 'package:checkfuchs/domain/lens.dart';
import 'package:checkfuchs/domain/recurrence.dart';
import 'package:checkfuchs/domain/task.dart';
import 'package:checkfuchs/domain/window_rule.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seed one row into every table, returning the created ids where relevant.
Future<({int lensId, int viewId, int templateId, int taskId})> seed(
  AppDatabase db,
) async {
  final lensId = await db
      .into(db.lenses)
      .insert(
        LensesCompanion.insert(
          name: 'Morning routine',
          ordering: LensOrdering.manual,
          selection: LensSelection.top,
        ),
      );
  final viewId = await db
      .into(db.views)
      .insert(ViewsCompanion.insert(name: 'Home'));
  final templateId = await db
      .into(db.templates)
      .insert(
        TemplatesCompanion.insert(
          name: 'Brush teeth',
          recurrence: Recurrence.daily(DateTime(2026, 7, 1)),
          windowRule: Slice.morning,
          createdAt: DateTime(2026, 7, 1),
          defaultLensId: Value(lensId),
        ),
      );
  final taskId = await db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          templateId: Value(templateId),
          occurrence: Value(DateTime(2026, 7, 2)),
          name: 'Brush teeth',
          status: TaskStatus.open,
          createdAt: DateTime(2026, 7, 2, 8),
        ),
      );
  await db
      .into(db.taskLens)
      .insert(TaskLensCompanion.insert(taskId: taskId, lensId: lensId));
  await db
      .into(db.viewLens)
      .insert(ViewLensCompanion.insert(viewId: viewId, lensId: lensId));
  await db
      .into(db.vacations)
      .insert(
        VacationsCompanion.insert(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 15),
        ),
      );
  await db
      .into(db.appSettings)
      .insert(
        const AppSettingsCompanion(
          themeModeIndex: Value(1),
          fontIndex: Value(2),
        ),
      );
  return (
    lensId: lensId,
    viewId: viewId,
    templateId: templateId,
    taskId: taskId,
  );
}

/// Craft a ZIP with the given entries (for negative-path tests).
List<int> zipWith({Map<String, Object?>? manifest, List<int>? sqlite}) {
  final archive = Archive();
  if (manifest != null) {
    final bytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile(backupManifestEntry, bytes.length, bytes));
  }
  if (sqlite != null) {
    archive.addFile(ArchiveFile(backupSqliteEntry, sqlite.length, sqlite));
  }
  return ZipEncoder().encode(archive);
}

Map<String, dynamic> entryJson(Archive archive, String name) =>
    jsonDecode(utf8.decode(archive.findFile(name)!.content as List<int>))
        as Map<String, dynamic>;

void main() {
  // Restore legitimately opens a second AppDatabase (the snapshot), and the
  // round-trip tests hold a source + destination pair — drop drift's
  // multiple-instances debug warning.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  group('export', () {
    test('produces a zip with manifest + sqlite + json entries', () async {
      await seed(db);
      final bytes = await buildBackupZipBytes(
        db,
        now: DateTime(2026, 7, 6, 12),
        appVersion: '1.2.3+4',
      );

      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.findFile(backupManifestEntry), isNotNull);
      expect(archive.findFile(backupSqliteEntry), isNotNull);
      expect(archive.findFile(backupJsonEntry), isNotNull);

      final manifest = entryJson(archive, backupManifestEntry);
      expect(manifest['app'], backupAppId);
      expect(manifest['schemaVersion'], db.schemaVersion);
      expect(manifest['appVersion'], '1.2.3+4');
      expect(
        manifest['exportedAt'],
        DateTime(2026, 7, 6, 12).toIso8601String(),
      );

      // The sqlite entry is a real database file, not a torn copy.
      final sqlite = archive.findFile(backupSqliteEntry)!.content as List<int>;
      expect(
        String.fromCharCodes(sqlite.take(15)),
        'SQLite format 3',
        reason: 'VACUUM INTO must produce a valid sqlite file',
      );
    });

    test('JSON export contains the created rows of every table', () async {
      await seed(db);
      final bytes = await buildBackupZipBytes(db, now: DateTime(2026, 7, 6));
      final archive = ZipDecoder().decodeBytes(bytes);
      final json = entryJson(archive, backupJsonEntry);

      final tables = json['tables'] as Map<String, dynamic>;
      expect(
        tables.keys,
        containsAll([
          'templates',
          'tasks',
          'lenses',
          'views',
          'task_lens',
          'view_lens',
          'vacations',
          'app_settings',
        ]),
      );
      expect(
        (tables['tasks'] as List).map((r) => r['name']),
        contains('Brush teeth'),
      );
      expect(
        (tables['lenses'] as List).map((r) => r['name']),
        contains('Morning routine'),
      );
      expect((tables['views'] as List).map((r) => r['name']), contains('Home'));
      expect(tables['vacations'], hasLength(1));
      expect((tables['app_settings'] as List).single['font_index'], 2);
    });
  });

  group('restore', () {
    test('round-trip replaces destination data with the backup', () async {
      final ids = await seed(db);
      final bytes = await buildBackupZipBytes(db, now: DateTime(2026, 7, 6));

      // Destination pre-seeded with data that must be gone afterwards.
      final dest = AppDatabase(NativeDatabase.memory());
      addTearDown(dest.close);
      await dest
          .into(dest.tasks)
          .insert(
            TasksCompanion.insert(
              name: 'Old task',
              status: TaskStatus.done,
              createdAt: DateTime(2020),
            ),
          );

      await restoreBackupZipBytes(dest, bytes);

      final tasks = await dest.select(dest.tasks).get();
      expect(tasks.map((t) => t.name), ['Brush teeth']);
      expect(tasks.single.id, ids.taskId, reason: 'ids survive the restore');
      expect(tasks.single.templateId, ids.templateId);

      final template = await dest.select(dest.templates).getSingle();
      expect(template.name, 'Brush teeth');
      expect(template.defaultLensId, ids.lensId);
      final slice = template.windowRule as Slice;
      expect(slice.from, Duration.zero);
      expect(slice.to, const Duration(hours: 12));

      final link = await dest.select(dest.taskLens).getSingle();
      expect((link.taskId, link.lensId), (ids.taskId, ids.lensId));
      final viewLink = await dest.select(dest.viewLens).getSingle();
      expect((viewLink.viewId, viewLink.lensId), (ids.viewId, ids.lensId));

      final vacation = await dest.select(dest.vacations).getSingle();
      expect(vacation.start, DateTime(2026, 8, 1));

      final settings = await dest.select(dest.appSettings).getSingle();
      expect(settings.themeModeIndex, 1);
      expect(settings.fontIndex, 2);
    });

    test('refuses a backup with a newer schema version', () async {
      await seed(db);
      final good = await buildBackupZipBytes(db, now: DateTime(2026, 7, 6));
      final sqlite =
          ZipDecoder().decodeBytes(good).findFile(backupSqliteEntry)!.content
              as List<int>;
      final newer = zipWith(
        manifest: {'app': backupAppId, 'schemaVersion': db.schemaVersion + 1},
        sqlite: sqlite,
      );

      final dest = AppDatabase(NativeDatabase.memory());
      addTearDown(dest.close);
      await dest
          .into(dest.tasks)
          .insert(
            TasksCompanion.insert(
              name: 'Untouched',
              status: TaskStatus.open,
              createdAt: DateTime(2026),
            ),
          );

      await expectLater(
        restoreBackupZipBytes(dest, newer),
        throwsA(isA<BackupVersionException>()),
      );
      final tasks = await dest.select(dest.tasks).get();
      expect(tasks.map((t) => t.name), [
        'Untouched',
      ], reason: 'nothing touched');
    });

    test('rejects zips without manifest, wrong app, or missing sqlite', () {
      expect(
        () => restoreBackupZipBytes(db, zipWith(sqlite: [1, 2, 3])),
        throwsFormatException,
      );
      expect(
        () => restoreBackupZipBytes(
          db,
          zipWith(
            manifest: {'app': 'knabberfuchs', 'schemaVersion': 1},
            sqlite: [1, 2, 3],
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => restoreBackupZipBytes(
          db,
          zipWith(manifest: {'app': backupAppId, 'schemaVersion': 1}),
        ),
        throwsFormatException,
      );
      expect(
        () => restoreBackupZipBytes(db, utf8.encode('not a zip at all')),
        throwsFormatException,
      );
    });
  });

  group('checkBackupManifest', () {
    test('newer schema refused, same or older accepted', () {
      expect(
        () => checkBackupManifest({
          'app': backupAppId,
          'schemaVersion': 10,
        }, appSchemaVersion: 9),
        throwsA(isA<BackupVersionException>()),
      );
      checkBackupManifest({
        'app': backupAppId,
        'schemaVersion': 9,
      }, appSchemaVersion: 9); // no throw
      checkBackupManifest({
        'app': backupAppId,
        'schemaVersion': 1,
      }, appSchemaVersion: 9); // older is fine — drift migrations run on open
    });

    test('missing schemaVersion or foreign app id is a FormatException', () {
      expect(
        () => checkBackupManifest({'app': backupAppId}, appSchemaVersion: 9),
        throwsFormatException,
      );
      expect(
        () => checkBackupManifest({
          'app': 'somethingelse',
          'schemaVersion': 1,
        }, appSchemaVersion: 9),
        throwsFormatException,
      );
    });
  });
}
