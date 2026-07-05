/// Plain-English summary of a recurrence rule (null = doesn't repeat) — the live
/// banner in the recurrence editor (design-concept §3.1, mockup 06-recurrence).
/// Pure, so it's unit-tested directly.
///
/// TODO(l10n): currently English-only; localising the connectives + ordinals
/// across en/de/fr/it is its own task (intl supplies weekday/month names).
library;

import 'recurrence.dart';

const _weekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

String recurrenceSummary(Recurrence? r) {
  if (r == null) return "Doesn't repeat";
  final n = r.interval;
  switch (r.freq) {
    case Freq.daily:
      return n == 1 ? 'Every day' : 'Every $n days';

    case Freq.weekly:
      final days =
          (r.byWeekday.isEmpty ? {Weekday.fromDateTime(r.anchor)} : r.byWeekday)
              .toList()
            ..sort((a, b) => a.dateTimeWeekday - b.dateTimeWeekday);
      if (n == 1 && days.length == 1) {
        return 'Every ${_weekdayLong[days.first.index]}';
      }
      final list = days.map((d) => _weekdayShort[d.index]).join(', ');
      return 'Every ${n == 1 ? 'week' : '$n weeks'} on $list';

    case Freq.monthly:
      final day = r.byMonthDay ?? r.anchor.day;
      final phrase = day == lastDayOfMonth
          ? 'the last day'
          : 'the ${_ordinal(day)}';
      return n == 1
          ? 'On $phrase of every month'
          : 'Every $n months on $phrase';

    case Freq.yearly:
      final month = r.byMonth ?? r.anchor.month;
      final day = r.byMonthDay ?? r.anchor.day;
      final monthName = _monthLong[month - 1];
      final years = n == 1 ? 'year' : '$n years';
      return day == lastDayOfMonth
          ? 'Every $years on the last day of $monthName'
          : 'Every $years on $day $monthName';
  }
}
