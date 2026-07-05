import 'package:checkfuchs/data/db/database.dart';
import 'package:checkfuchs/data/repositories/task_repository.dart';
import 'package:checkfuchs/domain/lens.dart';
import 'package:checkfuchs/domain/recurrence.dart';
import 'package:checkfuchs/domain/task.dart';
import 'package:checkfuchs/domain/template.dart';
import 'package:checkfuchs/domain/window_rule.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day, [int h = 0, int min = 0]) =>
    DateTime(y, m, day, h, min);

void main() {
  late AppDatabase db;
  late TaskRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TaskRepository(db);
  });
  tearDown(() => db.close());

  Future<int> seedDailyHabit() => repo.createTemplate(
    Template(
      name: 'Brush teeth',
      recurrence: Recurrence.daily(d(2026, 6, 27)),
      windowRule: Slice.morning,
      createdAt: d(2026, 6, 27),
    ),
  );

  test(
    'round-trips a template through the recurrence/window converters',
    () async {
      await seedDailyHabit();
      await repo.reconcileAll(d(2026, 6, 27, 8));
      final tasks = await repo.allTasks();
      expect(tasks, hasLength(1));
      expect(tasks.single.name, 'Brush teeth');
      expect(
        tasks.single.start,
        d(2026, 6, 27, 0),
      ); // morning slice survived JSON
      expect(tasks.single.end, d(2026, 6, 27, 12));
    },
  );

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

  test(
    'two overlapping reconcileAll calls create no duplicate instance',
    () async {
      await seedDailyHabit();
      final now = d(2026, 6, 27, 8);
      // Transactions serialise: the second run sees the first's insert.
      await Future.wait([repo.reconcileAll(now), repo.reconcileAll(now)]);
      final tasks = await repo.allTasks();
      expect(tasks, hasLength(1));
      expect(tasks.single.status, TaskStatus.open);
    },
  );

  test(
    'advancing past the window persists Missed + the next instance',
    () async {
      await seedDailyHabit();
      await repo.reconcileAll(d(2026, 6, 27, 8)); // today open
      await repo.reconcileAll(d(2026, 6, 28, 8)); // next morning

      final tasks = await repo.allTasks();
      final byOcc = {for (final t in tasks) t.occurrence: t};
      expect(byOcc[d(2026, 6, 27)]!.status, TaskStatus.missed);
      expect(byOcc[d(2026, 6, 28)]!.status, TaskStatus.open);
    },
  );

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

  test(
    'deleting a task cascades to its task_lens rows (FK enforcement)',
    () async {
      final lensId = await db
          .into(db.lenses)
          .insert(
            LensesCompanion.insert(
              name: 'All tasks',
              ordering: LensOrdering.automatic,
              selection: LensSelection.top,
            ),
          );
      final taskId = await repo.createTask(
        Task(name: 'Call dentist', createdAt: d(2026, 6, 27)),
        lensId: lensId,
      );
      expect(await db.select(db.taskLens).get(), hasLength(1));

      await repo.deleteTask(taskId);

      expect(await db.select(db.taskLens).get(), isEmpty); // cascade fired
    },
  );

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

  test('turnIntoSeries replaces a one-off with a recurring instance', () async {
    await repo.createTask(
      Task(name: 'Call dentist', createdAt: d(2026, 6, 27)),
    );
    final oneOff = (await repo.allTasks()).single;
    expect(oneOff.templateId, isNull);

    await repo.turnIntoSeries(
      oneOff,
      Recurrence.daily(d(2026, 6, 27)),
      const UntilNextOccurrence(),
      d(2026, 6, 27, 8),
    );

    final tasks = await repo.allTasks();
    expect(tasks, hasLength(1));
    expect(tasks.single.name, 'Call dentist');
    expect(tasks.single.templateId, isNotNull); // now recurring
  });

  test('updateTemplateConfig changes the series rule', () async {
    final tid = await seedDailyHabit();
    await repo.reconcileAll(d(2026, 6, 27, 8));
    await repo.updateTemplateConfig(
      tid,
      Recurrence.weekly(d(2026, 6, 27), on: {Weekday.mon}),
      Slice.morning,
      d(2026, 6, 27, 9),
    );
    expect((await repo.templateConfig(tid))!.recurrence.freq, Freq.weekly);
  });

  test('stopRepeating drops the template, keeps tasks as one-offs', () async {
    final tid = await seedDailyHabit();
    await repo.reconcileAll(d(2026, 6, 27, 8));
    await repo.stopRepeating(tid);
    final tasks = await repo.allTasks();
    expect(tasks, hasLength(1));
    expect(tasks.single.templateId, isNull);
    expect(await repo.templateConfig(tid), isNull);
  });

  test('isOnVacation reflects the scheduled periods', () async {
    await repo.addVacation(d(2026, 6, 20), d(2026, 6, 30, 23, 59));
    expect(await repo.isOnVacation(d(2026, 6, 27, 8)), isTrue);
    expect(await repo.isOnVacation(d(2026, 7, 5)), isFalse);
  });

  test('a vacation gates generation (no instance materialised)', () async {
    await seedDailyHabit();
    await repo.addVacation(d(2026, 6, 20), d(2026, 6, 30, 23, 59));
    await repo.reconcileAll(
      d(2026, 6, 27, 8),
    ); // vacation auto-computed → gated
    expect(await repo.allTasks(), isEmpty);
  });

  test(
    'a standalone one-off with a past end becomes Missed on reconcile',
    () async {
      await repo.createTask(
        Task(
          name: 'Return library book',
          end: d(2026, 6, 26, 23, 59),
          createdAt: d(2026, 6, 20),
        ),
      );

      await repo.reconcileAll(d(2026, 6, 27, 8));

      final t = (await repo.allTasks()).single;
      expect(t.status, TaskStatus.missed);
      expect(t.resolvedAt, d(2026, 6, 26, 23, 59)); // when it actually failed
    },
  );

  test('vacation resume: gated days produce no Missed rows', () async {
    await seedDailyHabit();
    // Vacation covers the next 5 days (06-28 .. 07-02) before the next
    // instance materialises, so generation is gated for those occurrences.
    await repo.addVacation(d(2026, 6, 28), d(2026, 7, 2, 23, 59));
    await repo.reconcileAll(d(2026, 6, 27, 8));
    final today = (await repo.allTasks()).single;
    await repo.completeTask(today, d(2026, 6, 27, 8));

    // The day after the vacation ends.
    await repo.reconcileAll(d(2026, 7, 3, 8));

    final tasks = await repo.allTasks();
    final byOcc = {for (final t in tasks) t.occurrence: t};
    expect(byOcc[d(2026, 6, 27)]!.status, TaskStatus.done);
    expect(byOcc[d(2026, 7, 3)]!.status, TaskStatus.open);
    expect(tasks.where((t) => t.status == TaskStatus.missed), isEmpty);
    expect(tasks, hasLength(2)); // nothing materialised for the vacation days
  });

  test(
    'an instance already open when the vacation is added is auto-Skipped '
    '(§6 open question 3, resolved: neutral Skip at vacation start, never a Miss)',
    () async {
      await seedDailyHabit();
      await repo.reconcileAll(d(2026, 6, 27, 8));
      // Completing today immediately materialises tomorrow's (06-28) instance…
      await repo.completeTask(
        (await repo.allTasks()).single,
        d(2026, 6, 27, 8),
      );
      // …and only then is the vacation declared over it.
      await repo.addVacation(d(2026, 6, 28), d(2026, 7, 2, 23, 59));

      await repo.reconcileAll(d(2026, 7, 3, 8));

      final byOcc = {for (final t in await repo.allTasks()) t.occurrence: t};
      final swallowed = byOcc[d(2026, 6, 28)]!;
      expect(swallowed.status, TaskStatus.skipped); // not Missed
      expect(swallowed.resolvedAt, d(2026, 6, 28)); // the vacation start
      expect(byOcc[d(2026, 6, 29)], isNull); // gated days leave no trace
      expect(byOcc[d(2026, 6, 30)], isNull);
      expect(byOcc[d(2026, 7, 1)], isNull);
      expect(byOcc[d(2026, 7, 2)], isNull);
      expect(byOcc[d(2026, 7, 3)]!.status, TaskStatus.open);
    },
  );

  test('a vacation shorter than the open window leaves the instance open '
      '(still doable after the return)', () async {
    // Weekly task, window = the whole week; a two-day vacation mid-window
    // must not consume it.
    await repo.createTemplate(
      Template(
        name: 'Water plants',
        recurrence: Recurrence.weekly(d(2026, 6, 22), on: {Weekday.mon}),
        createdAt: d(2026, 6, 22),
      ),
    );
    await repo.reconcileAll(d(2026, 6, 22, 8)); // Mon: week window opens
    await repo.addVacation(d(2026, 6, 24), d(2026, 6, 25, 23, 59)); // Wed–Thu

    await repo.reconcileAll(d(2026, 6, 26, 8)); // Fri, back home

    final task = (await repo.allTasks()).single;
    expect(task.status, TaskStatus.open); // window outlasts the vacation
  });

  test('pausing a template stops generating the next instance', () async {
    final tid = await seedDailyHabit();
    await repo.reconcileAll(d(2026, 6, 27, 8));
    await repo.pauseTemplate(tid, true, d(2026, 6, 27, 8));
    final today = (await repo.allTasks()).single;
    await repo.completeTask(today, d(2026, 6, 27, 8)); // reconciles, but paused

    final tasks = await repo.allTasks();
    expect(tasks, hasLength(1));
    expect(tasks.single.status, TaskStatus.done); // no tomorrow generated
  });
}
