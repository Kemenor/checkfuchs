import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// Short label for a window edge on a task tile pill (DESIGN_SYSTEM §3.6):
/// today → the clock time ("18:00"), tomorrow → "Tomorrow", within the week →
/// the short weekday ("Sat"), further out → a short date ("12 Jul"). The pill
/// renders it uppercase.
///
/// [isEnd] marks a window *end*: an end at exactly midnight means "by the end
/// of the previous day" (an evening habit's window ends at 00:00 — its due
/// day is today, not tomorrow), so classification backs up a minute and
/// midnight itself is shown as a day word, never "00:00".
String whenLabel(
  AppLocalizations l10n,
  String locale,
  DateTime now,
  DateTime t, {
  required bool isEnd,
}) {
  final isMidnight = t.hour == 0 && t.minute == 0;
  final classified = isEnd && isMidnight
      ? t.subtract(const Duration(minutes: 1))
      : t;

  int epochDay(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  final diff = epochDay(classified) - epochDay(now);

  if (diff <= 0) {
    // Today (or already past): the clock time carries the information;
    // a bare midnight boundary reads better as a word.
    return isMidnight ? l10n.pillToday : DateFormat.Hm(locale).format(t);
  }
  if (diff == 1) return l10n.pillTomorrow;
  if (diff < 7) return DateFormat.E(locale).format(classified);
  return DateFormat.MMMd(locale).format(classified);
}
