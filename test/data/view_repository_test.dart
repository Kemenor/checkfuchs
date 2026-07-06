import 'package:checkfuchs/data/db/database.dart';
import 'package:checkfuchs/data/repositories/task_repository.dart';
import 'package:checkfuchs/data/repositories/view_repository.dart';
import 'package:checkfuchs/domain/clock.dart';
import 'package:checkfuchs/domain/lens.dart';
import 'package:checkfuchs/domain/recurrence.dart';
import 'package:checkfuchs/domain/task.dart' as domain;
import 'package:checkfuchs/domain/template.dart';
import 'package:checkfuchs/domain/window_rule.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day, [int h = 0]) => DateTime(y, m, day, h);

void main() {
  late AppDatabase db;
  late TaskRepository taskRepo;
  late ViewRepository viewRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    taskRepo = TaskRepository(db);
    viewRepo = ViewRepository(db);
  });
  tearDown(() => db.close());

  test(
    'seedDefaults creates a Home view + an All-tasks lens (idempotent)',
    () async {
      final a = await viewRepo.seedDefaults();
      final b = await viewRepo.seedDefaults();
      expect(a, b);
      expect((await viewRepo.watchViews().first).map((v) => v.name), ['Home']);
    },
  );

  test('a View renders its lens through derive', () async {
    await viewRepo.seedDefaults();
    // A daily habit auto-joins the default lens.
    await taskRepo.createTemplate(
      Template(
        name: 'Brush teeth',
        recurrence: Recurrence.daily(d(2026, 6, 27)),
        windowRule: Slice.morning,
        createdAt: d(2026, 6, 27),
      ),
    );
    await taskRepo.reconcileAll(d(2026, 6, 27, 8));

    final home = (await viewRepo.watchViews().first).single;
    final state = await viewRepo
        .watchViewState(home.id, FixedClock(d(2026, 6, 27, 8)))
        .first;

    expect(state, isNotNull);
    expect(state!.sections, hasLength(1));
    expect(state.sections.single.shown.map((t) => t.name), ['Brush teeth']);
    expect(state.sections.single.openCount, 1);
  });

  test('completing a task updates the open/done counts', () async {
    await viewRepo.seedDefaults();
    await taskRepo.createTemplate(
      Template(
        name: 'Brush teeth',
        recurrence: Recurrence.daily(d(2026, 6, 27)),
        windowRule: Slice.morning,
        createdAt: d(2026, 6, 27),
      ),
    );
    await taskRepo.reconcileAll(d(2026, 6, 27, 8));

    final today = (await taskRepo.allTasks()).firstWhere((t) => t.isOpen);
    await taskRepo.completeTask(today, d(2026, 6, 27, 8));

    final home = (await viewRepo.watchViews().first).single;
    final state = (await viewRepo
        .watchViewState(home.id, FixedClock(d(2026, 6, 27, 8)))
        .first)!;
    // today done; tomorrow's pending instance is the new open one.
    expect(state.sections.single.doneCount, 1);
  });

  group('lens dial editing (Phase 4 UI)', () {
    test('updateLensDials round-trips, and Value(null) clears', () async {
      final lensId = await viewRepo.seedDefaults();
      final period = Recurrence.weekly(d(2026, 6, 22));

      await viewRepo.updateLensDials(
        lensId,
        showCount: 3,
        ordering: LensOrdering.dueDate,
        selection: LensSelection.random,
        period: Value(period),
        dormantAfter: const Value(2),
      );
      var lens = await db.select(db.lenses).getSingle();
      expect(lens.showCount, 3);
      expect(lens.ordering, LensOrdering.dueDate);
      expect(lens.selection, LensSelection.random);
      expect(lens.period?.freq, Freq.weekly);
      expect(lens.dormantAfter, 2);

      // Absent params leave dials untouched.
      await viewRepo.updateLensDials(lensId, showCount: Lens.showAll);
      lens = await db.select(db.lenses).getSingle();
      expect(lens.showCount, Lens.showAll);
      expect(lens.ordering, LensOrdering.dueDate);
      expect(lens.period, isNotNull);
      expect(lens.dormantAfter, 2);

      // Value(null) clears back to continuous / never-dormant.
      await viewRepo.updateLensDials(
        lensId,
        period: const Value(null),
        dormantAfter: const Value(null),
      );
      lens = await db.select(db.lenses).getSingle();
      expect(lens.period, isNull);
      expect(lens.dormantAfter, isNull);
    });

    test('setStatusFilter surfaces a Done task in watchViewState', () async {
      final lensId = await viewRepo.seedDefaults();
      await taskRepo.createTemplate(
        Template(
          name: 'Brush teeth',
          recurrence: Recurrence.daily(d(2026, 6, 27)),
          windowRule: Slice.morning,
          createdAt: d(2026, 6, 27),
        ),
      );
      await taskRepo.reconcileAll(d(2026, 6, 27, 8));
      final today = (await taskRepo.allTasks()).firstWhere((t) => t.isOpen);
      await taskRepo.completeTask(today, d(2026, 6, 27, 8));

      final home = (await viewRepo.watchViews().first).single;
      final clock = FixedClock(d(2026, 6, 27, 8));

      // Default filter 0: open-only, the done task is hidden.
      var state = (await viewRepo.watchViewState(home.id, clock).first)!;
      expect(
        state.sections.single.shown.map((t) => t.status),
        isNot(contains(domain.TaskStatus.done)),
      );

      await viewRepo.setStatusFilter(home.id, lensId, 1); // done=1
      state = (await viewRepo.watchViewState(home.id, clock).first)!;
      expect(
        state.sections.single.shown.map((t) => t.status),
        contains(domain.TaskStatus.done),
      );
    });

    test('statusFilter shows current outcomes only, never history', () async {
      final lensId = await viewRepo.seedDefaults();
      await taskRepo.createTemplate(
        Template(
          name: 'Brush teeth',
          recurrence: Recurrence.daily(d(2026, 6, 27)),
          windowRule: Slice.morning,
          createdAt: d(2026, 6, 27),
        ),
      );
      final home = (await viewRepo.watchViews().first).single;
      await viewRepo.setStatusFilter(home.id, lensId, 5); // done + missed

      // Day 1: complete it.
      await taskRepo.reconcileAll(d(2026, 6, 27, 8));
      final day1 = (await taskRepo.allTasks()).firstWhere((t) => t.isOpen);
      await taskRepo.completeTask(day1, d(2026, 6, 27, 8));

      var state = (await viewRepo
          .watchViewState(home.id, FixedClock(d(2026, 6, 27, 9)))
          .first)!;
      expect(state.sections.single.doneCount, 1); // today's ✓ is current

      // Day 3: day-1's Done is history now; day-2 Missed is also stale —
      // only day-3's open slot plus nothing terminal.
      await taskRepo.reconcileAll(d(2026, 6, 29, 8));
      state = (await viewRepo
          .watchViewState(home.id, FixedClock(d(2026, 6, 29, 8)))
          .first)!;
      final shown = state.sections.single.shown;
      expect(
        shown.where((t) => t.isTerminal),
        isEmpty,
        reason: 'old outcomes must not pile up as history rows',
      );
      expect(state.sections.single.doneCount, 0);
      expect(state.sections.single.missedCount, 0);

      // Miss day 3 (window passes): the miss IS the current outcome.
      await taskRepo.reconcileAll(d(2026, 6, 29, 13));
      state = (await viewRepo
          .watchViewState(home.id, FixedClock(d(2026, 6, 29, 13)))
          .first)!;
      expect(state.sections.single.missedCount, 1);
      expect(
        state.sections.single.shown.map((t) => t.status),
        contains(domain.TaskStatus.missed),
      );
    });

    test('deleteLens cascades memberships; tasks survive', () async {
      final lensId = await viewRepo.seedDefaults();
      await taskRepo.createTemplate(
        Template(
          name: 'Brush teeth',
          recurrence: Recurrence.daily(d(2026, 6, 27)),
          windowRule: Slice.morning,
          createdAt: d(2026, 6, 27),
        ),
      );
      await taskRepo.reconcileAll(d(2026, 6, 27, 8));
      expect(await db.select(db.taskLens).get(), isNotEmpty);

      await viewRepo.deleteLens(lensId);

      expect(await db.select(db.lenses).get(), isEmpty);
      expect(await db.select(db.taskLens).get(), isEmpty);
      expect(await db.select(db.viewLens).get(), isEmpty);
      expect(await taskRepo.allTasks(), isNotEmpty);
      // The template's default lens is nulled, not deleted.
      final template = await db.select(db.templates).getSingle();
      expect(template.defaultLensId, isNull);
    });

    test('deleteView keeps lenses and tasks', () async {
      await viewRepo.seedDefaults();
      await taskRepo.createTemplate(
        Template(
          name: 'Brush teeth',
          recurrence: Recurrence.daily(d(2026, 6, 27)),
          windowRule: Slice.morning,
          createdAt: d(2026, 6, 27),
        ),
      );
      await taskRepo.reconcileAll(d(2026, 6, 27, 8));

      final home = (await viewRepo.watchViews().first).single;
      await viewRepo.deleteView(home.id);

      expect(await viewRepo.watchViews().first, isEmpty);
      expect(await db.select(db.viewLens).get(), isEmpty);
      expect(await db.select(db.lenses).get(), isNotEmpty);
      expect(await taskRepo.allTasks(), isNotEmpty);
      expect(await db.select(db.taskLens).get(), isNotEmpty);
    });

    test('renameView / setViewIcon / renameLens write through', () async {
      final lensId = await viewRepo.seedDefaults();
      final home = (await viewRepo.watchViews().first).single;

      await viewRepo.renameView(home.id, 'Alltag');
      await viewRepo.setViewIcon(home.id, 'star');
      await viewRepo.renameLens(lensId, 'Alles');

      final view = (await viewRepo.watchView(home.id).first)!;
      expect(view.name, 'Alltag');
      expect(view.icon, 'star');
      expect((await db.select(db.lenses).getSingle()).name, 'Alles');
    });

    test('watchViewLenses emits the lens with its statusFilter', () async {
      final lensId = await viewRepo.seedDefaults();
      final home = (await viewRepo.watchViews().first).single;

      var entries = await viewRepo.watchViewLenses(home.id).first;
      expect(entries.single.lens.id, lensId);
      expect(entries.single.statusFilter, 0);

      await viewRepo.setStatusFilter(home.id, lensId, 5); // done + missed
      entries = await viewRepo.watchViewLenses(home.id).first;
      expect(entries.single.statusFilter, 5);
    });
  });
}
