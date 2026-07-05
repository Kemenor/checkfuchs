import 'dart:math';

import 'lens.dart';
import 'recurrence.dart';
import 'task.dart';

/// The pure lens projection (design-concept §4) — `(lens, members, now) →` the
/// Tasks to show, applying dormancy → Pass → ordering/selection → showCount,
/// plus the periodic hold-till-rollover. No I/O; the reactive layer feeds it
/// DB streams + the clock.

/// Count of [period] rollovers strictly after [from], up to and including [now].
/// Dormancy is **derived** from this — no ticking counter (§4.2).
int periodsElapsed(Recurrence period, DateTime from, DateTime now) {
  var count = 0;
  for (final occ in occurrences(period, from: from)) {
    if (!occ.isAfter(from)) continue; // skip the boundary at/before `from`
    if (occ.isAfter(now)) break;
    count++;
  }
  return count;
}

/// The instant the current period began — the latest rollover at/before [now]
/// (or the anchor date if the period hasn't rolled over yet).
DateTime periodStart(Recurrence period, DateTime now) =>
    lastOccurrenceOnOrBefore(period, now) ??
    DateTime(period.anchor.year, period.anchor.month, period.anchor.day);

/// A member is Dormant when it has sat **surfaced but open** for `dormantAfter`
/// periods (periodic lenses only). It then rests exactly one period and
/// resurfaces (§4.4 "sinks out of view … resurfaces later") — when it is next
/// shown, the reactive layer re-stamps `surfacedAt`, starting a fresh cycle.
/// Members that were never surfaced (`surfacedAt == null`) never go dormant.
bool isDormant(LensMember m, Lens lens, DateTime now) {
  if (!lens.isPeriodic || lens.dormantAfter == null || m.surfacedAt == null) {
    return false;
  }
  if (!m.task.isOpen) return false;
  return periodsElapsed(lens.period!, m.surfacedAt!, now) == lens.dormantAfter!;
}

/// The Tasks a Lens shows right now.
///
/// Periodic lenses **hold till rollover** (§4.3): a member resolved this period
/// stays shown ("nicely done") and keeps occupying its slot — completing the
/// top item does not surface the next one until the period rolls over. A
/// member Passed this period (§4.4) is set aside so the slot shows another.
///
/// [randomSeed] pins `LensSelection.random`; when null the seed derives from
/// the current period (periodic) or the civil day (continuous), so the pick
/// rotates on rollover instead of being frozen forever.
List<Task> projectLens(
  Lens lens,
  List<LensMember> members,
  DateTime now, {
  int? randomSeed,
}) {
  final ps = lens.isPeriodic ? periodStart(lens.period!, now) : null;

  bool heldThisPeriod(LensMember m) =>
      ps != null &&
      m.task.isTerminal &&
      m.task.resolvedAt != null &&
      !m.task.resolvedAt!.isBefore(ps);
  bool passedThisPeriod(LensMember m) =>
      ps != null && m.passedAt != null && !m.passedAt!.isBefore(ps);

  final held = [
    for (final m in members)
      if (heldThisPeriod(m)) m,
  ]..sort(_comparatorFor(lens.ordering));

  var candidates = members
      .where(
        (m) =>
            m.task.isOpen && !isDormant(m, lens, now) && !passedThisPeriod(m),
      )
      .toList();

  if (lens.selection == LensSelection.random) {
    final seed = randomSeed ?? _epochDay(ps ?? now);
    candidates.shuffle(Random(seed)); // deterministic given a seed
  } else {
    candidates.sort(_comparatorFor(lens.ordering));
  }

  final open = lens.showsAll
      ? candidates
      : candidates.take(max(0, lens.showCount - held.length));
  return [for (final m in held) m.task, for (final m in open) m.task];
}

/// Seed material: the civil day as an integer (stable across a whole day/period).
int _epochDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

Comparator<LensMember> _comparatorFor(LensOrdering ordering) =>
    switch (ordering) {
      LensOrdering.manual => (a, b) => a.order.compareTo(b.order),
      LensOrdering.automatic => (a, b) => _fifoKey(
        a.task,
      ).compareTo(_fifoKey(b.task)),
      LensOrdering.dueDate => (a, b) => _dueKey(
        a.task,
      ).compareTo(_dueKey(b.task)),
    };

/// FIFO: the occurrence date if generated, else when it was created.
DateTime _fifoKey(Task t) => t.occurrence ?? t.createdAt;

/// Earliest deadline first; unbounded tasks (no `end`) sort last.
DateTime _dueKey(Task t) => t.end ?? DateTime(9999);
