import 'package:checkfuchs/domain/window_rule.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day, [int h = 0, int min = 0]) =>
    DateTime(y, m, day, h, min);

void main() {
  // Windows must be *civil*: asserting date/hour components keeps the tests
  // TZ-agnostic — in a DST zone a raw-Duration implementation would end
  // "all day" at 23:00 or 01:00 on the transition days below.
  group('Slice across the EU fall-back day (2026-10-25)', () {
    test('allDay ends at the NEXT day\'s midnight', () {
      final w = Slice.allDay.resolve(d(2026, 10, 25), d(2026, 10, 26));
      expect(w.start, d(2026, 10, 25));
      expect(w.end.year, 2026);
      expect(w.end.month, 10);
      expect(w.end.day, 26);
      expect(w.end.hour, 0);
      expect(w.end.minute, 0);
    });

    test('morning ends at 12:00 wall clock on the same day', () {
      final w = Slice.morning.resolve(d(2026, 10, 25), d(2026, 10, 26));
      expect(w.start, d(2026, 10, 25));
      expect(w.end.day, 25);
      expect(w.end.hour, 12);
      expect(w.end.minute, 0);
    });
  });

  group('Slice across the EU spring-forward day (2026-03-29)', () {
    test('allDay ends at the NEXT day\'s midnight', () {
      final w = Slice.allDay.resolve(d(2026, 3, 29), d(2026, 3, 30));
      expect(w.start, d(2026, 3, 29));
      expect(w.end.month, 3);
      expect(w.end.day, 30);
      expect(w.end.hour, 0);
    });

    test('morning ends at 12:00 wall clock on the same day', () {
      final w = Slice.morning.resolve(d(2026, 3, 29), d(2026, 3, 30));
      expect(w.end.day, 29);
      expect(w.end.hour, 12);
    });
  });

  group('FixedDuration', () {
    test(
      '7 days ends 7 civil days later at midnight (spans spring-forward)',
      () {
        final w = const FixedDuration(
          Duration(days: 7),
        ).resolve(d(2026, 3, 25), d(2026, 4, 1));
        expect(w.start, d(2026, 3, 25));
        expect(w.end.month, 4);
        expect(w.end.day, 1);
        expect(w.end.hour, 0);
      },
    );

    test('7 days ends 7 civil days later at midnight (spans fall-back)', () {
      final w = const FixedDuration(
        Duration(days: 7),
      ).resolve(d(2026, 10, 20), d(2026, 10, 27));
      expect(w.end.month, 10);
      expect(w.end.day, 27);
      expect(w.end.hour, 0);
    });

    test('a sub-day remainder sets the wall-clock time', () {
      final w = const FixedDuration(
        Duration(days: 1, hours: 6),
      ).resolve(d(2026, 10, 25), d(2026, 10, 26));
      expect(w.end.day, 26);
      expect(w.end.hour, 6);
    });
  });

  group('UntilNextOccurrence', () {
    test('runs back-to-back from midnight to the next occurrence midnight', () {
      final w = const UntilNextOccurrence().resolve(
        d(2026, 10, 25, 9, 30),
        d(2026, 10, 26),
      );
      expect(w.start, d(2026, 10, 25)); // time-of-day stripped
      expect(w.end, d(2026, 10, 26));
    });
  });
}
