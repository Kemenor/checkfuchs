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

/// Several bands on the occurrence day — "morning *or* evening": the task is
/// done once in any of them. Resolves to the envelope (first `from` → last
/// `to`); the gaps are carried by [bands] and honoured by `phaseOf`.
class MultiSlice extends WindowRule {
  MultiSlice(Iterable<Band> bands)
    : bands = Band.normalize(bands),
      assert(bands.isNotEmpty, 'MultiSlice needs at least one band');

  @override
  final List<Band> bands;

  @override
  Window resolve(DateTime occurrence, DateTime _) {
    final base = _midnight(occurrence);
    return (
      start: _atCivilOffset(base, bands.first.from),
      end: _atCivilOffset(base, bands.last.to),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MultiSlice &&
      other.bands.length == bands.length &&
      [
        for (var i = 0; i < bands.length; i++) other.bands[i] == bands[i],
      ].every((e) => e);

  @override
  int get hashCode => Object.hashAll(bands);
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
/// midnight` — back-to-back, the classic daily habit.
class UntilNextOccurrence extends WindowRule {
  const UntilNextOccurrence();

  @override
  Window resolve(DateTime occurrence, DateTime nextOccurrence) =>
      (start: _midnight(occurrence), end: _midnight(nextOccurrence));

  @override
  bool operator ==(Object other) => other is UntilNextOccurrence;

  @override
  int get hashCode => 0x0417;
}
