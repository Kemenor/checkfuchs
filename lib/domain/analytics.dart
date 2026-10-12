/// Analytics over a Task series' instances (design-concept §8).
/// **Skip is neutral**, **Missed breaks the run**, completion-rate excludes
/// Skips. Counters (§3.7) count in **check-ins**: every check-in is one done
/// (right away, while its cycle still runs), every check-in short of `min`
/// when a cycle closes one missed; streaks count **met cycles**. Pure, so
/// it's unit-tested directly.
library;

import 'task.dart';

class HabitStats {
  const HabitStats({
    required this.done,
    required this.missed,
    required this.skipped,
    required this.completionRate,
    required this.currentStreak,
    required this.consecutiveMisses,
  });

  /// Done check-ins ([Task.doneUnits]).
  final int done;

  /// Missing check-ins of closed cycles ([Task.missedUnits]).
  final int missed;

  /// Skipped cycles.
  final int skipped;

  /// done / (done + missed) — Skips excluded; 1.0 when there's nothing to rate.
  final double completionRate;

  /// Consecutive met cycles from the most recent occurrence — Done, or a
  /// running counter already met (it can't fail any more); `Skip` preserves
  /// the run, `Missed` breaks it.
  final int currentStreak;

  /// Leading run of `Missed` from the most recent — the avoidance signal (§8).
  final int consecutiveMisses;

  bool get hasData => done + missed + skipped > 0;

  /// Avoidance surfacing (§8): past this many consecutive misses the item is
  /// *rendered* differently (soft amber) — information, never a forced action.
  static const int avoidanceThreshold = 3;

  bool get isAvoided => consecutiveMisses >= avoidanceThreshold;
}

DateTime _key(Task t) => t.occurrence ?? t.resolvedAt ?? t.createdAt;

/// A cycle that counts toward a run: Done, or an open counter already met.
bool _met(Task t) => t.status == TaskStatus.done || (t.isOpen && t.isMet);

HabitStats computeStats(Iterable<Task> instances, {DateTime? since}) {
  final inRange = [
    for (final t in instances)
      if (since == null || !_key(t).isBefore(since)) t,
  ];
  // The run is read over decided cycles plus a running met counter.
  final resolved = [
    for (final t in inRange)
      if (t.isTerminal || _met(t)) t,
  ]..sort((a, b) => _key(b).compareTo(_key(a))); // most recent first

  // Check-ins count as done units at once — even in a running cycle.
  final done = inRange.fold(0, (n, t) => n + t.doneUnits);
  final missed = inRange.fold(0, (n, t) => n + t.missedUnits);
  final skipped = inRange.where((t) => t.status == TaskStatus.skipped).length;

  var streak = 0;
  for (final t in resolved) {
    if (_met(t)) {
      streak++;
    } else if (t.status == TaskStatus.skipped) {
      continue; // neutral — a rest day doesn't break the run
    } else {
      break; // missed
    }
  }

  var misses = 0;
  for (final t in resolved.where((t) => t.isTerminal)) {
    if (t.status == TaskStatus.missed) {
      misses++;
    } else {
      break;
    }
  }

  final denom = done + missed;
  return HabitStats(
    done: done,
    missed: missed,
    skipped: skipped,
    completionRate: denom == 0 ? 1.0 : done / denom,
    currentStreak: streak,
    consecutiveMisses: misses,
  );
}
