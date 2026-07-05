import 'package:checkfuchs/domain/recurrence.dart';
import 'package:checkfuchs/domain/recurrence_summary.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  test('null = doesn\'t repeat', () {
    expect(recurrenceSummary(null), "Doesn't repeat");
  });

  test('daily', () {
    expect(recurrenceSummary(Recurrence.daily(d(2026, 6, 27))), 'Every day');
    expect(
      recurrenceSummary(Recurrence.daily(d(2026, 6, 27), interval: 3)),
      'Every 3 days',
    );
  });

  test('weekly', () {
    expect(
      recurrenceSummary(Recurrence.weekly(d(2026, 6, 27), on: {Weekday.sat})),
      'Every Saturday',
    );
    expect(
      recurrenceSummary(
        Recurrence.weekly(d(2026, 6, 27), interval: 2, on: {Weekday.sat}),
      ),
      'Every 2 weeks on Sat',
    );
    expect(
      recurrenceSummary(
        Recurrence.weekly(d(2026, 6, 27), on: {Weekday.mon, Weekday.thu}),
      ),
      'Every week on Mon, Thu',
    );
  });

  test('monthly', () {
    expect(
      recurrenceSummary(Recurrence.monthly(d(2026, 6, 10), day: 25)),
      'On the 25th of every month',
    );
    expect(
      recurrenceSummary(
        Recurrence.monthly(d(2026, 6, 10), day: lastDayOfMonth),
      ),
      'On the last day of every month',
    );
    expect(
      recurrenceSummary(Recurrence.monthly(d(2026, 6, 1), interval: 2, day: 1)),
      'Every 2 months on the 1st',
    );
  });

  test('yearly', () {
    expect(
      recurrenceSummary(Recurrence.yearly(d(2026, 3, 13), month: 3, day: 13)),
      'Every year on 13 March',
    );
    expect(
      recurrenceSummary(
        Recurrence.yearly(d(2026, 2, 1), month: 2, day: lastDayOfMonth),
      ),
      'Every year on the last day of February',
    );
  });

  test('ordinals', () {
    expect(
      recurrenceSummary(Recurrence.monthly(d(2026, 1, 2), day: 2)),
      'On the 2nd of every month',
    );
    expect(
      recurrenceSummary(Recurrence.monthly(d(2026, 1, 3), day: 3)),
      'On the 3rd of every month',
    );
    expect(
      recurrenceSummary(Recurrence.monthly(d(2026, 1, 11), day: 11)),
      'On the 11th of every month',
    );
    expect(
      recurrenceSummary(Recurrence.monthly(d(2026, 1, 21), day: 21)),
      'On the 21st of every month',
    );
  });
}
