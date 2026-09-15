/// Recurrence — the curated, RRULE-shaped subset (design-concept §3.1) and the
/// pure occurrence generator over it.
///
/// Recurrence works on **calendar dates** (the occurrence days). A Template later
/// applies its window rule to turn each occurrence date into a Task's
/// `start`/`end` datetimes — that's not this file's job.
///
/// All date arithmetic is done by reconstructing `DateTime(y, m, d + n)` rather
/// than adding `Duration`s, so it stays correct across DST (a "day" is a civil
/// day, never 23/25 hours).
library;

enum Freq { daily, weekly, monthly, yearly }

enum Weekday {
  mon,
  tue,
  wed,
  thu,
  fri,
  sat,
  sun;

  /// `DateTime.weekday` convention: Mon = 1 … Sun = 7.
  int get dateTimeWeekday => index + 1;

  static Weekday fromDateTime(DateTime d) => Weekday.values[d.weekday - 1];
}

/// `byMonthDay` sentinel for "the last day of the month".
const int lastDayOfMonth = -1;

/// A recurrence rule. There is no `once` — one-offs are template-less Tasks.
class Recurrence {
  const Recurrence({
    required this.freq,
    required this.anchor,
    this.interval = 1,
    this.byWeekday = const {},
    this.byMonthDay,
    this.byMonth,
  }) : assert(interval >= 1, 'interval must be >= 1'),
       assert(
         byMonthDay == null ||
             byMonthDay == lastDayOfMonth ||
             (byMonthDay >= 1 && byMonthDay <= 31),
         'byMonthDay must be 1–31 or lastDayOfMonth',
       ),
       assert(
         byMonth == null || (byMonth >= 1 && byMonth <= 12),
         'byMonth must be 1–12',
       );

  /// every day.
  const Recurrence.daily(DateTime anchor, {int interval = 1})
    : this(freq: Freq.daily, anchor: anchor, interval: interval);

  /// weekly on the given days (defaults to the anchor's weekday if empty).
  const Recurrence.weekly(
    DateTime anchor, {
    int interval = 1,
    Set<Weekday> on = const {},
  }) : this(
         freq: Freq.weekly,
         anchor: anchor,
         interval: interval,
         byWeekday: on,
       );

  /// monthly on a day-of-month ([lastDayOfMonth] for the last day; defaults to
  /// the anchor's day).
  const Recurrence.monthly(DateTime anchor, {int interval = 1, int? day})
    : this(
        freq: Freq.monthly,
        anchor: anchor,
        interval: interval,
        byMonthDay: day,
      );

  /// yearly on a month + day (defaults to the anchor's month/day).
  const Recurrence.yearly(
    DateTime anchor, {
    int interval = 1,
    int? month,
    int? day,
  }) : this(
         freq: Freq.yearly,
         anchor: anchor,
         interval: interval,
         byMonth: month,
         byMonthDay: day,
       );

  final Freq freq;
  final int interval;

  /// The reference date intervals count from. Load-bearing for any `interval > 1`.
  final DateTime anchor;

  /// Weekly only — which weekday(s). Empty ⇒ the anchor's weekday.
  final Set<Weekday> byWeekday;

  /// Monthly/yearly — day of month, or [lastDayOfMonth]. Null ⇒ the anchor's day.
  final int? byMonthDay;

  /// Yearly only — month (1–12). Null ⇒ the anchor's month.
  final int? byMonth;

  /// The same rule anchored at [date]. The implicit fields (weekday, day of
  /// month, month — the ones that default to the anchor's) are pinned first,
  /// so moving the anchor can never shift the phase.
  Recurrence withAnchor(DateTime date) {
    final a = _dateOnly(anchor);
    return Recurrence(
      freq: freq,
      anchor: _dateOnly(date),
      interval: interval,
      byWeekday: freq == Freq.weekly && byWeekday.isEmpty
          ? {Weekday.fromDateTime(a)}
          : byWeekday,
      byMonthDay: freq == Freq.monthly || freq == Freq.yearly
          ? (byMonthDay ?? a.day)
          : byMonthDay,
      byMonth: freq == Freq.yearly ? (byMonth ?? a.month) : byMonth,
    );
  }
}

// ---------------------------------------------------------------------------
// Generator
// ---------------------------------------------------------------------------

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// DST-safe whole-day distance via UTC ordinals.
int _epochDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

DateTime _mondayOf(DateTime d) => _addDays(d, -(d.weekday - 1));

/// Resolve a day-of-month against a real month (clamp overflow; [lastDayOfMonth]).
/// Out-of-range values that slipped past validation (release builds skip the
/// asserts) are clamped rather than rolled into a neighbouring month.
int _resolveDay(int year, int month, int day) {
  final dim = _daysInMonth(year, month);
  if (day == lastDayOfMonth) return dim;
  if (day < 1) return 1;
  return day < dim ? day : dim;
}

/// The occurrence dates of [r] in ascending order, starting at the later of the
/// anchor and [from]. The sequence is **infinite** — take what you need.
Iterable<DateTime> occurrences(Recurrence r, {DateTime? from}) sync* {
  final anchor = _dateOnly(r.anchor);
  final lower = from == null
      ? anchor
      : (_dateOnly(from).isAfter(anchor) ? _dateOnly(from) : anchor);

  bool ok(DateTime d) => !d.isBefore(anchor) && !d.isBefore(lower);

  switch (r.freq) {
    case Freq.daily:
      final gap = _daysBetween(anchor, lower);
      var k = gap <= 0 ? 0 : (gap + r.interval - 1) ~/ r.interval; // ceil
      while (true) {
        yield _addDays(anchor, k * r.interval);
        k++;
      }

    case Freq.weekly:
      final days =
          (r.byWeekday.isEmpty ? {Weekday.fromDateTime(anchor)} : r.byWeekday)
              .toList()
            ..sort((a, b) => a.dateTimeWeekday - b.dateTimeWeekday);
      final anchorMonday = _mondayOf(anchor);
      final weeksToLower = _daysBetween(anchorMonday, _mondayOf(lower)) ~/ 7;
      final startStep = weeksToLower <= 0 ? 0 : weeksToLower ~/ r.interval;
      var weekMonday = _addDays(anchorMonday, startStep * r.interval * 7);
      while (true) {
        for (final wd in days) {
          final occ = _addDays(weekMonday, wd.dateTimeWeekday - 1);
          if (ok(occ)) yield occ;
        }
        weekMonday = _addDays(weekMonday, 7 * r.interval);
      }

    case Freq.monthly:
      final anchorMi = anchor.year * 12 + (anchor.month - 1);
      final lowerMi = lower.year * 12 + (lower.month - 1);
      final startK = lowerMi <= anchorMi
          ? 0
          : (lowerMi - anchorMi) ~/ r.interval;
      var k = startK;
      while (true) {
        final mi = anchorMi + k * r.interval;
        final y = mi ~/ 12;
        final m = mi % 12 + 1;
        final occ = DateTime(
          y,
          m,
          _resolveDay(y, m, r.byMonthDay ?? anchor.day),
        );
        if (ok(occ)) yield occ;
        k++;
      }

    case Freq.yearly:
      final month = r.byMonth ?? anchor.month;
      final day = r.byMonthDay ?? anchor.day;
      final startK = lower.year <= anchor.year
          ? 0
          : (lower.year - anchor.year) ~/ r.interval;
      var k = startK;
      while (true) {
        final y = anchor.year + k * r.interval;
        final occ = DateTime(y, month, _resolveDay(y, month, day));
        if (ok(occ)) yield occ;
        k++;
      }
  }
}

int _daysBetween(DateTime a, DateTime b) => _epochDay(b) - _epochDay(a);

/// The first occurrence on or after [from].
DateTime occurrenceOnOrAfter(Recurrence r, DateTime from) =>
    occurrences(r, from: from).first;

/// The first occurrence strictly after [date].
DateTime occurrenceAfter(Recurrence r, DateTime date) =>
    occurrences(r, from: _addDays(_dateOnly(date), 1)).first;

/// The slot of the cycle that contains [now] — *even when that slot precedes
/// the anchor*. A series created mid-cycle (weekly on Mondays, made on a
/// Wednesday) has its first occurrence next week, but the cycle it belongs
/// to started on Monday; this is that Monday. Null when [now] lies before
/// the rule's first cycle (a deliberately future start).
DateTime? currentCycleStart(Recurrence r, DateTime now) =>
    lastOccurrenceOnOrBefore(_rewoundOneCycle(r), now);

/// [r] with its anchor moved back one whole interval period — same phase,
/// one cycle of headroom, so the generator will also yield the slots the
/// anchor was cutting off.
Recurrence _rewoundOneCycle(Recurrence r) {
  final a = _dateOnly(r.anchor);
  return switch (r.freq) {
    Freq.daily => r.withAnchor(_addDays(a, -r.interval)),
    Freq.weekly => r.withAnchor(_addDays(a, -7 * r.interval)),
    Freq.monthly => r.withAnchor(_monthsBefore(a, r.interval)),
    Freq.yearly => r.withAnchor(
      DateTime(
        a.year - r.interval,
        a.month,
        _resolveDay(a.year - r.interval, a.month, a.day),
      ),
    ),
  };
}

/// [n] months before [a], clamping the day into the shorter month instead of
/// rolling over into the next one (31 Mar − 1 month = 28 Feb, never 3 Mar).
DateTime _monthsBefore(DateTime a, int n) {
  final mi = a.year * 12 + (a.month - 1) - n;
  final y = mi ~/ 12;
  final m = mi % 12 + 1;
  return DateTime(y, m, _resolveDay(y, m, a.day));
}

/// The latest occurrence on or before [date], or null if [date] precedes the
/// first occurrence. Iterates from the anchor — cheap when the anchor is near
/// [date] (the generation use-case).
DateTime? lastOccurrenceOnOrBefore(Recurrence r, DateTime date) {
  final target = _dateOnly(date);
  DateTime? last;
  for (final occ in occurrences(r)) {
    if (occ.isAfter(target)) break;
    last = occ;
  }
  return last;
}
