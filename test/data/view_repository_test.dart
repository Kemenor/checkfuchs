import 'package:checkfuchs/data/db/database.dart';
import 'package:checkfuchs/data/repositories/task_repository.dart';
import 'package:checkfuchs/data/repositories/view_repository.dart';
import 'package:checkfuchs/domain/clock.dart';
import 'package:checkfuchs/domain/recurrence.dart';
import 'package:checkfuchs/domain/template.dart';
import 'package:checkfuchs/domain/window_rule.dart';
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
}
