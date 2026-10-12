import 'package:checkfuchs/domain/goal.dart';
import 'package:checkfuchs/domain/recurrence.dart';
import 'package:checkfuchs/domain/window_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final mon = DateTime(2026, 10, 12);

  group('windowSpanDays', () {
    test('daily all-day touches one day; weekly until-next touches seven', () {
      expect(
        windowSpanDays(Recurrence.daily(mon), const UntilNextOccurrence()),
        1,
      );
      expect(
        windowSpanDays(
          Recurrence.weekly(mon, on: {Weekday.mon}),
          const UntilNextOccurrence(),
        ),
        7,
      );
    });

    test('a weekly morning slice touches one day', () {
      expect(
        windowSpanDays(
          Recurrence.weekly(mon, on: {Weekday.mon}),
          Slice.morning,
        ),
        1,
      );
    });
  });

  group('fitTo', () {
    const gym = Goal(min: 2, max: 3, oncePerDay: true);

    test('keeps once a day where the window has room', () {
      expect(gym.fitTo(7), gym);
      expect(gym.fitTo(2), gym);
    });

    test('drops once a day where it can never be met', () {
      expect(gym.fitTo(1).oncePerDay, isFalse); // a one-day window
      expect(
        const Goal(min: 5, max: 5, oncePerDay: true).fitTo(2).oncePerDay,
        isFalse,
      ); // five in a weekend
    });
  });

  test('shapes', () {
    expect(Goal.single.isSingle, isTrue);
    expect(Goal.single.isRange, isFalse);
    expect(const Goal.times(2).isRange, isFalse);
    expect(const Goal(min: 2, max: 3).isRange, isTrue);
    expect(const Goal(min: 8, max: null).isRange, isTrue);
    expect(const Goal(min: 8, max: null).capped(100), isFalse);
  });
}
