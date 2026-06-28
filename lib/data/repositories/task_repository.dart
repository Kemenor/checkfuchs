import 'package:drift/drift.dart';

import '../../domain/generation.dart';
import '../../domain/recurrence.dart';
import '../../domain/task.dart' as domain;
import '../../domain/template.dart' as domain;
import '../../domain/window_rule.dart';
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

  Future<int> createTemplate(domain.Template t, {int? defaultLensId}) async {
    final lensId = defaultLensId ?? await _defaultLensId();
    return db.into(db.templates).insert(TemplatesCompanion.insert(
          name: t.name,
          note: Value(t.note),
          recurrence: t.recurrence,
          windowRule: t.windowRule,
          paused: Value(t.paused),
          resumeOn: Value(t.resumeOn),
          createdAt: t.createdAt,
          defaultLensId: Value(lensId),
        ));
  }

  Future<int> createTask(domain.Task t, {int? lensId}) async {
    final id = await db.into(db.tasks).insert(_toCompanion(t));
    final lid = lensId ?? await _defaultLensId();
    if (lid != null) await addMembership(id, lid, t.createdAt);
    return id;
  }

  /// The default lens new tasks join when none is specified — the first lens.
  Future<int?> _defaultLensId() async => (await (db.select(db.lenses)
            ..orderBy([(l) => OrderingTerm.asc(l.id)])
            ..limit(1))
          .getSingleOrNull())
      ?.id;

  Future<void> addMembership(int taskId, int lensId, DateTime surfacedAt) =>
      db.into(db.taskLens).insert(
            TaskLensCompanion.insert(
                taskId: taskId, lensId: lensId, surfacedAt: Value(surfacedAt)),
            mode: InsertMode.insertOrIgnore,
          );

  /// Tap-the-ring / swipe Done. Applies the domain transition (no-op if not
  /// currently completable), persists, then reconciles so the next instance is
  /// generated immediately.
  Future<void> completeTask(domain.Task task, DateTime now) async {
    if (task.id == null || !domain.canComplete(task, now)) return;
    await _writeTask(domain.complete(task, now));
    await reconcileAll(now);
  }

  /// Swipe Skip — declines this instance, then reconciles.
  Future<void> skipTask(domain.Task task, DateTime now) async {
    if (task.id == null || !domain.canSkip(task, now)) return;
    await _writeTask(domain.skip(task, now));
    await reconcileAll(now);
  }

  Future<void> _writeTask(domain.Task t) =>
      (db.update(db.tasks)..where((x) => x.id.equals(t.id!)))
          .write(_toCompanion(t));

  Future<void> renameTask(int id, String name) =>
      (db.update(db.tasks)..where((t) => t.id.equals(id)))
          .write(TasksCompanion(name: Value(name)));

  /// Delete a single Task (this occurrence).
  Future<void> deleteTask(int id) =>
      (db.delete(db.tasks)..where((t) => t.id.equals(id))).go();

  /// Delete a whole series — the Template and every Task it generated.
  Future<void> deleteTemplate(int templateId) async {
    await (db.delete(db.tasks)..where((t) => t.templateId.equals(templateId)))
        .go();
    await (db.delete(db.templates)..where((t) => t.id.equals(templateId))).go();
  }

  /// Turn a one-off into a series (§3.6): create the Template, drop the original
  /// one-off, and reconcile so the first generated instance takes its place.
  Future<void> turnIntoSeries(domain.Task task, Recurrence recurrence,
      WindowRule windowRule, DateTime now) async {
    await createTemplate(domain.Template(
      name: task.name,
      note: task.note,
      recurrence: recurrence,
      windowRule: windowRule,
      createdAt: now,
    ));
    if (task.id != null) await deleteTask(task.id!);
    await reconcileAll(now);
  }

  /// Edit a series prospectively (§5.2): update the Template's recurrence/window;
  /// reconcile leaves the running instance and applies the change from the next.
  Future<void> updateTemplateConfig(int templateId, Recurrence recurrence,
      WindowRule windowRule, DateTime now) async {
    await (db.update(db.templates)..where((t) => t.id.equals(templateId))).write(
        TemplatesCompanion(
            recurrence: Value(recurrence), windowRule: Value(windowRule)));
    await reconcileAll(now);
  }

  /// Stop a series repeating: delete the Template but keep its existing Tasks as
  /// standalone one-offs.
  Future<void> stopRepeating(int templateId) async {
    await (db.update(db.tasks)..where((t) => t.templateId.equals(templateId)))
        .write(const TasksCompanion(templateId: Value(null)));
    await (db.delete(db.templates)..where((t) => t.id.equals(templateId))).go();
  }

  // --- pause & vacation (§3.5, §6) ---------------------------------------------

  Future<void> pauseTemplate(int templateId, bool paused,
          {DateTime? resumeOn}) =>
      (db.update(db.templates)..where((t) => t.id.equals(templateId))).write(
          TemplatesCompanion(
              paused: Value(paused), resumeOn: Value(resumeOn)));

  Future<bool> isTemplatePaused(int templateId) async {
    final row = await (db.select(db.templates)
          ..where((t) => t.id.equals(templateId)))
        .getSingleOrNull();
    return row?.paused ?? false;
  }

  /// True when [now] falls inside any vacation period (treadmill paused, §6).
  Future<bool> isOnVacation(DateTime now) async {
    final rows = await db.select(db.vacations).get();
    return rows
        .any((v) => !now.isBefore(v.start) && !now.isAfter(v.end));
  }

  Stream<List<VacationRow>> watchVacations() => (db.select(db.vacations)
        ..orderBy([(v) => OrderingTerm.asc(v.start)]))
      .watch();

  Future<int> addVacation(DateTime start, DateTime end) =>
      db.into(db.vacations).insert(
          VacationsCompanion.insert(start: start, end: end));

  Future<void> deleteVacation(int id) =>
      (db.delete(db.vacations)..where((v) => v.id.equals(id))).go();

  Future<({Recurrence recurrence, WindowRule windowRule})?> templateConfig(
      int templateId) async {
    final row = await (db.select(db.templates)
          ..where((t) => t.id.equals(templateId)))
        .getSingleOrNull();
    return row == null
        ? null
        : (recurrence: row.recurrence, windowRule: row.windowRule);
  }

  /// Run the pure engine over every template and persist the changes
  /// (design-concept §3.4). Idempotent — safe to call on every open/resume.
  Future<void> reconcileAll(DateTime now, {bool? vacationActive}) async {
    final vac = vacationActive ?? await isOnVacation(now);
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
        vacationActive: vac,
      );
      for (final task in result.changed) {
        if (task.id == null) {
          final newId = await db.into(db.tasks).insert(_toCompanion(task));
          if (row.defaultLensId != null) {
            await addMembership(newId, row.defaultLensId!, now);
          }
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
