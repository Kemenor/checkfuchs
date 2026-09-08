import 'recurrence.dart';
import 'task.dart';
import 'template.dart';

/// The per-Template reconcile — the pure heart of generation (design-concept
/// §3.4, PLAN "the engine"). Given a Template, its existing materialised Tasks,
/// and `now`, it:
///   1. expires any open Task whose window has passed → `Missed`;
///   2. ensures **exactly one open instance** exists, back-filling each skipped
///      occurrence as `Missed` until it reaches the current (not-yet-passed) one.
///
/// Back-fill is **gate-aware** (§3.5, §6): an occurrence whose generation would
/// have been suppressed at the time — its window started inside a vacation
/// period, or it ended before the template's resume point — is stepped over
/// without materialising anything. Pausing or going on vacation never *creates*
/// `Missed` records ("not done is data, never punishment").
///
/// Pure and idempotent: feeding its output back in produces no further changes.
/// The DB/repository persists [ReconcileResult.changed]; this file does no I/O.

/// An absolute period, e.g. one vacation row. Both bounds inclusive.
typedef DatePeriod = ({DateTime start, DateTime end});

/// Tasks created or modified by a reconcile, in apply order. New instances have
/// `id == null` (the DB assigns one); modified instances keep their id.
class ReconcileResult {
  const ReconcileResult(this.changed);
  final List<Task> changed;

  bool get isEmpty => changed.isEmpty;
}

/// Safety bound on back-fill iterations (≈ years of a daily habit unopened).
/// A net against pathological loops, not a feature limit. On exhaustion the
/// loop stops early, so the **newest** occurrences (including the would-be
/// current instance) aren't created until the next reconcile advances further.
const int _maxBackfill = 1200;

ReconcileResult reconcileTemplate(
  Template t,
  List<Task> existing,
  DateTime now, {
  List<DatePeriod> vacations = const [],
}) {
  final changed = <Task>[];
  final working = [...existing];

  // 1. Sweep every open instance. Vacation-start auto-Skip first (§6, resolved
  //    open question 3): an open instance whose window *cannot survive* the
  //    vacation — its end falls inside one — is Skipped (neutral, streak-
  //    preserving) at the vacation start instead of decaying into a Miss. A
  //    window that outlasts the vacation stays open (still doable after the
  //    return). Then expiry runs unconditionally — even a paused template's
  //    open instance can still Miss (§3.5). One-off deadlines are untouched
  //    by all of this: this function only ever sees template instances.
  for (var i = 0; i < working.length; i++) {
    final open = working[i];
    if (open.isOpen) {
      final v = _vacationConsuming(open, vacations);
      if (v != null) {
        final at = open.start != null && open.start!.isAfter(v.start)
            ? open.start!
            : v.start;
        final skipped = open.copyWith(
          status: TaskStatus.skipped,
          resolvedAt: at,
        );
        working[i] = skipped;
        changed.add(skipped);
        continue;
      }
    }
    final missed = expireIfDue(working[i], now);
    if (missed != null) {
      working[i] = missed;
      changed.add(missed);
    }
  }

  // 2. Generation is gated by pause + vacation at `now` (§3.5, §6).
  final vacationActive = vacations.any(
    (v) => !now.isBefore(v.start) && !now.isAfter(v.end),
  );
  if (!t.generatesAt(now) || vacationActive) return ReconcileResult(changed);

  // The generation floor: nothing that ended before the template's resume
  // point is back-filled — the paused stretch produces no retroactive Misses.
  // `resumeOn` doubles as "when this template last resumed" (see Template).
  final floor = t.resumeOn;

  // Occurrence slots already filled by a stored Task (materialise-on-action
  // means a *future* slot can be stored, §3.4 — those are stepped over, never
  // used as a shortcut past unfilled earlier slots).
  final filled = {
    for (final x in working)
      if (x.occurrence != null) x.occurrence!,
  };

  // Walk forward from the first *gap*: advance a frontier through the
  // contiguous run of filled slots (cheap Set lookups over stored history),
  // then generate from the first unfilled one. Starting from the *latest*
  // filled slot instead would let a pre-resolved future slot shortcut past
  // unfilled earlier days — they'd silently vanish from history.
  DateTime occ;
  if (filled.isEmpty) {
    occ = _firstActionableOccurrence(t, now);
  } else {
    var frontier = filled.reduce(
      (a, b) => a.isBefore(b) ? a : b,
    ); // earliest filled
    var next = occurrenceAfter(t.recurrence, frontier);
    while (filled.contains(next)) {
      frontier = next;
      next = occurrenceAfter(t.recurrence, frontier);
    }
    occ = next;
  }

  var guard = 0;
  while (guard++ < _maxBackfill) {
    if (working.any((x) => x.isOpen)) break; // a current open instance exists

    if (filled.contains(occ)) {
      // Slot already materialised (e.g. pre-resolved on action); step over it.
      occ = occurrenceAfter(t.recurrence, occ);
      continue;
    }

    final next = occurrenceAfter(t.recurrence, occ);
    final window = t.windowRule.resolve(occ, next);
    // A window that was already over at the resume instant (`end <= floor`)
    // fell inside the paused stretch — skip, don't Miss.
    final gated =
        (floor != null && !window.end.isAfter(floor)) ||
        vacations.any(
          (v) =>
              !window.start.isBefore(v.start) && !window.start.isAfter(v.end),
        );
    if (gated) {
      // Generation was suspended when this slot would have been emitted —
      // skip it entirely (no instance, no Miss).
      occ = next;
      continue;
    }

    var task = t.materialize(occ, next, now: now);
    final missed = expireIfDue(task, now); // back-fill: already-passed → Missed
    if (missed != null) task = missed;

    working.add(task);
    changed.add(task);
    occ = next;
    // If `task` stayed open it's the current instance → next loop breaks;
    // if it Missed, the loop generates the following occurrence.
  }

  return ReconcileResult(changed);
}

/// The vacation that consumes [open]'s remaining window, if any: the window's
/// end falls inside the period (`v.start <= end <= v.end`), so the instance
/// could only ever Miss during the time away. Unbounded windows (`end == null`)
/// can't Miss and are never auto-Skipped.
DatePeriod? _vacationConsuming(Task open, List<DatePeriod> vacations) {
  final end = open.end;
  if (end == null) return null;
  for (final v in vacations) {
    if (!v.start.isAfter(end) && !end.isAfter(v.end)) return v;
  }
  return null;
}

/// The first occurrence whose window end is at or after [now] — i.e. the first
/// one still actionable (or in the future). Window-aware, so it respects the
/// template's [WindowRule].
DateTime _firstActionableOccurrence(Template t, DateTime now) {
  final start =
      lastOccurrenceOnOrBefore(t.recurrence, now) ??
      occurrenceOnOrAfter(t.recurrence, now);
  final it = occurrences(t.recurrence, from: start).iterator;
  it.moveNext();
  var occ = it.current;
  while (true) {
    it.moveNext();
    final next = it.current;
    final window = t.windowRule.resolve(occ, next);
    if (!window.end.isBefore(now)) return occ;
    occ = next;
  }
}
