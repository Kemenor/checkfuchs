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
/// Pure and idempotent: feeding its output back in produces no further changes.
/// The DB/repository persists [ReconcileResult.changed]; this file does no I/O.

/// Tasks created or modified by a reconcile, in apply order. New instances have
/// `id == null` (the DB assigns one); modified instances keep their id.
class ReconcileResult {
  const ReconcileResult(this.changed);
  final List<Task> changed;

  bool get isEmpty => changed.isEmpty;
}

/// Safety bound on back-fill iterations (≈ years of a daily habit unopened).
/// A net against pathological loops, not a feature limit — if you somehow blow
/// past it, the oldest gap simply isn't back-filled.
const int _maxBackfill = 1200;

ReconcileResult reconcileTemplate(
  Template t,
  List<Task> existing,
  DateTime now, {
  bool vacationActive = false,
}) {
  final changed = <Task>[];
  final working = [...existing];

  // 1. Expiry runs unconditionally — even a paused template's open instance can
  //    still Miss (§3.5: "the current open instance is left alone… or let it Miss").
  for (var i = 0; i < working.length; i++) {
    final missed = expireIfDue(working[i], now);
    if (missed != null) {
      working[i] = missed;
      changed.add(missed);
    }
  }

  // 2. Generation is gated by pause + vacation (§3.5, §6).
  if (!t.generatesAt(now) || vacationActive) return ReconcileResult(changed);

  var guard = 0;
  while (guard++ < _maxBackfill) {
    if (working.any((x) => x.isOpen)) break; // a current open instance exists

    final withOcc = working.where((x) => x.occurrence != null).toList();
    final DateTime occ;
    if (withOcc.isEmpty) {
      // Brand-new template: the first occurrence whose window hasn't already
      // fully passed at `now` (so making a "morning" habit in the afternoon
      // doesn't instantly Miss today — it starts tomorrow).
      occ = _firstActionableOccurrence(t, now);
    } else {
      final latest =
          withOcc.map((x) => x.occurrence!).reduce((a, b) => a.isAfter(b) ? a : b);
      occ = occurrenceAfter(t.recurrence, latest);
    }

    final next = occurrenceAfter(t.recurrence, occ);
    var task = t.materialize(occ, next, now: now);
    final missed = expireIfDue(task, now); // back-fill: already-passed → Missed
    if (missed != null) task = missed;

    working.add(task);
    changed.add(task);
    // If `task` stayed open it's the current instance → next loop breaks;
    // if it Missed, the loop generates the following occurrence.
  }

  return ReconcileResult(changed);
}

/// The first occurrence whose window end is at or after [now] — i.e. the first
/// one still actionable (or in the future). Window-aware, so it respects the
/// template's [WindowRule].
DateTime _firstActionableOccurrence(Template t, DateTime now) {
  final start = lastOccurrenceOnOrBefore(t.recurrence, now) ??
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
