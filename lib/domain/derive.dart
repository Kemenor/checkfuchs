import 'dart:math';

import 'lens.dart';
import 'recurrence.dart';
import 'task.dart';

/// The pure lens projection (design-concept §4) — `(lens, members, now) →` the
/// Tasks to show, applying dormancy → ordering/selection → showCount. No I/O;
/// the reactive layer feeds it DB streams + the clock.

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

/// A member is Dormant when it has sat **shown but open** for `dormantAfter`
/// periods (periodic lenses only).
bool isDormant(LensMember m, Lens lens, DateTime now) {
  if (!lens.isPeriodic || lens.dormantAfter == null || m.surfacedAt == null) {
    return false;
  }
  if (!m.task.isOpen) return false;
  return periodsElapsed(lens.period!, m.surfacedAt!, now) >= lens.dormantAfter!;
}

/// The Tasks a Lens shows right now.
List<Task> projectLens(
  Lens lens,
  List<LensMember> members,
  DateTime now, {
  int randomSeed = 0,
}) {
  var candidates = members
      .where((m) => m.task.isOpen && !isDormant(m, lens, now))
      .toList();

  if (lens.selection == LensSelection.random) {
    candidates.shuffle(Random(randomSeed)); // deterministic given a seed
  } else {
    candidates.sort(_comparatorFor(lens.ordering));
  }

  final shown =
      lens.showsAll ? candidates : candidates.take(max(0, lens.showCount));
  return [for (final m in shown) m.task];
}

Comparator<LensMember> _comparatorFor(LensOrdering ordering) => switch (ordering) {
      LensOrdering.manual => (a, b) => a.order.compareTo(b.order),
      LensOrdering.automatic => (a, b) => _fifoKey(a.task).compareTo(_fifoKey(b.task)),
      LensOrdering.dueDate => (a, b) => _dueKey(a.task).compareTo(_dueKey(b.task)),
    };

/// FIFO: the occurrence date if generated, else when it was created.
DateTime _fifoKey(Task t) => t.occurrence ?? t.createdAt;

/// Earliest deadline first; unbounded tasks (no `end`) sort last.
DateTime _dueKey(Task t) => t.end ?? DateTime(9999);
