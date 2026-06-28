import 'package:checkfuchs/domain/notification.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime dt(int y, int m, int d, [int h = 0]) => DateTime(y, m, d, h);

void main() {
  group('fireTime', () {
    final start = dt(2026, 6, 27, 8);
    final end = dt(2026, 6, 27, 12);

    test('at start', () {
      expect(const TaskNotification.atStart().fireTime(start: start, end: end),
          start);
    });

    test('upcoming (a day before start)', () {
      expect(
        const TaskNotification.atStart(offset: Duration(days: -1))
            .fireTime(start: start, end: end),
        dt(2026, 6, 26, 8),
      );
    });

    test('before due', () {
      expect(
        const TaskNotification.atEnd(offset: Duration(hours: -2))
            .fireTime(start: start, end: end),
        dt(2026, 6, 27, 10),
      );
    });

    test('absolute', () {
      final at = dt(2026, 7, 1, 9);
      expect(TaskNotification.absolute(at).fireTime(), at);
    });

    test('null when the anchor date is missing', () {
      expect(const TaskNotification.atStart().fireTime(end: end), isNull);
      expect(const TaskNotification.atEnd().fireTime(start: start), isNull);
    });
  });

  group('selectScheduled', () {
    final now = dt(2026, 6, 27, 9);
    ScheduledNotification at(int id, DateTime t) =>
        ScheduledNotification(taskId: id, fireAt: t);

    test('drops past, sorts soonest-first', () {
      final picked = selectScheduled([
        at(1, dt(2026, 6, 27, 8)), // past
        at(2, dt(2026, 6, 27, 12)),
        at(3, dt(2026, 6, 27, 10)),
      ], now);
      expect(picked.map((n) => n.taskId), [3, 2]);
    });

    test('caps at the limit (soonest kept)', () {
      final all = [for (var i = 0; i < 100; i++) at(i, now.add(Duration(minutes: i + 1)))];
      final picked = selectScheduled(all, now, cap: 64);
      expect(picked, hasLength(64));
      expect(picked.first.taskId, 0); // soonest
      expect(picked.last.taskId, 63);
    });
  });
}
