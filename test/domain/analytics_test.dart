import 'package:checkfuchs/domain/analytics.dart';
import 'package:checkfuchs/domain/goal.dart';
import 'package:checkfuchs/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';

Task t(int day, TaskStatus s) => Task(
  name: 'x',
  status: s,
  occurrence: DateTime(2026, 6, day),
  createdAt: DateTime(2026, 6, 1),
  resolvedAt: DateTime(2026, 6, day),
);

void main() {
  test('no resolved instances → empty, rate 1.0', () {
    final s = computeStats([t(1, TaskStatus.open)]);
    expect(s.hasData, isFalse);
    expect(s.completionRate, 1.0);
    expect(s.currentStreak, 0);
  });

  test('completion rate excludes skips', () {
    final s = computeStats([
      t(1, TaskStatus.done),
      t(2, TaskStatus.done),
      t(3, TaskStatus.done),
      t(4, TaskStatus.missed),
      t(5, TaskStatus.skipped),
      t(6, TaskStatus.skipped),
    ]);
    expect(s.done, 3);
    expect(s.missed, 1);
    expect(s.skipped, 2);
    expect(s.completionRate, closeTo(0.75, 1e-9)); // 3 / (3+1)
  });

  test('streak: Skip preserves, Missed breaks', () {
    // occurrences asc; most recent = day 6.
    final s = computeStats([
      t(1, TaskStatus.done),
      t(2, TaskStatus.missed),
      t(3, TaskStatus.done),
      t(4, TaskStatus.skipped),
      t(5, TaskStatus.done),
      t(6, TaskStatus.done),
    ]);
    // from day6 back: done, done, skip(neutral), done, missed(break) → 3
    expect(s.currentStreak, 3);
  });

  test('consecutiveMisses is the leading run of misses (avoidance signal)', () {
    final s = computeStats([
      t(1, TaskStatus.done),
      t(2, TaskStatus.missed),
      t(3, TaskStatus.missed),
      t(4, TaskStatus.missed),
    ]);
    expect(s.consecutiveMisses, 3); // days 4,3,2
    expect(s.currentStreak, 0);
  });

  group('counters (§3.7, §8)', () {
    const gym = Goal(min: 2, max: 3);
    Task week(int day, TaskStatus s, int checkIns) => t(day, s).copyWith(
      goal: gym,
      checkIns: [for (var i = 0; i < checkIns; i++) DateTime(2026, 6, day, i)],
    );

    test('done and missed count check-ins, not cycles', () {
      final s = computeStats([
        week(1, TaskStatus.done, 3), // 3 done
        week(8, TaskStatus.missed, 1), // 1 done + 1 missed
        week(15, TaskStatus.missed, 0), // 2 missed
      ]);
      expect((s.done, s.missed), (4, 3));
      expect(s.completionRate, closeTo(4 / 7, 1e-9));
    });

    test('a running cycle counts its check-ins at once', () {
      final s = computeStats([week(1, TaskStatus.open, 1)]);
      expect((s.done, s.missed), (1, 0));
      expect(s.hasData, isTrue);
    });

    test('the streak counts met cycles, a running met one included', () {
      final s = computeStats([
        week(1, TaskStatus.missed, 1),
        week(8, TaskStatus.done, 2),
        week(15, TaskStatus.done, 3),
        week(22, TaskStatus.open, 2), // met, can't fail any more
      ]);
      expect(s.currentStreak, 3);
      final below = computeStats([
        week(15, TaskStatus.done, 3),
        week(22, TaskStatus.open, 1), // not met yet: neither helps nor breaks
      ]);
      expect(below.currentStreak, 1);
    });
  });
}
