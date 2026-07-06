import 'package:drift/drift.dart';

import '../../domain/analytics.dart';
import '../../domain/clock.dart';
import '../../domain/derive.dart';
import '../../domain/lens.dart';
import '../../domain/recurrence.dart';
import '../../domain/task.dart' as domain;
import '../db/database.dart';

/// One lens as rendered inside a View: the shown tasks (open, projected, plus
/// periodic holds) plus the optional terminal tasks the View's statusFilter
/// opts in, and the full member counts for the text-breakdown header.
class LensSection {
  LensSection({
    required this.lens,
    required this.domainLens,
    required this.shown,
    required this.doneCount,
    required this.missedCount,
    required this.openCount,
    required this.avoidedTemplateIds,
  });

  final LensRow lens;
  final Lens domainLens;
  final List<domain.Task> shown;
  final int doneCount;
  final int missedCount;
  final int openCount;

  /// Templates past the consecutive-miss avoidance threshold (§8) — their open
  /// instance renders in soft amber. Information, never a forced action.
  final Set<int> avoidedTemplateIds;

  bool isAvoided(domain.Task t) =>
      t.templateId != null && avoidedTemplateIds.contains(t.templateId);
}

class ViewState {
  ViewState({
    required this.view,
    required this.sections,
    required this.nextTransition,
  });

  final ViewRow view;
  final List<LensSection> sections;

  /// The soonest instant this state becomes stale on its own (a window edge,
  /// a period rollover, or midnight) — the reactive layer arms one timer to it
  /// (PLAN "foreground time advance"): event-driven, no polling.
  final DateTime nextTransition;
}

const _showDone = 1, _showSkipped = 2, _showMissed = 4;

/// Lens/View persistence + the derive-driven view state (Phase 4). The
/// projection itself is the pure, tested `domain/derive.dart`.
class ViewRepository {
  ViewRepository(this.db);
  final AppDatabase db;

  Stream<List<ViewRow>> watchViews() => (db.select(
    db.views,
  )..orderBy([(v) => OrderingTerm.asc(v.sortIndex)])).watch();

  /// First-run defaults: a "Home" View showing one continuous "All tasks" Lens.
  /// Returns the default lens id (new tasks join it). Idempotent, and
  /// transactional — a partial seed (lens without its view) would otherwise
  /// trip the guard forever and leave the app without a Home view.
  Future<int> seedDefaults() => db.transaction(() async {
    final existing = await db.select(db.lenses).get();
    if (existing.isNotEmpty) return existing.first.id;

    final lensId = await db
        .into(db.lenses)
        .insert(
          LensesCompanion.insert(
            name: 'All tasks',
            ordering: LensOrdering.automatic,
            selection: LensSelection.top,
          ),
        );
    final viewId = await db
        .into(db.views)
        .insert(ViewsCompanion.insert(name: 'Home', sortIndex: const Value(0)));
    await db
        .into(db.viewLens)
        .insert(
          ViewLensCompanion.insert(
            viewId: viewId,
            lensId: lensId,
            statusFilter: const Value(0),
          ),
        );

    // Backfill tasks/templates created before lenses existed (early
    // dogfooding). surfacedAt stays null — "never yet shown".
    for (final t in await db.select(db.tasks).get()) {
      await db
          .into(db.taskLens)
          .insert(
            TaskLensCompanion.insert(taskId: t.id, lensId: lensId),
            mode: InsertMode.insertOrIgnore,
          );
    }
    await (db.update(db.templates)..where((t) => t.defaultLensId.isNull()))
        .write(TemplatesCompanion(defaultLensId: Value(lensId)));
    return lensId;
  });

  Future<int> createView(String name, {String icon = 'home'}) =>
      db.transaction(() async {
        final next = await _nextSortIndex(db.views.sortIndex, db.views);
        return db
            .into(db.views)
            .insert(
              ViewsCompanion.insert(
                name: name,
                sortIndex: Value(next),
                icon: Value(icon),
              ),
            );
      });

  Future<int> createLensInView(int viewId, String name) =>
      db.transaction(() async {
        final next = await _nextSortIndex(db.lenses.sortIndex, db.lenses);
        final lensId = await db
            .into(db.lenses)
            .insert(
              LensesCompanion.insert(
                name: name,
                ordering: LensOrdering.automatic,
                selection: LensSelection.top,
                sortIndex: Value(next),
              ),
            );
        await db
            .into(db.viewLens)
            .insert(ViewLensCompanion.insert(viewId: viewId, lensId: lensId));
        return lensId;
      });

  /// `max(sortIndex) + 1` — count-based indexing produces duplicates once
  /// deletion exists.
  Future<int> _nextSortIndex(
    GeneratedColumn<int> column,
    TableInfo table,
  ) async {
    final maxIndex = column.max();
    final row = await (db.selectOnly(
      table,
    )..addColumns([maxIndex])).getSingle();
    return (row.read(maxIndex) ?? -1) + 1;
  }

  /// Watch a View's full rendered state. The join watches views + viewLens +
  /// lenses + taskLens + tasks, so it re-emits on any relevant write — and
  /// every emission is projected against a **fresh** `clock.now()`, never a
  /// timestamp captured at subscription time.
  Stream<ViewState?> watchViewState(int viewId, Clock clock) {
    final v = db.views;
    final vl = db.viewLens;
    final l = db.lenses;
    final tl = db.taskLens;
    final t = db.tasks;

    final query =
        db.select(vl).join([
            innerJoin(v, v.id.equalsExp(vl.viewId)),
            innerJoin(l, l.id.equalsExp(vl.lensId)),
            leftOuterJoin(tl, tl.lensId.equalsExp(l.id)),
            leftOuterJoin(t, t.id.equalsExp(tl.taskId)),
          ])
          ..where(vl.viewId.equals(viewId))
          ..orderBy([OrderingTerm.asc(l.sortIndex)]);

    return query.watch().asyncMap((rows) async {
      // A view with no lenses yields no join rows — fall back to a direct read
      // so it still renders (empty) instead of disappearing.
      final view = rows.isNotEmpty
          ? rows.first.readTable(db.views)
          : await (db.select(
              db.views,
            )..where((x) => x.id.equals(viewId))).getSingleOrNull();
      if (view == null) return null;
      return _assemble(view, rows, clock.now());
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
        members[lensRow.id]!.add(
          LensMember(
            task: _toTask(taskRow),
            order: memRow.sortOrder,
            surfacedAt: memRow.surfacedAt,
            passedAt: memRow.passedAt,
          ),
        );
      }
    }

    final sections = <LensSection>[];
    for (final entry in lensById.entries) {
      final lens = _toLens(entry.value);
      final ms = members[entry.key]!;
      final filter = filterById[entry.key]!;

      final projected = projectLens(lens, ms, now);
      final projectedIds = {for (final x in projected) x.id};
      final terminals = <domain.Task>[
        for (final m in ms)
          if (_terminalMatches(m.task, filter) &&
              !projectedIds.contains(m.task.id))
            m.task,
      ];

      // Avoidance (§8): a template's instances all live in its lens, so the
      // members ARE the series history — group and run the pure analytics.
      final byTemplate = <int, List<domain.Task>>{};
      for (final m in ms) {
        final tid = m.task.templateId;
        if (tid != null) byTemplate.putIfAbsent(tid, () => []).add(m.task);
      }
      final avoided = {
        for (final e in byTemplate.entries)
          if (computeStats(e.value).isAvoided) e.key,
      };

      sections.add(
        LensSection(
          lens: entry.value,
          domainLens: lens,
          shown: [...projected, ...terminals],
          doneCount: ms
              .where((m) => m.task.status == domain.TaskStatus.done)
              .length,
          missedCount: ms
              .where((m) => m.task.status == domain.TaskStatus.missed)
              .length,
          openCount: ms.where((m) => m.task.isOpen).length,
          avoidedTemplateIds: avoided,
        ),
      );
    }
    return ViewState(
      view: view,
      sections: sections,
      nextTransition: _nextTransition(lensById.values, members, now),
    );
  }

  /// The soonest window edge / period rollover after [now]; never later than
  /// the next midnight (the generic daily tick).
  DateTime _nextTransition(
    Iterable<LensRow> lenses,
    Map<int, List<LensMember>> members,
    DateTime now,
  ) {
    var soonest = DateTime(now.year, now.month, now.day + 1);
    void consider(DateTime? d) {
      if (d != null && d.isAfter(now) && d.isBefore(soonest)) soonest = d;
    }

    for (final ms in members.values) {
      for (final m in ms) {
        if (!m.task.isOpen) continue;
        consider(m.task.start);
        consider(m.task.end);
      }
    }
    for (final lens in lenses) {
      if (lens.period != null) {
        consider(occurrenceAfter(lens.period!, now));
      }
    }
    return soonest;
  }

  /// Stamp `surfacedAt` for members currently entering a periodic lens's shown
  /// set (first surfacing, or resurfacing after a dormancy rest). Runs on
  /// launch/resume and on the time-advance tick; writes the period start, so
  /// it converges (at most one write per member per period) instead of
  /// re-triggering the reactive loop forever.
  Future<void> refreshSurfaced(DateTime now) => db.transaction(() async {
    final lensRows = await (db.select(
      db.lenses,
    )..where((l) => l.period.isNotNull())).get();
    for (final lensRow in lensRows) {
      final lens = _toLens(lensRow);
      final tl = db.taskLens;
      final t = db.tasks;
      final rows = await (db.select(tl).join([
        innerJoin(t, t.id.equalsExp(tl.taskId)),
      ])..where(tl.lensId.equals(lensRow.id))).get();
      final ms = [
        for (final row in rows)
          LensMember(
            task: _toTask(row.readTable(t)),
            order: row.readTable(tl).sortOrder,
            surfacedAt: row.readTable(tl).surfacedAt,
            passedAt: row.readTable(tl).passedAt,
          ),
      ];
      final shownIds = {for (final task in projectLens(lens, ms, now)) task.id};
      final ps = periodStart(lens.period!, now);
      for (final m in ms) {
        if (!shownIds.contains(m.task.id)) continue;
        final fresh =
            m.surfacedAt == null ||
            (lens.dormantAfter != null &&
                periodsElapsed(lens.period!, m.surfacedAt!, now) >
                    lens.dormantAfter!);
        if (fresh) {
          await (db.update(tl)..where(
                (x) =>
                    x.taskId.equals(m.task.id!) & x.lensId.equals(lensRow.id),
              ))
              .write(TaskLensCompanion(surfacedAt: Value(ps)));
        }
      }
    }
  });

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
    notifications: r.notifications,
  );
}
