import 'package:checkfuchs/domain/goal.dart';
import 'package:checkfuchs/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime dt(int y, int m, int d, [int h = 0, int min = 0]) =>
    DateTime(y, m, d, h, min);

Task taskWith({
  DateTime? start,
  DateTime? end,
  TaskStatus status = TaskStatus.open,
}) => Task(
  name: 'Brush teeth',
  status: status,
  start: start,
  end: end,
  createdAt: dt(2026, 6, 1),
);

void main() {
  final morning = dt(2026, 6, 27, 8); // inside an 00:00–12:00 window

  group('phaseOf', () {
    test('pending before start', () {
      final t = taskWith(start: dt(2026, 6, 28), end: dt(2026, 6, 28, 12));
      expect(phaseOf(t, morning), TaskPhase.pending);
    });

    test('active within the window', () {
      final t = taskWith(start: dt(2026, 6, 27), end: dt(2026, 6, 27, 12));
      expect(phaseOf(t, morning), TaskPhase.active);
    });

    test('active when unbounded (no end)', () {
      final t = taskWith(); // no start, no end
      expect(phaseOf(t, morning), TaskPhase.active);
    });

    test('expired after end', () {
      final t = taskWith(start: dt(2026, 6, 27), end: dt(2026, 6, 27, 12));
      expect(phaseOf(t, dt(2026, 6, 27, 13)), TaskPhase.expired);
    });
  });

  group('action rules', () {
    final active = taskWith(start: dt(2026, 6, 27), end: dt(2026, 6, 27, 12));
    final pending = taskWith(start: dt(2026, 6, 28), end: dt(2026, 6, 28, 12));
    final expired = taskWith(start: dt(2026, 6, 27), end: dt(2026, 6, 27, 12));
    final unbounded = taskWith();

    test('Done only while active+open', () {
      expect(canCheckIn(active, morning), isTrue);
      expect(canCheckIn(pending, morning), isFalse); // pending
      expect(canCheckIn(expired, dt(2026, 6, 27, 13)), isFalse); // expired
      expect(canCheckIn(unbounded, morning), isTrue);
      expect(
        canCheckIn(active.copyWith(status: TaskStatus.done), morning),
        isFalse, // terminal
      );
    });

    test('Skip anytime while open except expired', () {
      expect(canSkip(active, morning), isTrue);
      expect(canSkip(pending, morning), isTrue); // pre-empt
      expect(canSkip(expired, dt(2026, 6, 27, 13)), isFalse);
      expect(
        canSkip(active.copyWith(status: TaskStatus.skipped), morning),
        isFalse,
      );
    });
  });

  group('copyWith clearing', () {
    final full = Task(
      name: 'Brush teeth',
      note: 'gently',
      status: TaskStatus.done,
      start: dt(2026, 6, 27),
      end: dt(2026, 6, 27, 12),
      occurrence: dt(2026, 6, 27),
      createdAt: dt(2026, 6, 1),
      resolvedAt: dt(2026, 6, 27, 8),
    );

    test('an explicit null clears end/note/resolvedAt/occurrence', () {
      final cleared = full.copyWith(
        end: null,
        note: null,
        resolvedAt: null,
        occurrence: null,
      );
      expect(cleared.end, isNull);
      expect(cleared.note, isNull);
      expect(cleared.resolvedAt, isNull);
      expect(cleared.occurrence, isNull);
      expect(cleared.start, full.start); // untouched fields survive
      expect(cleared.name, full.name);
    });

    test('omitting the arguments keeps the current values', () {
      expect(full.copyWith(), full);
    });
  });

  group('transitions', () {
    test('a 1-of-1 check-in → Done with resolvedAt = now', () {
      final t = taskWith(start: dt(2026, 6, 27), end: dt(2026, 6, 27, 12));
      final done = checkIn(t, morning);
      expect(done.status, TaskStatus.done);
      expect(done.resolvedAt, morning);
    });

    test('skip → Skipped with resolvedAt = now', () {
      final t = taskWith(start: dt(2026, 6, 27), end: dt(2026, 6, 27, 12));
      final skipped = skip(t, morning);
      expect(skipped.status, TaskStatus.skipped);
      expect(skipped.resolvedAt, morning);
    });

    test('expireIfDue → Missed with resolvedAt = window end', () {
      final end = dt(2026, 6, 27, 12);
      final t = taskWith(start: dt(2026, 6, 27), end: end);
      final missed = expireIfDue(t, dt(2026, 6, 27, 13));
      expect(missed, isNotNull);
      expect(missed!.status, TaskStatus.missed);
      expect(missed.resolvedAt, end); // when it actually failed, not "now"
    });

    test(
      'expireIfDue is a no-op for active / pending / unbounded / terminal',
      () {
        final active = taskWith(
          start: dt(2026, 6, 27),
          end: dt(2026, 6, 27, 12),
        );
        expect(expireIfDue(active, morning), isNull);
        expect(
          expireIfDue(taskWith(), morning),
          isNull,
        ); // unbounded, never fails
        expect(
          expireIfDue(
            active.copyWith(status: TaskStatus.done),
            dt(2026, 6, 27, 13),
          ),
          isNull, // already terminal
        );
      },
    );

    test('window opened AND closed while away → straight to Missed', () {
      // created in advance for a 14–25 Jul window; opened the app in August.
      final end = dt(2026, 7, 25, 23, 59);
      final t = taskWith(start: dt(2026, 7, 14), end: end);
      final missed = expireIfDue(t, dt(2026, 8, 3));
      expect(missed?.status, TaskStatus.missed);
      expect(missed?.resolvedAt, end);
    });
  });

  group('Missed → Done correction (§11 q7)', () {
    final missedHabit = Task(
      id: 1,
      templateId: 7,
      name: 'Brush teeth',
      status: TaskStatus.missed,
      start: DateTime(2026, 9, 8, 6),
      end: DateTime(2026, 9, 8, 12),
      occurrence: DateTime(2026, 9, 8),
      createdAt: DateTime(2026, 9, 8),
      resolvedAt: DateTime(2026, 9, 8, 12),
    );

    test('a missed habit instance can be corrected; one-offs cannot', () {
      expect(canCorrectMiss(missedHabit), isTrue);
      expect(canCorrectMiss(missedHabit.copyWith(templateId: null)), isFalse);
      expect(
        canCorrectMiss(missedHabit.copyWith(status: TaskStatus.skipped)),
        isFalse,
      );
    });

    test('correction lands as done at the window end', () {
      final fixed = correctMiss(missedHabit);
      expect(fixed.status, TaskStatus.done);
      expect(fixed.resolvedAt, DateTime(2026, 9, 8, 12));
    });
  });

  group('reopen (undo a Done/Skip)', () {
    final done = Task(
      id: 3,
      name: 'Stretch',
      status: TaskStatus.done,
      start: DateTime(2026, 9, 8, 6),
      end: DateTime(2026, 9, 8, 12),
      createdAt: DateTime(2026, 9, 8),
      resolvedAt: DateTime(2026, 9, 8, 7),
    );

    test('done and skipped reopen; open and missed do not', () {
      expect(canReopen(done), isTrue);
      expect(canReopen(done.copyWith(status: TaskStatus.skipped)), isTrue);
      expect(canReopen(done.copyWith(status: TaskStatus.open)), isFalse);
      expect(canReopen(done.copyWith(status: TaskStatus.missed)), isFalse);
      final back = reopen(done, DateTime(2026, 9, 8, 8));
      expect(back.status, TaskStatus.open);
      expect(back.resolvedAt, isNull);
    });

    test('a 1-of-1 Done gives back its check-in when reopened', () {
      final t = taskWith(start: dt(2026, 6, 27), end: dt(2026, 6, 27, 12));
      final done = checkIn(t, morning);
      expect(done.checkIns, [morning]);
      final back = reopen(done, morning);
      expect(back.status, TaskStatus.open);
      expect(back.checkIns, isEmpty);
    });
  });

  group('counting habits (§3.7)', () {
    // Gym, 2–3× in the week of Mon 12 Oct 2026, never twice a day.
    Task gym({Goal goal = const Goal(min: 2, max: 3, oncePerDay: true)}) =>
        Task(
          id: 1,
          templateId: 4,
          name: 'Gym',
          start: dt(2026, 10, 12),
          end: dt(2026, 10, 19),
          occurrence: dt(2026, 10, 12),
          createdAt: dt(2026, 10, 12),
          goal: goal,
        );
    final tue = dt(2026, 10, 13, 18);
    final wed = dt(2026, 10, 14, 7);
    final thu = dt(2026, 10, 15, 19);
    final nextWeek = dt(2026, 10, 19, 9);

    test('below min stays open, can still be skipped', () {
      final t = checkIn(gym(), tue);
      expect(t.status, TaskStatus.open);
      expect(t.count, 1);
      expect(t.isMet, isFalse);
      expect(canSkip(t, tue), isTrue);
    });

    test('once a day blocks a second check-in on the same day only', () {
      final t = checkIn(gym(), tue);
      expect(canCheckIn(t, tue.add(const Duration(hours: 2))), isFalse);
      expect(canCheckIn(t, wed), isTrue);
      final free = checkIn(gym(goal: const Goal(min: 2, max: 3)), tue);
      expect(canCheckIn(free, tue.add(const Duration(hours: 2))), isTrue);
    });

    test('met stays open, takes +1, but can no longer be skipped', () {
      final t = checkIn(checkIn(gym(), tue), wed);
      expect(t.status, TaskStatus.open);
      expect(t.isMet, isTrue);
      expect(canCheckIn(t, thu), isTrue);
      expect(canSkip(t, thu), isFalse);
    });

    test('reaching max is Done, resolved at that check-in', () {
      final t = checkIn(checkIn(checkIn(gym(), tue), wed), thu);
      expect(t.status, TaskStatus.done);
      expect(t.resolvedAt, thu);
      expect(canCheckIn(t, dt(2026, 10, 16, 8)), isFalse);
    });

    test('a met cycle resolves Done when the window closes', () {
      final t = expireIfDue(checkIn(checkIn(gym(), tue), wed), nextWeek)!;
      expect(t.status, TaskStatus.done);
      expect(t.resolvedAt, wed); // the last check-in, not the window end
      expect(t.doneUnits, 2);
      expect(t.missedUnits, 0);
    });

    test('a cycle short of min is Missed, one unit per missing check-in', () {
      final one = expireIfDue(checkIn(gym(), tue), nextWeek)!;
      expect(one.status, TaskStatus.missed);
      expect(one.resolvedAt, dt(2026, 10, 19));
      expect((one.doneUnits, one.missedUnits), (1, 1));
      final none = expireIfDue(gym(), nextWeek)!;
      expect((none.doneUnits, none.missedUnits), (0, 2));
    });

    test('no limit: met stays open past min, Done at window end', () {
      var water = Task(
        templateId: 2,
        name: 'Water',
        start: dt(2026, 10, 12),
        end: dt(2026, 10, 13),
        createdAt: dt(2026, 10, 12),
        goal: const Goal(min: 8, max: null),
      );
      for (var h = 7; h < 17; h++) {
        water = checkIn(water, dt(2026, 10, 12, h));
      }
      expect(water.count, 10);
      expect(water.status, TaskStatus.open);
      expect(canCheckIn(water, dt(2026, 10, 12, 20)), isTrue);
      expect(expireIfDue(water, dt(2026, 10, 13, 1))!.status, TaskStatus.done);
    });

    test('removing a check-in re-resolves', () {
      final full = checkIn(checkIn(checkIn(gym(), tue), wed), thu);
      // Window still open: back to met.
      final back = removeCheckIn(full, thu, dt(2026, 10, 16));
      expect(back.status, TaskStatus.open);
      expect(back.isMet, isTrue);
      // Window closed and below min: Missed.
      final done = expireIfDue(checkIn(checkIn(gym(), tue), wed), nextWeek)!;
      final short = removeCheckIn(done, wed, nextWeek);
      expect(short.status, TaskStatus.missed);
      expect(short.resolvedAt, dt(2026, 10, 19));
    });

    test('a forgotten check-in fixes a Missed cycle', () {
      final missed = expireIfDue(checkIn(gym(), tue), nextWeek)!;
      expect(canAddCheckIn(missed, thu, nextWeek), isTrue);
      final fixed = addCheckIn(missed, thu, nextWeek);
      expect(fixed.status, TaskStatus.done);
      expect(fixed.checkIns, [tue, thu]);
    });

    test('a forgotten check-in must sit inside the window, in the past', () {
      final t = checkIn(gym(), tue);
      expect(canAddCheckIn(t, dt(2026, 10, 11, 9), wed), isFalse); // before
      expect(canAddCheckIn(t, dt(2026, 10, 20), nextWeek), isFalse); // after
      expect(canAddCheckIn(t, thu, wed), isFalse); // in the future
      expect(canAddCheckIn(t, tue.add(const Duration(hours: 1)), wed), isFalse);
      expect(canAddCheckIn(t.copyWith(templateId: null), wed, thu), isFalse);
    });

    test('reopening a counter at max takes back its latest check-in', () {
      final full = checkIn(checkIn(checkIn(gym(), tue), wed), thu);
      final back = reopen(full, dt(2026, 10, 16));
      expect(back.status, TaskStatus.open);
      expect(back.checkIns, [tue, wed]);
    });

    test('a Done from before check-ins counts one unit and reopens', () {
      final legacy = taskWith(
        start: dt(2026, 6, 27),
        end: dt(2026, 6, 27, 12),
        status: TaskStatus.done,
      );
      expect(legacy.doneUnits, 1);
      expect(reopen(legacy, morning).status, TaskStatus.open);
    });

    test('a goal edit re-resolves the running instance', () {
      final two = checkIn(checkIn(gym(), tue), wed);
      final raised = applyGoal(two, const Goal(min: 3, max: 4), thu)!;
      expect((raised.status, raised.isMet), (TaskStatus.open, false));
      final capped = applyGoal(two, const Goal(min: 1, max: 2), thu)!;
      expect(capped.status, TaskStatus.done);
      expect(capped.resolvedAt, wed); // the check-in that reaches the new cap
      expect(applyGoal(capped, const Goal(min: 2, max: 3), thu), isNull);
    });

    test('reminders stop at min or at max, as the goal says', () {
      final met = checkIn(checkIn(gym(), tue), wed);
      expect(wantsReminders(gym()), isTrue);
      expect(wantsReminders(checkIn(gym(), tue)), isTrue); // below min
      expect(wantsReminders(met), isFalse); // remind till min: done
      final tillMax = checkIn(
        checkIn(
          gym(goal: const Goal(min: 2, max: 3, remindTill: RemindTill.max)),
          tue,
        ),
        wed,
      );
      expect(wantsReminders(tillMax), isTrue); // met, but till max
      expect(wantsReminders(checkIn(tillMax, thu)), isFalse); // Done
      expect(wantsReminders(taskWith(status: TaskStatus.done)), isFalse);
    });

    test('only a 1-of-1 miss is corrected by the ring tap', () {
      final missed = expireIfDue(gym(), nextWeek)!;
      expect(canCorrectMiss(missed), isFalse);
      expect(canCorrectMiss(missed.copyWith(goal: Goal.single)), isTrue);
    });
  });
}
