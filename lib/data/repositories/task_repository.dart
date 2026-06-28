import 'package:drift/drift.dart';

import '../../domain/generation.dart';
import '../../domain/task.dart' as domain;
import '../../domain/template.dart' as domain;
import '../db/database.dart';

/// Bridges the drift database and the pure domain engine: maps rows ⇄ domain
/// objects, and persists `reconcileTemplate`'s output. The engine stays pure;
/// all I/O lives here.
class TaskRepository {
  TaskRepository(this.db);

  final AppDatabase db;

  // --- reads -----------------------------------------------------------------

  /// All tasks, newest occurrence first — a reactive stream (drift re-emits on
  /// any write).
  Stream<List<domain.Task>> watchTasks() => (db.select(db.tasks)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch()
      .map((rows) => rows.map(_toTask).toList());

  Future<List<domain.Task>> allTasks() async =>
      (await db.select(db.tasks).get()).map(_toTask).toList();

  // --- writes ----------------------------------------------------------------

  Future<int> createTemplate(domain.Template t) =>
      db.into(db.templates).insert(TemplatesCompanion.insert(
            name: t.name,
            note: Value(t.note),
            recurrence: t.recurrence,
            windowRule: t.windowRule,
            paused: Value(t.paused),
            resumeOn: Value(t.resumeOn),
            createdAt: t.createdAt,
          ));

  Future<int> createTask(domain.Task t) =>
      db.into(db.tasks).insert(_toCompanion(t));

  /// Run the pure engine over every template and persist the changes
  /// (design-concept §3.4). Idempotent — safe to call on every open/resume.
  Future<void> reconcileAll(DateTime now, {bool vacationActive = false}) async {
    final templates = await db.select(db.templates).get();
    for (final row in templates) {
      final template = _toTemplate(row);
      final existing = await (db.select(db.tasks)
            ..where((t) => t.templateId.equals(row.id)))
          .get();
      final result = reconcileTemplate(
        template,
        existing.map(_toTask).toList(),
        now,
        vacationActive: vacationActive,
      );
      for (final task in result.changed) {
        if (task.id == null) {
          await db.into(db.tasks).insert(_toCompanion(task));
        } else {
          await (db.update(db.tasks)..where((t) => t.id.equals(task.id!)))
              .write(_toCompanion(task));
        }
      }
    }
  }

  // --- mapping ---------------------------------------------------------------

  domain.Template _toTemplate(TemplateRow r) => domain.Template(
        id: r.id,
        name: r.name,
        note: r.note,
        recurrence: r.recurrence,
        windowRule: r.windowRule,
        paused: r.paused,
        resumeOn: r.resumeOn,
        createdAt: r.createdAt,
      );

  domain.Task _toTask(TaskRow r) => domain.Task(
        id: r.id,
        templateId: r.templateId,
        occurrence: r.occurrence,
        name: r.name,
        note: r.note,
        status: r.status,
        start: r.windowStart,
        end: r.windowEnd,
        createdAt: r.createdAt,
        resolvedAt: r.resolvedAt,
      );

  TasksCompanion _toCompanion(domain.Task t) => TasksCompanion(
        id: t.id == null ? const Value.absent() : Value(t.id!),
        templateId: Value(t.templateId),
        occurrence: Value(t.occurrence),
        name: Value(t.name),
        note: Value(t.note),
        status: Value(t.status),
        windowStart: Value(t.start),
        windowEnd: Value(t.end),
        createdAt: Value(t.createdAt),
        resolvedAt: Value(t.resolvedAt),
      );
}
