/// How a Template turns each occurrence date into a Task's `start`/`end` window
/// (design-concept §3.3). Pure.
library;

/// A resolved window. Either bound may be null only via the rules that allow it
/// (none here do — generated Tasks are always bounded, §2.3 invariant).
typedef Window = ({DateTime start, DateTime end});

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

sealed class WindowRule {
  const WindowRule();

  /// Resolve to a concrete window for [occurrence]. [nextOccurrence] is used
  /// only by [UntilNextOccurrence] (the default back-to-back window).
  Window resolve(DateTime occurrence, DateTime nextOccurrence);
}

/// A band on the occurrence day — e.g. *morning* = 00:00–12:00. [from]/[to] are
/// durations from the occurrence's midnight.
///
/// (DST caveat: on the ~2 transition days a year a duration-based band can be an
/// hour off; acceptable for v1, revisit if it ever bites.)
class Slice extends WindowRule {
  const Slice({required this.from, required this.to});

  final Duration from;
  final Duration to;

  static const allDay = Slice(from: Duration.zero, to: Duration(hours: 24));
  static const morning = Slice(from: Duration.zero, to: Duration(hours: 12));
  static const afternoon =
      Slice(from: Duration(hours: 12), to: Duration(hours: 18));
  static const evening = Slice(from: Duration(hours: 18), to: Duration(hours: 24));

  @override
  Window resolve(DateTime occurrence, DateTime _) {
    final base = _midnight(occurrence);
    return (start: base.add(from), end: base.add(to));
  }
}

/// `start = occurrence midnight`, `end = start + length` (e.g. "active for the
/// week from the occurrence").
class FixedDuration extends WindowRule {
  const FixedDuration(this.length);

  final Duration length;

  @override
  Window resolve(DateTime occurrence, DateTime _) {
    final base = _midnight(occurrence);
    return (start: base, end: base.add(length));
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
