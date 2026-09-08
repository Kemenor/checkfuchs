import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../domain/recurrence.dart';
import '../l10n/app_localizations.dart';

/// Localized counterpart of the pure-domain `recurrenceSummary()`
/// (lib/domain/recurrence_summary.dart): the same sentences, but built from
/// [AppLocalizations] keys plus intl's localized weekday/month names — the live
/// banner in the recurrence editor. The domain function stays English-only
/// (its unit tests pin the English copy); this one follows the app locale.
String localizedRecurrenceSummary(BuildContext context, Recurrence? r) {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  if (r == null) return l10n.summaryNoRepeat;

  final n = r.interval;
  switch (r.freq) {
    case Freq.daily:
      return l10n.summaryDaily(n);

    case Freq.weekly:
      final days =
          (r.byWeekday.isEmpty ? {Weekday.fromDateTime(r.anchor)} : r.byWeekday)
              .toList()
            ..sort((a, b) => a.dateTimeWeekday - b.dateTimeWeekday);
      if (n == 1 && days.length == 1) {
        return l10n.summaryWeeklySingle(_weekdayLong(locale, days.first));
      }
      final list = days.map((d) => _weekdayShort(locale, d)).join(', ');
      return l10n.summaryWeeklyOn(n, list);

    case Freq.monthly:
      final day = r.byMonthDay ?? r.anchor.day;
      return day == lastDayOfMonth
          ? l10n.summaryMonthlyLastDay(n)
          : l10n.summaryMonthlyDay(n, day);

    case Freq.yearly:
      final month = r.byMonth ?? r.anchor.month;
      final day = r.byMonthDay ?? r.anchor.day;
      final monthName = localizedMonthName(locale, month);
      return day == lastDayOfMonth
          ? l10n.summaryYearlyLastDay(n, _ofMonth(locale, monthName))
          : l10n.summaryYearly(n, day, monthName);
  }
}

/// The full localized month name (1 = January) via intl.
String localizedMonthName(String locale, int month) =>
    DateFormat.MMMM(locale).format(DateTime(2001, month));

// 2001-01-01 is a Monday, so day `1 + index` has the wanted weekday.
DateTime _weekdayRef(Weekday d) => DateTime(2001, 1, 1 + d.index);

String _weekdayLong(String locale, Weekday d) =>
    DateFormat.EEEE(locale).format(_weekdayRef(d));

String _weekdayShort(String locale, Weekday d) =>
    DateFormat.E(locale).format(_weekdayRef(d));

/// French needs its elided preposition baked into the month argument of the
/// yearly last-day sentence ("de mars" but "d'avril"); other locales carry the
/// preposition in the translation itself and take the bare name.
String _ofMonth(String locale, String month) {
  if (!locale.startsWith('fr')) return month;
  const vowels = 'aàâeéèêëiîïoôöuûü';
  return vowels.contains(month[0].toLowerCase()) ? "d'$month" : 'de $month';
}
