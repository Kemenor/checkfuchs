/// How a Template turns each occurrence date into a Task's `start`/`end` window
/// (design-concept §3.3). Pure.
library;

/// A resolved window. Either bound may be null only via the rules that allow it
/// (none here do — generated Tasks are always bounded, §2.3 invariant).
typedef Window = ({DateTime start, DateTime end});

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

/// Civil (DST-safe) offset from a day's midnight: whole days advance the
/// calendar date, the sub-day remainder sets the wall-clock time. Adding a raw
/// `Duration` instead would drift by an hour across a DST transition ("all day"
/// would end at 23:00 on the fall-back Sunday).
DateTime _atCivilOffset(DateTime day, Duration offset) {
  final days = offset.inDays;
  final rest = offset - Duration(days: days);
  return DateTime(
    day.year,
    day.month,
    day.day + days,
    rest.inHours,
    rest.inMinutes % 60,
    rest.inSeconds % 60,
  );
}

sealed class WindowRule {
  const WindowRule();

  /// Resolve to a concrete window for [occurrence]. [nextOccurrence] is used
  /// only by [UntilNextOccurrence] (the default back-to-back window).
  Window resolve(DateTime occurrence, DateTime nextOccurrence);
}

/// A band on the occurrence day — e.g. *morning* = 06:00–12:00. The four
/// presets tile the day: night 00–06, morning 06–12, afternoon 12–18,
/// evening 18–24. [from]/[to] are
/// wall-clock offsets from the occurrence's midnight, resolved civilly so the
/// band keeps its clock times across DST transitions.
class Slice extends WindowRule {
  const Slice({required this.from, required this.to});

  final Duration from;
  final Duration to;

  static const allDay = Slice(from: Duration.zero, to: Duration(hours: 24));
  static const night = Slice(from: Duration.zero, to: Duration(hours: 6));
  static const morning = Slice(
    from: Duration(hours: 6),
    to: Duration(hours: 12),
  );
  static const afternoon = Slice(
    from: Duration(hours: 12),
    to: Duration(hours: 18),
  );
  static const evening = Slice(
    from: Duration(hours: 18),
    to: Duration(hours: 24),
  );

  @override
  Window resolve(DateTime occurrence, DateTime _) {
    final base = _midnight(occurrence);
    return (start: _atCivilOffset(base, from), end: _atCivilOffset(base, to));
  }
}

/// `start = occurrence midnight`, `end = start + length` (e.g. "active for the
/// week from the occurrence"). The length is resolved civilly: its day part
/// counts calendar days, so "7 days" ends at the same wall-clock time even when
/// a DST transition falls inside the window.
class FixedDuration extends WindowRule {
  const FixedDuration(this.length);

  final Duration length;

  @override
  Window resolve(DateTime occurrence, DateTime _) {
    final base = _midnight(occurrence);
    return (start: base, end: _atCivilOffset(base, length));
  }
}

/// The default: `start = occurrence midnight`, `end = the next occurrence
/// midnight` — back-to-back, the classic daily habit.
class UntilNextOccurrence extends WindowRule {
  const UntilNextOccurrence();

  @override
  Window resolve(DateTime occurrence, DateTime nextOccurrence) =>
      (start: _midnight(occurrence), end: _midnight(nextOccurrence));
}
