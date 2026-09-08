import 'package:checkfuchs/domain/analytics.dart';
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
}
