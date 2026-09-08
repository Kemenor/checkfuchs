import 'package:drift/drift.dart';

import '../../domain/analytics.dart';
import '../../domain/clock.dart';
import '../../domain/derive.dart';
import '../../domain/lens.dart';
import '../../domain/recurrence.dart';
import '../../domain/task.dart' as domain;
import '../../domain/window_rule.dart';
import '../db/converters.dart';
import '../db/database.dart';

/// One lens as rendered inside a View: the shown tasks (open, projected, plus
/// periodic holds) plus the optional terminal tasks the View's statusFilter
/// opts in, and the full member counts for the text-breakdown header.
class LensSection {
  LensSection({
    required this.lens,
    required this.domainLens,
    required this.shown,
    required this.hiddenTerminals,
    required this.doneCount,
    required this.missedCount,
    required this.openCount,
    required this.avoidedTemplateIds,
  });

  final LensRow lens;
  final Lens domainLens;
  final List<domain.Task> shown;

  /// Current outcomes the statusFilter keeps out of [shown] — the breakdown
  /// header counts them, and tapping it peeks at them without changing the
  /// persisted filter.
  final List<domain.Task> hiddenTerminals;

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

/// One Lens as configured inside a View: the lens row plus the per-pair
/// `statusFilter` (which lives on the View↔Lens join, concept §4.6).
class ViewLensEntry {
  ViewLensEntry({required this.lens, required this.statusFilter});

  final LensRow lens;
  final int statusFilter;
}

/// Lens/View persistence + the derive-driven view state (Phase 4). The
/// projection itself is the pure, tested `domain/derive.dart`.
class ViewRepository {
  ViewRepository(this.db);
  final AppDatabase db;

  Stream<List<ViewRow>> watchViews() => (db.select(
    db.views,
  )..orderBy([(v) => OrderingTerm.asc(v.sortIndex)])).watch();

  Stream<List<LensRow>> watchAllLenses() => (db.select(
    db.lenses,
  )..orderBy([(l) => OrderingTerm.asc(l.sortIndex)])).watch();

  /// Live member count per lens id (the Library browse subtitles).
  Stream<Map<int, int>> watchLensTaskCounts() =>
      db.select(db.taskLens).watch().map((rows) {
        final counts = <int, int>{};
        for (final r in rows) {
          counts[r.lensId] = (counts[r.lensId] ?? 0) + 1;
        }
        return counts;
      });

  /// Which views each lens appears in (lens id → view names, bar order) —
  /// the Library browse notes where a lens is mounted, and an empty entry
  /// exposes an orphaned lens.
  Stream<Map<int, List<String>>> watchLensViewNames() {
    final q = db.select(db.viewLens).join([
      innerJoin(db.views, db.views.id.equalsExp(db.viewLens.viewId)),
    ])..orderBy([OrderingTerm.asc(db.views.sortIndex)]);
    return q.watch().map((rows) {
      final map = <int, List<String>>{};
      for (final r in rows) {
        map
            .putIfAbsent(r.readTable(db.viewLens).lensId, () => [])
            .add(r.readTable(db.views).name);
      }
      return map;
    });
  }

  /// Every instance in a lens's pool, unfiltered — the Library drill-in shows
  /// the raw pool a lens draws from, not what its dials currently surface.
  Stream<List<domain.Task>> watchLensTasks(int lensId) {
    final q = db.select(db.tasks).join([
      innerJoin(db.taskLens, db.taskLens.taskId.equalsExp(db.tasks.id)),
    ])..where(db.taskLens.lensId.equals(lensId));
    return q.watch().map(
      (rows) => [for (final r in rows) _toTask(r.readTable(db.tasks))],
    );
  }

  /// First-run defaults: a "Home" View showing one continuous "Default" Lens
  /// (named for what it is — the bucket tasks land in when nothing else is
  /// picked — not "All tasks", which it isn't once more lenses exist).
  /// Returns the default lens id (new tasks join it). Idempotent, and
  /// transactional — a partial seed (lens without its view) would otherwise
  /// trip the guard forever and leave the app without a Home view.
  /// [lensName] / [viewName] are the localized first-run names (the UI
  /// passes `l10n.seedLensDefault` / `l10n.seedViewHome`); the English
  /// defaults exist for tests and tooling.
  Future<int> seedDefaults({
    String lensName = 'Default',
    String viewName = 'Home',
  }) => db.transaction(
    () => seedDefaultsUnwrapped(lensName: lensName, viewName: viewName),
  );

  /// [seedDefaults] without its own transaction — for callers that already
  /// hold one (wipe + reseed must be atomic).
  Future<int> seedDefaultsUnwrapped({
    String lensName = 'Default',
    String viewName = 'Home',
  }) async {
    final existing = await db.select(db.lenses).get();
    if (existing.isNotEmpty) return existing.first.id;

    final lensId = await db
        .into(db.lenses)
        .insert(
          LensesCompanion.insert(
            name: lensName,
            ordering: LensOrdering.automatic,
            selection: LensSelection.top,
          ),
        );
    final viewId = await db
        .into(db.views)
        .insert(
          ViewsCompanion.insert(name: viewName, sortIndex: const Value(0)),
        );
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
    // Series without any lens join the default too (template_lens is what
    // generation reads; default_lens_id is only a legacy mirror).
    final orphans = await db
        .customSelect(
          'SELECT id FROM templates WHERE id NOT IN '
          '(SELECT template_id FROM template_lens)',
        )
        .get();
    for (final r in orphans) {
      await db
          .into(db.templateLens)
          .insert(
            TemplateLensCompanion.insert(
              templateId: r.read<int>('id'),
              lensId: lensId,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    return lensId;
  }

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

  // --- dial editing (Phase 4 UI) ---------------------------------------------

  /// Update a Lens's dials. Enum/count dials pass plain values (null = leave
  /// untouched); [period] and [dormantAfter] use drift [Value] semantics so
  /// `Value(null)` *clears* (periodic → continuous) while `Value.absent()`
  /// leaves the dial alone.
  Future<void> updateLensDials(
    int lensId, {
    int? showCount,
    LensOrdering? ordering,
    LensSelection? selection,
    Value<Recurrence?> period = const Value.absent(),
    Value<int?> dormantAfter = const Value.absent(),
  }) => (db.update(db.lenses)..where((l) => l.id.equals(lensId))).write(
    LensesCompanion(
      showCount: showCount == null ? const Value.absent() : Value(showCount),
      ordering: ordering == null ? const Value.absent() : Value(ordering),
      selection: selection == null ? const Value.absent() : Value(selection),
      period: period,
      dormantAfter: dormantAfter,
    ),
  );

  Future<void> renameLens(int id, String name) => (db.update(
    db.lenses,
  )..where((l) => l.id.equals(id))).write(LensesCompanion(name: Value(name)));

  /// Delete a Lens. The FK cascades clean its `task_lens` / `view_lens` /
  /// `template_lens` rows, and `templates.defaultLensId` is set null — tasks
  /// themselves stay.
  Future<void> deleteLens(int id) =>
      (db.delete(db.lenses)..where((l) => l.id.equals(id))).go();

  Future<void> renameView(int id, String name) => (db.update(
    db.views,
  )..where((v) => v.id.equals(id))).write(ViewsCompanion(name: Value(name)));

  Future<void> setViewIcon(int id, String slug) => (db.update(
    db.views,
  )..where((v) => v.id.equals(id))).write(ViewsCompanion(icon: Value(slug)));

  /// Delete a View. The FK cascade cleans its `view_lens` rows; the lenses
  /// (and their tasks) survive — a View is just an arrangement (§4.6).
  Future<void> deleteView(int id) =>
      (db.delete(db.views)..where((v) => v.id.equals(id))).go();

  /// Set which terminal states this View surfaces for [lensId] (bitmask:
  /// done=1, skipped=2, missed=4; 0 = open-only).
  Future<void> setStatusFilter(int viewId, int lensId, int filter) =>
      (db.update(db.viewLens)
            ..where((r) => r.viewId.equals(viewId) & r.lensId.equals(lensId)))
          .write(ViewLensCompanion(statusFilter: Value(filter)));

  /// Watch a single View row (null once deleted).
  Stream<ViewRow?> watchView(int viewId) => (db.select(
    db.views,
  )..where((v) => v.id.equals(viewId))).watchSingleOrNull();

  /// Watch the lenses of a View with their per-pair statusFilter — the
  /// view-edit screen's live source.
  Stream<List<ViewLensEntry>> watchViewLenses(int viewId) {
    final vl = db.viewLens;
    final l = db.lenses;
    final query = db.select(vl).join([innerJoin(l, l.id.equalsExp(vl.lensId))])
      ..where(vl.viewId.equals(viewId))
      ..orderBy([OrderingTerm.asc(l.sortIndex)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          ViewLensEntry(
            lens: row.readTable(l),
            statusFilter: row.readTable(vl).statusFilter,
          ),
      ],
    );
  }

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

    final dayStart = DateTime(now.year, now.month, now.day);

    final sections = <LensSection>[];
    for (final entry in lensById.entries) {
      final lens = _toLens(entry.value);
      final ms = members[entry.key]!;
      final filter = filterById[entry.key]!;

      // statusFilter surfaces each habit's CURRENT outcome, never history
      // (the Habitify shape: today's check stays in the list; yesterday's
      // belongs to analytics). A terminal template instance is current while
      // it is the template's latest non-future slot — so a completed daily
      // shows ✓ until tomorrow's slot arrives, a completed weekly all week.
      // Terminal one-offs are current on the day they were resolved.
      final latestByTemplate = <int, DateTime>{};
      for (final m in ms) {
        final t = m.task;
        final occ = t.occurrence;
        if (t.templateId == null || occ == null || occ.isAfter(now)) continue;
        final cur = latestByTemplate[t.templateId!];
        if (cur == null || occ.isAfter(cur)) {
          latestByTemplate[t.templateId!] = occ;
        }
      }
      bool isCurrentTerminal(domain.Task t) {
        if (!t.isTerminal) return false;
        if (t.templateId != null) {
          final occ = t.occurrence;
          return occ != null &&
              !occ.isAfter(now) &&
              occ.isAtSameMomentAs(latestByTemplate[t.templateId!]!);
        }
        return t.resolvedAt != null && !t.resolvedAt!.isBefore(dayStart);
      }

      final projected = projectLens(lens, ms, now);
      final projectedIds = {for (final x in projected) x.id};
      final terminals = <domain.Task>[];
      final hiddenTerminals = <domain.Task>[];
      for (final m in ms) {
        if (!isCurrentTerminal(m.task) || projectedIds.contains(m.task.id)) {
          continue;
        }
        (_terminalMatches(m.task, filter) ? terminals : hiddenTerminals).add(
          m.task,
        );
      }

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

      // Header counts scope to the same current slots — "1 done · 2 left" is
      // a statement about NOW, not an ever-growing all-time tally.
      sections.add(
        LensSection(
          lens: entry.value,
          domainLens: lens,
          shown: [...projected, ...terminals],
          hiddenTerminals: hiddenTerminals,
          doneCount: ms
              .where(
                (m) =>
                    m.task.status == domain.TaskStatus.done &&
                    isCurrentTerminal(m.task),
              )
              .length,
          missedCount: ms
              .where(
                (m) =>
                    m.task.status == domain.TaskStatus.missed &&
                    isCurrentTerminal(m.task),
              )
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
        // Band edges (a "morning or evening" task flips Active↔Pending
        // inside its envelope): today's and tomorrow's, civil arithmetic.
        for (final b in m.task.bands ?? const <Band>[]) {
          for (final dayOffset in const [0, 1]) {
            for (final o in [b.from, b.to]) {
              consider(
                DateTime(
                  now.year,
                  now.month,
                  now.day + dayOffset + o.inDays,
                  (o - Duration(days: o.inDays)).inHours,
                  o.inMinutes % 60,
                ),
              );
            }
          }
        }
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
    bands: bandsFromSql(r.windowBands),
  );
}
