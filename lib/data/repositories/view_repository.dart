import 'package:drift/drift.dart';

import '../../domain/derive.dart';
import '../../domain/lens.dart';
import '../../domain/task.dart' as domain;
import '../db/database.dart';

/// One lens as rendered inside a View: the shown tasks (open, projected) plus
/// the optional terminal tasks the View's statusFilter opts in, and the full
/// member counts for the text-breakdown header.
class LensSection {
  LensSection({
    required this.lens,
    required this.shown,
    required this.doneCount,
    required this.missedCount,
    required this.openCount,
  });

  final LensRow lens;
  final List<domain.Task> shown;
  final int doneCount;
  final int missedCount;
  final int openCount;
}

class ViewState {
  ViewState({required this.view, required this.sections});
  final ViewRow view;
  final List<LensSection> sections;
}

const _showDone = 1, _showSkipped = 2, _showMissed = 4;

/// Lens/View persistence + the derive-driven view state (Phase 4). The
/// projection itself is the pure, tested `domain/derive.dart`.
class ViewRepository {
  ViewRepository(this.db);
  final AppDatabase db;

  Stream<List<ViewRow>> watchViews() => (db.select(db.views)
        ..orderBy([(v) => OrderingTerm.asc(v.sortIndex)]))
      .watch();

  /// First-run defaults: a "Home" View showing one continuous "All tasks" Lens.
  /// Returns the default lens id (new tasks join it). Idempotent.
  Future<int> seedDefaults() async {
    final existing = await db.select(db.lenses).get();
    if (existing.isNotEmpty) return existing.first.id;

    final lensId = await db.into(db.lenses).insert(LensesCompanion.insert(
          name: 'All tasks',
          ordering: LensOrdering.automatic,
          selection: LensSelection.top,
        ));
    final viewId = await db.into(db.views).insert(
        ViewsCompanion.insert(name: 'Home', sortIndex: const Value(0)));
    await db.into(db.viewLens).insert(ViewLensCompanion.insert(
        viewId: viewId, lensId: lensId, statusFilter: const Value(0)));

    // Backfill tasks/templates created before lenses existed (early dogfooding).
    for (final t in await db.select(db.tasks).get()) {
      await db.into(db.taskLens).insert(
            TaskLensCompanion.insert(
                taskId: t.id, lensId: lensId, surfacedAt: Value(t.createdAt)),
            mode: InsertMode.insertOrIgnore,
          );
    }
    await (db.update(db.templates)..where((t) => t.defaultLensId.isNull()))
        .write(TemplatesCompanion(defaultLensId: Value(lensId)));
    return lensId;
  }

  Future<int> createView(String name) async {
    final count = await db.select(db.views).get();
    return db.into(db.views).insert(
        ViewsCompanion.insert(name: name, sortIndex: Value(count.length)));
  }

  Future<int> createLensInView(int viewId, String name) async {
    final lensId = await db.into(db.lenses).insert(LensesCompanion.insert(
          name: name,
          ordering: LensOrdering.automatic,
          selection: LensSelection.top,
        ));
    await db.into(db.viewLens).insert(
        ViewLensCompanion.insert(viewId: viewId, lensId: lensId));
    return lensId;
  }

  /// Watch a View's full rendered state. The underlying join watches viewLens +
  /// lenses + taskLens + tasks, so it re-emits on any relevant write.
  Stream<ViewState?> watchViewState(int viewId, DateTime now) {
    final vl = db.viewLens;
    final l = db.lenses;
    final tl = db.taskLens;
    final t = db.tasks;

    final query = db.select(vl).join([
      innerJoin(l, l.id.equalsExp(vl.lensId)),
      leftOuterJoin(tl, tl.lensId.equalsExp(l.id)),
      leftOuterJoin(t, t.id.equalsExp(tl.taskId)),
    ])
      ..where(vl.viewId.equals(viewId))
      ..orderBy([OrderingTerm.asc(l.sortIndex)]);

    final viewFuture =
        (db.select(db.views)..where((v) => v.id.equals(viewId))).getSingleOrNull();

    return query.watch().asyncMap((rows) async {
      final view = await viewFuture;
      if (view == null) return null;
      return _assemble(view, rows, now);
    });
  }

  ViewState _assemble(ViewRow view, List<TypedResult> rows, DateTime now) {
    // Group rows by lens, collecting (membership, task) pairs.
    final lensById = <int, LensRow>{};
    final filterById = <int, int>{};
    final members = <int, List<LensMember>>{};

    for (final row in rows) {
      final lensRow = row.readTable(db.lenses);
      lensById[lensRow.id] = lensRow;
      filterById[lensRow.id] = row.readTable(db.viewLens).statusFilter;
      members.putIfAbsent(lensRow.id, () => []);

      final taskRow = row.readTableOrNull(db.tasks);
      final memRow = row.readTableOrNull(db.taskLens);
      if (taskRow != null && memRow != null) {
        members[lensRow.id]!.add(LensMember(
          task: _toTask(taskRow),
          order: memRow.sortOrder,
          surfacedAt: memRow.surfacedAt,
          passedThisPeriod: memRow.passedThisPeriod,
        ));
      }
    }

    final sections = <LensSection>[];
    for (final entry in lensById.entries) {
      final lens = _toLens(entry.value);
      final ms = members[entry.key]!;
      final filter = filterById[entry.key]!;

      final shownOpen = projectLens(lens, ms, now);
      final terminals = <domain.Task>[
        for (final m in ms)
          if (_terminalMatches(m.task, filter)) m.task,
      ];

      sections.add(LensSection(
        lens: entry.value,
        shown: [...shownOpen, ...terminals],
        doneCount: ms.where((m) => m.task.status == domain.TaskStatus.done).length,
        missedCount:
            ms.where((m) => m.task.status == domain.TaskStatus.missed).length,
        openCount: ms.where((m) => m.task.isOpen).length,
      ));
    }
    return ViewState(view: view, sections: sections);
  }

  bool _terminalMatches(domain.Task task, int filter) => switch (task.status) {
        domain.TaskStatus.done => filter & _showDone != 0,
        domain.TaskStatus.skipped => filter & _showSkipped != 0,
        domain.TaskStatus.missed => filter & _showMissed != 0,
        domain.TaskStatus.open => false,
      };

  Lens _toLens(LensRow r) => Lens(
        id: r.id,
        name: r.name,
        showCount: r.showCount,
        ordering: r.ordering,
        selection: r.selection,
        period: r.period,
        dormantAfter: r.dormantAfter,
        sortIndex: r.sortIndex,
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
}
