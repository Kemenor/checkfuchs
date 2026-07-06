import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/lens.dart';
import '../../domain/notification.dart';
import '../../domain/recurrence.dart';
import '../../domain/task.dart';
import '../../domain/window_rule.dart';
import 'converters.dart';

part 'database.g.dart';

/// The recurring factory (design-concept §3). Complex value objects
/// (recurrence, window rule) ride JSON text columns via [TypeConverter]s.
@DataClassName('TemplateRow')
class Templates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get note => text().nullable()();
  TextColumn get recurrence => text().map(const RecurrenceConverter())();
  TextColumn get windowRule => text().map(const WindowRuleConverter())();
  BoolColumn get paused => boolean().withDefault(const Constant(false))();
  DateTimeColumn get resumeOn => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Default reminders stamped onto generated instances (§2.4), JSON list.
  TextColumn get notifications => text()
      .map(const NotificationListConverter())
      .withDefault(const Constant('[]'))();

  /// The Lens generated instances join by default (§4.2 stamping). Set to null
  /// if its lens is deleted.
  IntColumn get defaultLensId => integer().nullable().references(
    Lenses,
    #id,
    onDelete: KeyAction.setNull,
  )();
}

/// The Task — the only object with a completion status (§2). `windowStart`/`End`
/// map to the domain's `start`/`end` (avoids the SQL keywords).
@DataClassName('TaskRow')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get templateId => integer().nullable().references(Templates, #id)();
  DateTimeColumn get occurrence => dateTime().nullable()();
  TextColumn get name => text()();
  TextColumn get note => text().nullable()();
  IntColumn get status => intEnum<TaskStatus>()();
  DateTimeColumn get windowStart => dateTime().nullable()();
  DateTimeColumn get windowEnd => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  /// Per-instance reminders (§2.4), JSON list.
  TextColumn get notifications => text()
      .map(const NotificationListConverter())
      .withDefault(const Constant('[]'))();
}

/// A Lens — pure presentation (§4). `period` rides the recurrence converter
/// (null = continuous).
@DataClassName('LensRow')
class Lenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get showCount => integer().withDefault(const Constant(-1))();
  IntColumn get ordering => intEnum<LensOrdering>()();
  IntColumn get selection => intEnum<LensSelection>()();
  TextColumn get period => text().map(const RecurrenceConverter()).nullable()();
  IntColumn get dormantAfter => integer().nullable()();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();
}

/// A View — the screen layer (§4.6). `icon` is a stable slug into the curated
/// set in `ui/view_icons.dart` (the bottom navigation bar needs one per View).
@DataClassName('ViewRow')
class Views extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();
  TextColumn get icon => text().withDefault(const Constant('home'))();
}

/// Task↔Lens membership (§4.2): per-pair order + the two raw timestamps the
/// cyclical behaviours derive from — `surfacedAt` (last entered the shown set;
/// null = never shown) and `passedAt` (last Pass; only counts within the
/// period it was made in, so no per-rollover reset is needed).
@DataClassName('TaskLensRow')
class TaskLens extends Table {
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get lensId =>
      integer().references(Lenses, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get surfacedAt => dateTime().nullable()();
  DateTimeColumn get passedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {taskId, lensId};
}

/// View↔Lens membership (§4.6): per-pair order + statusFilter (bitmask of
/// terminal states to also show — done=1, skipped=2, missed=4; 0 = open-only).
@DataClassName('ViewLensRow')
class ViewLens extends Table {
  IntColumn get viewId =>
      integer().references(Views, #id, onDelete: KeyAction.cascade)();
  IntColumn get lensId =>
      integer().references(Lenses, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get statusFilter => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {viewId, lensId};
}

/// App-level vacation periods (§6).
@DataClassName('VacationRow')
class Vacations extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get end => dateTime()();
}

/// Singleton app settings (theme override + typeface). Stored as plain indices
/// (ThemeMode.values / FuchsbauFont.values) to avoid coupling the schema to the
/// enums.
@DataClassName('AppSettingsRow')
class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get themeModeIndex => integer().withDefault(const Constant(0))();
  IntColumn get fontIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Templates,
    Tasks,
    Lenses,
    Views,
    TaskLens,
    ViewLens,
    Vacations,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// The on-device database for the running app.
  AppDatabase.open() : super(driftDatabase(name: 'checkfuchs'));

  @override
  int get schemaVersion => 6;

  /// Whether [table].[column] already exists — migration steps are guarded on
  /// the *actual* schema, not just `from`. Two reasons: `m.createTable` in an
  /// early branch creates the table in its **current** shape (so a later
  /// branch's `addColumn` for the same column would collide), and SQLite does
  /// not run `onUpgrade` in a transaction, so a crash mid-migration persists
  /// the DDL without bumping `user_version` — the guards make every re-run
  /// heal such a half-migrated database instead of wedging on it.
  Future<bool> _columnExists(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.any((r) => r.data['name'] == column);
  }

  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    if (!await _columnExists(table.actualTableName, column.name)) {
      await m.addColumn(table, column);
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // createTable is CREATE TABLE IF NOT EXISTS, and creates the
        // *current* shape — later branches must not touch these tables.
        await m.createTable(lenses);
        await m.createTable(views);
        await m.createTable(taskLens);
        await m.createTable(viewLens);
        await m.createTable(vacations);
        await _addColumnIfMissing(m, templates, templates.defaultLensId);
      }
      if (from < 3) {
        await m.createTable(appSettings);
      }
      if (from < 4) {
        // passedThisPeriod (bool) → passedAt (timestamp): "passed" is now a
        // raw fact scoped to its period by derivation, not a stored flag.
        // Only applies when task_lens still has its pre-v4 shape.
        await _addColumnIfMissing(m, taskLens, taskLens.passedAt);
        if (await _columnExists('task_lens', 'passed_this_period')) {
          await customStatement(
            'ALTER TABLE task_lens DROP COLUMN passed_this_period',
          );
        }
      }
      if (from < 5) {
        // Reminders (Phase 5): the notifications JSON columns.
        await _addColumnIfMissing(m, templates, templates.notifications);
        await _addColumnIfMissing(m, tasks, tasks.notifications);
      }
      if (from < 6) {
        // Bottom navigation bar: per-View icon slug.
        await _addColumnIfMissing(m, views, views.icon);
      }
    },
    // SQLite ships with foreign keys OFF; without this every onDelete
    // cascade/setNull declared above is silently unenforced.
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
