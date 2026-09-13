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

  /// The active bands inside the resolved window, or null when the whole
  /// span is active. Only [MultiSlice] has gaps.
  List<Band>? get bands => null;
}

/// A wall-clock band, as offsets from a day's midnight (`to` may be 24h).
/// The unit a [MultiSlice] is made of, and what a Task stores when its
/// window has gaps.
class Band {
  const Band({required this.from, required this.to})
    : assert(from < to, 'Band must be non-empty');

  final Duration from;
  final Duration to;

  /// Whether [now] falls inside this band on its own civil day.
  bool contains(DateTime now) {
    final day = _midnight(now);
    return !now.isBefore(_atCivilOffset(day, from)) &&
        now.isBefore(_atCivilOffset(day, to));
  }

  /// Merge overlapping / touching bands into a sorted, disjoint list.
  static List<Band> normalize(Iterable<Band> bands) {
    final sorted = bands.toList()..sort((a, b) => a.from.compareTo(b.from));
    final out = <Band>[];
    for (final b in sorted) {
      if (out.isNotEmpty && b.from <= out.last.to) {
        final last = out.removeLast();
        out.add(Band(from: last.from, to: b.to > last.to ? b.to : last.to));
      } else {
        out.add(b);
      }
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is Band && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'Band($from–$to)';
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

  /// This slice as a [Band] (the unit [MultiSlice] is made of).
  Band get asBand => Band(from: from, to: to);

  @override
  bool operator ==(Object other) =>
      other is Slice && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  Window resolve(DateTime occurrence, DateTime _) {
    final base = _midnight(occurrence);
    return (start: _atCivilOffset(base, from), end: _atCivilOffset(base, to));
  }
}

/// Bands repeated on each of [days] consecutive days from the occurrence —
/// "morning *or* evening" (one day), or "mornings, for the 2 days of the
/// weekend". The task is done once in any band of any day. Resolves to the
/// envelope (first `from` on day 1 → last `to` on day [days]); the gaps —
/// between bands and between days — are carried by [bands] (which
/// `Band.contains` checks per civil day) and honoured by `phaseOf`.
class MultiSlice extends WindowRule {
  MultiSlice(Iterable<Band> bands, {this.days = 1})
    : bands = Band.normalize(bands),
      assert(bands.isNotEmpty, 'MultiSlice needs at least one band'),
      assert(days >= 1, 'MultiSlice spans at least one day');

  @override
  final List<Band> bands;

  /// How many consecutive days the bands repeat on.
  final int days;

  @override
  Window resolve(DateTime occurrence, DateTime _) {
    final base = _midnight(occurrence);
    return (
      start: _atCivilOffset(base, bands.first.from),
      end: _atCivilOffset(base, Duration(days: days - 1) + bands.last.to),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MultiSlice &&
      other.days == days &&
      sameBands(other.bands, bands);

  @override
  int get hashCode => Object.hash(days, Object.hashAll(bands));
}

bool sameBands(List<Band>? a, List<Band>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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

  @override
  bool operator ==(Object other) =>
      other is FixedDuration && other.length == length;

  @override
  int get hashCode => length.hashCode;
}

/// The default: `start = occurrence midnight`, `end = the next occurrence
/// midnight` — back-to-back, the classic daily habit. With [bands] the same
/// span is active only inside those hours on each of its days ("any morning
/// this week" for a weekly habit): start = first `from` on the occurrence
/// day, end = last `to` on the day before the next occurrence.
class UntilNextOccurrence extends WindowRule {
  const UntilNextOccurrence() : bands = null;

  UntilNextOccurrence.withBands(Iterable<Band> bands)
    : bands = Band.normalize(bands);

  @override
  final List<Band>? bands;

  @override
  Window resolve(DateTime occurrence, DateTime nextOccurrence) {
    final b = bands;
    if (b == null || b.isEmpty) {
      return (start: _midnight(occurrence), end: _midnight(nextOccurrence));
    }
    final lastDay = _midnight(nextOccurrence).subtract(const Duration(days: 1));
    return (
      start: _atCivilOffset(_midnight(occurrence), b.first.from),
      end: _atCivilOffset(_midnight(lastDay), b.last.to),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UntilNextOccurrence && sameBands(other.bands, bands);

  @override
  int get hashCode =>
      Object.hash(0x0417, bands == null ? null : Object.hashAll(bands!));
}
