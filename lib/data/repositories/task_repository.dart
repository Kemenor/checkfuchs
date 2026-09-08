import 'package:drift/drift.dart';

import '../../domain/generation.dart';
import '../../domain/notification.dart';
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

  /// All tasks, newest first (by creation, id as a stable tiebreak — one
  /// back-fill pass stamps several instances with the same `createdAt`) — a
  /// reactive stream (drift re-emits on any write).
  Stream<List<domain.Task>> watchTasks() =>
      (db.select(db.tasks)..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ]))
          .watch()
          .map((rows) => rows.map(_toTask).toList());

  Future<List<domain.Task>> allTasks() async =>
      (await db.select(db.tasks).get()).map(_toTask).toList();

  Future<domain.Task?> taskById(int id) async {
    final row = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toTask(row);
  }

  /// All instances of one series — the analytics source (§8).
  Future<List<domain.Task>> tasksForTemplate(int templateId) async =>
      (await (db.select(
            db.tasks,
          )..where((t) => t.templateId.equals(templateId))).get())
          .map(_toTask)
          .toList();

  // --- writes ----------------------------------------------------------------

  /// Create a series. Its instances join [lensIds] (or the single
  /// [defaultLensId], or the app default lens when neither is given).
  /// `templates.default_lens_id` is mirrored with the first lens for the
  /// legacy column's sake; `template_lens` is what generation reads.
  Future<int> createTemplate(
    domain.Template t, {
    int? defaultLensId,
    Set<int>? lensIds,
  }) => db.transaction(() async {
    final ids = await _resolveLensIds(lensIds, defaultLensId);
    final id = await db
        .into(db.templates)
        .insert(
          TemplatesCompanion.insert(
            name: t.name,
            note: Value(t.note),
            recurrence: t.recurrence,
            windowRule: t.windowRule,
            paused: Value(t.paused),
            resumeOn: Value(t.resumeOn),
            createdAt: t.createdAt,
            defaultLensId: Value(ids.firstOrNull),
            notifications: Value(t.notifications),
          ),
        );
    for (final lid in ids) {
      await _addTemplateMembership(id, lid);
    }
    return id;
  });

  Future<int> createTask(domain.Task t, {int? lensId, Set<int>? lensIds}) =>
      db.transaction(() async {
        final id = await db.into(db.tasks).insert(_toCompanion(t));
        for (final lid in await _resolveLensIds(lensIds, lensId)) {
          await addMembership(id, lid);
        }
        return id;
      });

  /// Explicit set wins; a single id next; the app default last.
  Future<List<int>> _resolveLensIds(Set<int>? ids, int? single) async {
    if (ids != null && ids.isNotEmpty) return ids.toList()..sort();
    final lid = single ?? await _defaultLensId();
    return [?lid];
  }

  Future<void> _addTemplateMembership(int templateId, int lensId) => db
      .into(db.templateLens)
      .insert(
        TemplateLensCompanion.insert(templateId: templateId, lensId: lensId),
        mode: InsertMode.insertOrIgnore,
      );

  /// The lenses a series' new instances join.
  Future<Set<int>> templateLensIds(int templateId) async => {
    for (final r in await (db.select(
      db.templateLens,
    )..where((m) => m.templateId.equals(templateId))).get())
      r.lensId,
  };

  /// The default lens new tasks join when none is specified — the first lens.
  Future<int?> _defaultLensId() async =>
      (await (db.select(db.lenses)
                ..orderBy([(l) => OrderingTerm.asc(l.id)])
                ..limit(1))
              .getSingleOrNull())
          ?.id;

  /// Join a lens. `surfacedAt` stays null — it means "never yet shown" and is
  /// stamped by [ViewRepository.refreshSurfaced] when the member actually
  /// enters a shown set (dormancy must not accrue for members never displayed).
  Future<void> addMembership(int taskId, int lensId) => db
      .into(db.taskLens)
      .insert(
        TaskLensCompanion.insert(taskId: taskId, lensId: lensId),
        mode: InsertMode.insertOrIgnore,
      );

  /// The lenses a task currently lives in.
  Future<Set<int>> taskLensIds(int taskId) async => {
    for (final r in await (db.select(
      db.taskLens,
    )..where((m) => m.taskId.equals(taskId))).get())
      r.lensId,
  };

  /// The first lens a task lives in (lowest id) — convenience for callers
  /// that only need *a* bucket.
  Future<int?> taskLensId(int taskId) async {
    final ids = await taskLensIds(taskId);
    return ids.isEmpty ? null : (ids.toList()..sort()).first;
  }

  /// Replace a one-off's memberships with [lensIds].
  Future<void> setTaskLenses(int taskId, Set<int> lensIds) =>
      db.transaction(() async {
        await (db.delete(
          db.taskLens,
        )..where((m) => m.taskId.equals(taskId))).go();
        for (final lid in lensIds) {
          await addMembership(taskId, lid);
        }
      });

  /// Move a one-off into a single lens.
  Future<void> setTaskLens(int taskId, int lensId) =>
      setTaskLenses(taskId, {lensId});

  /// Replace a whole series' lenses: future instances follow via
  /// `template_lens`, and every existing instance's memberships are replaced
  /// too so the lens pools (and their history drill-ins) stay coherent.
  Future<void> setTemplateLenses(
    int templateId,
    Set<int> lensIds,
  ) => db.transaction(() async {
    final sorted = lensIds.toList()..sort();
    await (db.update(db.templates)..where((t) => t.id.equals(templateId)))
        .write(TemplatesCompanion(defaultLensId: Value(sorted.firstOrNull)));
    await (db.delete(
      db.templateLens,
    )..where((m) => m.templateId.equals(templateId))).go();
    for (final lid in sorted) {
      await _addTemplateMembership(templateId, lid);
    }
    final rows = await (db.select(
      db.tasks,
    )..where((t) => t.templateId.equals(templateId))).get();
    for (final r in rows) {
      await (db.delete(db.taskLens)..where((m) => m.taskId.equals(r.id))).go();
      for (final lid in sorted) {
        await addMembership(r.id, lid);
      }
    }
  });

  /// Move a whole series into a single lens.
  Future<void> setTemplateLens(int templateId, int lensId) =>
      setTemplateLenses(templateId, {lensId});

  /// Pass (§4.4) — "not this one now, show me another this period". Purely
  /// presentational: recorded on the membership, never touches task status.
  Future<void> passTask(int taskId, int lensId, DateTime now) =>
      (db.update(db.taskLens)
            ..where((m) => m.taskId.equals(taskId) & m.lensId.equals(lensId)))
          .write(TaskLensCompanion(passedAt: Value(now)));

  /// Tap-the-ring / swipe Done. Applies the domain transition (no-op if not
  /// currently completable), persists, then reconciles so the next instance is
  /// generated immediately.
  Future<void> completeTask(domain.Task task, DateTime now) async {
    if (task.id == null || !domain.canComplete(task, now)) return;
    final done = domain.complete(task, now);
    await _writeStatus(task.id!, done.status, done.resolvedAt);
    await reconcileAll(now);
  }

  /// Swipe Skip — declines this instance, then reconciles.
  Future<void> skipTask(domain.Task task, DateTime now) async {
    if (task.id == null || !domain.canSkip(task, now)) return;
    final skipped = domain.skip(task, now);
    await _writeStatus(task.id!, skipped.status, skipped.resolvedAt);
    await reconcileAll(now);
  }

  /// Status transitions write only `status` + `resolvedAt` — writing the full
  /// row from the in-memory Task would clobber a concurrent field edit (e.g. a
  /// rename landing between the UI capturing the Task and the swipe).
  Future<void> _writeStatus(
    int id,
    domain.TaskStatus status,
    DateTime? resolvedAt,
  ) => (db.update(db.tasks)..where((x) => x.id.equals(id))).write(
    TasksCompanion(status: Value(status), resolvedAt: Value(resolvedAt)),
  );

  Future<void> renameTask(int id, String name) => (db.update(
    db.tasks,
  )..where((t) => t.id.equals(id))).write(TasksCompanion(name: Value(name)));

  /// Edit a one-off's window edges (null = unbounded on that side).
  Future<void> setTaskWindow(int id, DateTime? start, DateTime? end) =>
      (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(windowStart: Value(start), windowEnd: Value(end)),
      );

  /// Edit this instance's reminders (§2.4).
  Future<void> setTaskNotifications(int id, List<TaskNotification> n) =>
      (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(notifications: Value(n)),
      );

  /// Edit a series' default reminders; the current open/pending instances pick
  /// them up too (a reminder change should not wait a day to take effect).
  Future<void> setTemplateNotifications(
    int templateId,
    List<TaskNotification> n,
  ) => db.transaction(() async {
    await (db.update(db.templates)..where((t) => t.id.equals(templateId)))
        .write(TemplatesCompanion(notifications: Value(n)));
    await (db.update(db.tasks)..where(
          (t) =>
              t.templateId.equals(templateId) &
              t.status.equals(domain.TaskStatus.open.index),
        ))
        .write(TasksCompanion(notifications: Value(n)));
  });

  /// Delete a single Task (this occurrence).
  Future<void> deleteTask(int id) =>
      (db.delete(db.tasks)..where((t) => t.id.equals(id))).go();

  /// Delete a whole series — the Template and every Task it generated.
  Future<void> deleteTemplate(int templateId) => db.transaction(() async {
    await (db.delete(
      db.tasks,
    )..where((t) => t.templateId.equals(templateId))).go();
    await (db.delete(db.templates)..where((t) => t.id.equals(templateId))).go();
  });

  /// Turn a one-off into a series (§3.6): create the Template, drop the original
  /// one-off, and reconcile so the first generated instance takes its place.
  /// The one-off's lens membership carries over — a task living in a custom
  /// lens must not jump to the global default when it becomes a series.
  Future<void> turnIntoSeries(
    domain.Task task,
    Recurrence recurrence,
    WindowRule windowRule,
    DateTime now,
  ) => db.transaction(() async {
    final lensIds = task.id == null ? <int>{} : await taskLensIds(task.id!);
    await createTemplate(
      domain.Template(
        name: task.name,
        note: task.note,
        recurrence: recurrence,
        windowRule: windowRule,
        createdAt: now,
        // The one-off's reminders become the series defaults.
        notifications: task.notifications,
      ),
      lensIds: lensIds,
    );
    if (task.id != null) await deleteTask(task.id!);
    await reconcileAll(now);
  });

  /// Edit a series prospectively (§5.2): update the Template's recurrence/window;
  /// reconcile leaves the running instance and applies the change from the next.
  Future<void> updateTemplateConfig(
    int templateId,
    Recurrence recurrence,
    WindowRule windowRule,
    DateTime now,
  ) async {
    await (db.update(
      db.templates,
    )..where((t) => t.id.equals(templateId))).write(
      TemplatesCompanion(
        recurrence: Value(recurrence),
        windowRule: Value(windowRule),
      ),
    );
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

  /// Pause or resume a series. Resuming stamps `resumeOn` with [now] — the
  /// engine's generation floor — and reconciles immediately, so the paused
  /// stretch is skipped over instead of back-filled as a wall of Misses.
  Future<void> pauseTemplate(
    int templateId,
    bool paused,
    DateTime now, {
    DateTime? resumeOn,
  }) => db.transaction(() async {
    await (db.update(
      db.templates,
    )..where((t) => t.id.equals(templateId))).write(
      TemplatesCompanion(
        paused: Value(paused),
        resumeOn: Value(paused ? resumeOn : now),
      ),
    );
    if (!paused) await reconcileAll(now);
  });

  Future<bool> isTemplatePaused(int templateId) async {
    final row = await (db.select(
      db.templates,
    )..where((t) => t.id.equals(templateId))).getSingleOrNull();
    return row?.paused ?? false;
  }

  /// True when [now] falls inside any vacation period (treadmill paused, §6).
  Future<bool> isOnVacation(DateTime now) async {
    final rows = await db.select(db.vacations).get();
    return rows.any((v) => !now.isBefore(v.start) && !now.isAfter(v.end));
  }

  Stream<List<VacationRow>> watchVacations() => (db.select(
    db.vacations,
  )..orderBy([(v) => OrderingTerm.asc(v.start)])).watch();

  Future<int> addVacation(DateTime start, DateTime end) => db
      .into(db.vacations)
      .insert(VacationsCompanion.insert(start: start, end: end));

  Future<void> deleteVacation(int id) =>
      (db.delete(db.vacations)..where((v) => v.id.equals(id))).go();

  Future<({Recurrence recurrence, WindowRule windowRule})?> templateConfig(
    int templateId,
  ) async {
    final row = await (db.select(
      db.templates,
    )..where((t) => t.id.equals(templateId))).getSingleOrNull();
    return row == null
        ? null
        : (recurrence: row.recurrence, windowRule: row.windowRule);
  }

  /// Run the pure engine over every template and persist the changes
  /// (design-concept §3.4). Also expires standalone one-offs whose window has
  /// passed — they have no template, so nothing else would ever Miss them.
  /// Idempotent, and transactional so concurrent invocations serialise instead
  /// of double-inserting, and a crash can't leave a task without its
  /// membership row.
  Future<void> reconcileAll(DateTime now) => db.transaction(() async {
    final vacations = await vacationPeriods();
    final templates = await db.select(db.templates).get();
    for (final row in templates) {
      final template = _toTemplate(row);
      final existing = await (db.select(
        db.tasks,
      )..where((t) => t.templateId.equals(row.id))).get();
      final result = reconcileTemplate(
        template,
        existing.map(_toTask).toList(),
        now,
        vacations: vacations,
      );
      final lensIds = await templateLensIds(row.id);
      for (final task in result.changed) {
        if (task.id == null) {
          final newId = await db.into(db.tasks).insert(_toCompanion(task));
          for (final lid in lensIds) {
            await addMembership(newId, lid);
          }
        } else {
          await _writeStatus(task.id!, task.status, task.resolvedAt);
        }
      }
    }

    // Standalone one-offs: expiry sweep (hard deadlines pass even on
    // vacation, §6 — only the recurring treadmill is gated).
    final standalone =
        await (db.select(db.tasks)..where(
              (t) =>
                  t.templateId.isNull() &
                  t.status.equals(domain.TaskStatus.open.index),
            ))
            .get();
    for (final row in standalone) {
      final missed = domain.expireIfDue(_toTask(row), now);
      if (missed != null) {
        await _writeStatus(row.id, missed.status, missed.resolvedAt);
      }
    }
  });

  /// All vacation rows as engine periods.
  Future<List<DatePeriod>> vacationPeriods() async {
    final rows = await db.select(db.vacations).get();
    return [for (final v in rows) (start: v.start, end: v.end)];
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
    notifications: r.notifications,
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
    notifications: r.notifications,
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
    notifications: Value(t.notifications),
  );
}
