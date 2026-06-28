import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
}

/// The Task — the only object with a completion status (§2). `windowStart`/`End`
/// map to the domain's `start`/`end` (avoids the SQL keywords).
@DataClassName('TaskRow')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get templateId =>
      integer().nullable().references(Templates, #id)();
  DateTimeColumn get occurrence => dateTime().nullable()();
  TextColumn get name => text()();
  TextColumn get note => text().nullable()();
  IntColumn get status => intEnum<TaskStatus>()();
  DateTimeColumn get windowStart => dateTime().nullable()();
  DateTimeColumn get windowEnd => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
}

@DriftDatabase(tables: [Templates, Tasks])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// The on-device database for the running app.
  AppDatabase.open() : super(driftDatabase(name: 'checkfuchs'));

  @override
  int get schemaVersion => 1;
}
