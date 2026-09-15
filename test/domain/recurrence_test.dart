import 'package:checkfuchs/domain/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);
List<DateTime> firstN(Recurrence r, int n, {DateTime? from}) =>
    occurrences(r, from: from).take(n).toList();

void main() {
  _cycleTests();
  group('daily', () {
    test('every day', () {
      expect(firstN(Recurrence.daily(d(2026, 6, 27)), 3), [
        d(2026, 6, 27),
        d(2026, 6, 28),
        d(2026, 6, 29),
      ]);
    });

    test('every 3 days, anchored', () {
      expect(firstN(Recurrence.daily(d(2026, 6, 27), interval: 3), 3), [
        d(2026, 6, 27),
        d(2026, 6, 30),
        d(2026, 7, 3),
      ]);
    });
  });

  group('weekly', () {
    test('every other Saturday from a Saturday anchor', () {
      final r = Recurrence.weekly(
        d(2026, 6, 27),
        interval: 2,
        on: {Weekday.sat},
      );
      expect(firstN(r, 3), [d(2026, 6, 27), d(2026, 7, 11), d(2026, 7, 25)]);
    });

    test('Mon + Thu weekly, anchored mid-week (Wed)', () {
      final r = Recurrence.weekly(
        d(2026, 6, 24),
        on: {Weekday.mon, Weekday.thu},
      );
      // anchor Wed 24th: Mon 22nd is before the anchor (skipped), Thu 25th kept.
      expect(firstN(r, 4), [
        d(2026, 6, 25),
        d(2026, 6, 29),
        d(2026, 7, 2),
        d(2026, 7, 6),
      ]);
    });

    test('empty byWeekday defaults to the anchor weekday', () {
      final r = Recurrence.weekly(d(2026, 6, 24)); // a Wednesday
      expect(firstN(r, 2), [d(2026, 6, 24), d(2026, 7, 1)]);
    });
  });

  group('monthly', () {
    test('on the 25th', () {
      final r = Recurrence.monthly(d(2026, 6, 10), day: 25);
      expect(firstN(r, 3), [d(2026, 6, 25), d(2026, 7, 25), d(2026, 8, 25)]);
    });

    test('last day of month (non-leap year)', () {
      final r = Recurrence.monthly(d(2026, 1, 31), day: lastDayOfMonth);
      expect(firstN(r, 4), [
        d(2026, 1, 31),
        d(2026, 2, 28),
        d(2026, 3, 31),
        d(2026, 4, 30),
      ]);
    });

    test('day 31 clamps to the real last day', () {
      final r = Recurrence.monthly(d(2026, 1, 31), day: 31);
      expect(firstN(r, 4), [
        d(2026, 1, 31),
        d(2026, 2, 28),
        d(2026, 3, 31),
        d(2026, 4, 30),
      ]);
    });

    test('last day hits Feb 29 in a leap year', () {
      final r = Recurrence.monthly(d(2028, 1, 31), day: lastDayOfMonth);
      expect(firstN(r, 2), [d(2028, 1, 31), d(2028, 2, 29)]);
    });

    test('every 2 months, anchored', () {
      final r = Recurrence.monthly(d(2026, 1, 15), interval: 2);
      expect(firstN(r, 3), [d(2026, 1, 15), d(2026, 3, 15), d(2026, 5, 15)]);
    });
  });

  group('yearly', () {
    test('13th of March', () {
      final r = Recurrence.yearly(d(2026, 3, 13), month: 3, day: 13);
      expect(firstN(r, 3), [d(2026, 3, 13), d(2027, 3, 13), d(2028, 3, 13)]);
    });
  });

  group('lookups', () {
    final monthly25 = Recurrence.monthly(d(2026, 6, 10), day: 25);

    test('occurrenceOnOrAfter returns same day when it is an occurrence', () {
      expect(occurrenceOnOrAfter(monthly25, d(2026, 6, 25)), d(2026, 6, 25));
    });

    test('occurrenceOnOrAfter skips to the next when between', () {
      expect(occurrenceOnOrAfter(monthly25, d(2026, 7, 1)), d(2026, 7, 25));
    });

    test('occurrenceAfter is strictly after', () {
      expect(occurrenceAfter(monthly25, d(2026, 6, 25)), d(2026, 7, 25));
    });

    test(
      'from in the middle of a weekly interval lands on the next active day',
      () {
        final r = Recurrence.weekly(
          d(2026, 6, 27),
          interval: 2,
          on: {Weekday.sat},
        );
        expect(occurrenceOnOrAfter(r, d(2026, 7, 12)), d(2026, 7, 25));
      },
    );
  });
}

void _cycleTests() {
  group('currentCycleStart', () {
    test('finds the cycle that contains now, behind the anchor', () {
      // Weekly on Mondays, anchored on a Wednesday: this week's Monday.
      final r = Recurrence.weekly(DateTime(2026, 7, 8), on: {Weekday.mon});
      expect(
        currentCycleStart(r, DateTime(2026, 7, 8, 10)),
        DateTime(2026, 7, 6),
      );
      // Every other week keeps the phase of the anchor's week.
      final biweekly = Recurrence.weekly(
        DateTime(2026, 7, 8),
        on: {Weekday.mon},
        interval: 2,
      );
      expect(
        currentCycleStart(biweekly, DateTime(2026, 7, 8, 10)),
        DateTime(2026, 7, 6),
      );
      // Monthly on the 5th, anchored on the 20th.
      final monthly = Recurrence.monthly(DateTime(2026, 7, 20), day: 5);
      expect(
        currentCycleStart(monthly, DateTime(2026, 7, 20)),
        DateTime(2026, 7, 5),
      );
      // A month-end day clamps instead of rolling over.
      final endOfMonth = Recurrence.monthly(DateTime(2026, 3, 31));
      expect(
        currentCycleStart(endOfMonth, DateTime(2026, 3, 15)),
        DateTime(2026, 2, 28),
      );
      // Yearly, before this year's date.
      final yearly = Recurrence.yearly(DateTime(2026, 9, 15), month: 3, day: 1);
      expect(
        currentCycleStart(yearly, DateTime(2026, 9, 15)),
        DateTime(2026, 3, 1),
      );
      // A future anchor has no running cycle.
      expect(
        currentCycleStart(
          Recurrence.weekly(DateTime(2026, 8, 3), on: {Weekday.mon}),
          DateTime(2026, 7, 8),
        ),
        isNull,
      );
    });

    test('withAnchor pins the implicit fields so the phase cannot shift', () {
      final r = Recurrence.monthly(DateTime(2026, 3, 31));
      final moved = r.withAnchor(DateTime(2026, 2, 28));
      expect(moved.byMonthDay, 31); // the anchor's day, not February's 28
      final weekly = Recurrence.weekly(DateTime(2026, 7, 8)); // a Wednesday
      expect(weekly.withAnchor(DateTime(2026, 7, 1)).byWeekday, {Weekday.wed});
    });
  });
}
