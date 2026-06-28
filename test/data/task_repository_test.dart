import 'package:checkfuchs/data/db/database.dart';
import 'package:checkfuchs/data/repositories/task_repository.dart';
import 'package:checkfuchs/domain/recurrence.dart';
import 'package:checkfuchs/domain/task.dart';
import 'package:checkfuchs/domain/template.dart';
import 'package:checkfuchs/domain/window_rule.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day, [int h = 0]) => DateTime(y, m, day, h);

void main() {
  late AppDatabase db;
  late TaskRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TaskRepository(db);
  });
  tearDown(() => db.close());

  Future<int> seedDailyHabit() => repo.createTemplate(Template(
        name: 'Brush teeth',
        recurrence: Recurrence.daily(d(2026, 6, 27)),
        windowRule: Slice.morning,
        createdAt: d(2026, 6, 27),
      ));

  test('round-trips a template through the recurrence/window converters', () async {
    await seedDailyHabit();
    await repo.reconcileAll(d(2026, 6, 27, 8));
    final tasks = await repo.allTasks();
    expect(tasks, hasLength(1));
    expect(tasks.single.name, 'Brush teeth');
    expect(tasks.single.start, d(2026, 6, 27, 0)); // morning slice survived JSON
    expect(tasks.single.end, d(2026, 6, 27, 12));
  });

  test('reconcileAll materialises one open instance', () async {
    await seedDailyHabit();
    await repo.reconcileAll(d(2026, 6, 27, 8));
    final tasks = await repo.allTasks();
    expect(tasks.single.status, TaskStatus.open);
    expect(tasks.single.occurrence, d(2026, 6, 27));
  });

  test('reconcileAll is idempotent within the same window', () async {
    await seedDailyHabit();
    await repo.reconcileAll(d(2026, 6, 27, 8));
    await repo.reconcileAll(d(2026, 6, 27, 9));
    expect(await repo.allTasks(), hasLength(1)); // no duplicate
  });

  test('advancing past the window persists Missed + the next instance', () async {
    await seedDailyHabit();
    await repo.reconcileAll(d(2026, 6, 27, 8)); // today open
    await repo.reconcileAll(d(2026, 6, 28, 8)); // next morning

    final tasks = await repo.allTasks();
    final byOcc = {for (final t in tasks) t.occurrence: t};
    expect(byOcc[d(2026, 6, 27)]!.status, TaskStatus.missed);
    expect(byOcc[d(2026, 6, 28)]!.status, TaskStatus.open);
  });

  test('watchTasks emits on writes', () async {
    await seedDailyHabit();
    final first = await repo.watchTasks().first; // initial empty
    expect(first, isEmpty);
    await repo.reconcileAll(d(2026, 6, 27, 8));
    final after = await repo.watchTasks().first;
    expect(after, hasLength(1));
  });

  test('completeTask marks Done and generates the next instance', () async {
    await seedDailyHabit();
    await repo.reconcileAll(d(2026, 6, 27, 8));
    final today = (await repo.allTasks()).single;

    await repo.completeTask(today, d(2026, 6, 27, 8));

    final byOcc = {for (final t in await repo.allTasks()) t.occurrence: t};
    expect(byOcc[d(2026, 6, 27)]!.status, TaskStatus.done);
    expect(byOcc[d(2026, 6, 28)]!.status, TaskStatus.open);
  });

  test('skipTask marks Skipped and generates the next', () async {
    await seedDailyHabit();
    await repo.reconcileAll(d(2026, 6, 27, 8));
    final today = (await repo.allTasks()).single;

    await repo.skipTask(today, d(2026, 6, 27, 8));

    final byOcc = {for (final t in await repo.allTasks()) t.occurrence: t};
    expect(byOcc[d(2026, 6, 27)]!.status, TaskStatus.skipped);
    expect(byOcc[d(2026, 6, 28)]!.status, TaskStatus.open);
  });

  test('deleteTask removes just that instance', () async {
    await seedDailyHabit();
    await repo.reconcileAll(d(2026, 6, 27, 8));
    await repo.deleteTask((await repo.allTasks()).single.id!);
    expect(await repo.allTasks(), isEmpty);
  });

  test('deleteTemplate removes the series and its tasks', () async {
    final templateId = await seedDailyHabit();
    await repo.reconcileAll(d(2026, 6, 27, 8));
    await repo.deleteTemplate(templateId);
    expect(await repo.allTasks(), isEmpty);
  });

  test('renameTask updates the name', () async {
    await seedDailyHabit();
    await repo.reconcileAll(d(2026, 6, 27, 8));
    await repo.renameTask((await repo.allTasks()).single.id!, 'Floss');
    expect((await repo.allTasks()).single.name, 'Floss');
  });
}
