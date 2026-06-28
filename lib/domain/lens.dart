/// A Lens — pure presentation (design-concept §4): it selects and orders a slice
/// of Tasks. It never touches status.
library;

import 'recurrence.dart';
import 'task.dart';

/// How members are ranked.
enum LensOrdering { dueDate, manual, automatic }

/// How the shown set is drawn from the ordering.
enum LensSelection {
  /// the first `showCount` by [LensOrdering].
  top,

  /// `showCount` at random (ignores order).
  random,
}

class Lens {
  const Lens({
    this.id,
    required this.name,
    this.showCount = showAll,
    this.ordering = LensOrdering.manual,
    this.selection = LensSelection.top,
    this.period,
    this.dormantAfter,
    this.sortIndex = 0,
  });

  /// Sentinel for `showCount` — render every member.
  static const int showAll = -1;

  final int? id;
  final String name;

  /// How many slots to surface ([showAll] = all).
  final int showCount;
  final LensOrdering ordering;
  final LensSelection selection;

  /// The refill cadence: null ⇒ **continuous** (refill on complete); otherwise
  /// **periodic** (hold till rollover, Dormancy applies). Reuses the recurrence
  /// primitive (§4.3).
  final Recurrence? period;

  /// Periods a shown member may sit unworked before going Dormant (periodic only).
  final int? dormantAfter;

  final int sortIndex;

  bool get isPeriodic => period != null;
  bool get showsAll => showCount < 0;
}

/// A Task's membership in a Lens + the per-pair display state (§4.2): stable
/// `order`, the `surfacedAt` timestamp dormancy is derived from, and the
/// per-cycle `passedThisPeriod` flag.
class LensMember {
  const LensMember({
    required this.task,
    this.order = 0,
    this.surfacedAt,
    this.passedThisPeriod = false,
  });

  final Task task;
  final int order;
  final DateTime? surfacedAt;
  final bool passedThisPeriod;
}
