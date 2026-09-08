import 'package:checkfuchs/data/db/converters.dart';
import 'package:checkfuchs/domain/recurrence.dart';
import 'package:checkfuchs/domain/window_rule.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  group('RecurrenceConverter round-trips', () {
    const conv = RecurrenceConverter();

    Recurrence roundTrip(Recurrence r) => conv.fromSql(conv.toSql(r));

    test('daily with interval > 1, anchor preserved to the instant', () {
      final r = roundTrip(Recurrence.daily(d(2026, 6, 27), interval: 3));
      expect(r.freq, Freq.daily);
      expect(r.interval, 3);
      expect(r.anchor, d(2026, 6, 27));
      expect(r.byWeekday, isEmpty);
      expect(r.byMonthDay, isNull);
      expect(r.byMonth, isNull);
    });

    test('weekly with a byWeekday set', () {
      final r = roundTrip(
        Recurrence.weekly(
          d(2026, 6, 1),
          interval: 2,
          on: {Weekday.mon, Weekday.wed, Weekday.fri},
        ),
      );
      expect(r.freq, Freq.weekly);
      expect(r.interval, 2);
      expect(r.anchor, d(2026, 6, 1));
      expect(r.byWeekday, {Weekday.mon, Weekday.wed, Weekday.fri});
    });

    test('monthly on the last day of the month (byMonthDay: -1)', () {
      final r = roundTrip(
        Recurrence.monthly(d(2026, 1, 31), day: lastDayOfMonth),
      );
      expect(r.freq, Freq.monthly);
      expect(r.byMonthDay, lastDayOfMonth);
      expect(r.anchor, d(2026, 1, 31));
    });

    test('yearly with byMonth + byMonthDay + interval', () {
      final r = roundTrip(
        Recurrence.yearly(d(2026, 3, 13), interval: 4, month: 3, day: 13),
      );
      expect(r.freq, Freq.yearly);
      expect(r.interval, 4);
      expect(r.byMonth, 3);
      expect(r.byMonthDay, 13);
      expect(r.anchor, d(2026, 3, 13));
    });
  });

  group('WindowRuleConverter round-trips', () {
    const conv = WindowRuleConverter();

    WindowRule roundTrip(WindowRule w) => conv.fromSql(conv.toSql(w));

    test('Slice.morning keeps its offsets', () {
      final w = roundTrip(Slice.morning) as Slice;
      expect(w.from, const Duration(hours: 6));
      expect(w.to, const Duration(hours: 12));
    });

    test('a custom Slice keeps sub-hour offsets', () {
      final w =
          roundTrip(
                const Slice(
                  from: Duration(hours: 6, minutes: 30),
                  to: Duration(hours: 22, minutes: 15),
                ),
              )
              as Slice;
      expect(w.from, const Duration(hours: 6, minutes: 30));
      expect(w.to, const Duration(hours: 22, minutes: 15));
    });

    test('FixedDuration keeps its length', () {
      final w =
          roundTrip(const FixedDuration(Duration(days: 7))) as FixedDuration;
      expect(w.length, const Duration(days: 7));
    });

    test('UntilNextOccurrence survives the tag-only encoding', () {
      expect(
        roundTrip(const UntilNextOccurrence()),
        isA<UntilNextOccurrence>(),
      );
    });

    test('an unknown kind throws FormatException (fail loudly)', () {
      expect(() => conv.fromSql('{"kind":"bogus"}'), throwsFormatException);
    });
  });
}
