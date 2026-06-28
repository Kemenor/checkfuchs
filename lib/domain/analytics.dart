/// Analytics over a Task series' resolved instances (design-concept §8).
/// **Skip is neutral**, **Missed breaks the run**, completion-rate excludes
/// Skips. Pure, so it's unit-tested directly.
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

  final int done;
  final int missed;
  final int skipped;

  /// done / (done + missed) — Skips excluded; 1.0 when there's nothing to rate.
  final double completionRate;

  /// Consecutive `Done` from the most recent occurrence; `Skip` preserves it,
  /// `Missed` breaks it.
  final int currentStreak;

  /// Leading run of `Missed` from the most recent — the avoidance signal (§8).
  final int consecutiveMisses;

  bool get hasData => done + missed + skipped > 0;
}

DateTime _key(Task t) => t.occurrence ?? t.resolvedAt ?? t.createdAt;

HabitStats computeStats(Iterable<Task> instances, {DateTime? since}) {
  final resolved = [
    for (final t in instances)
      if (t.isTerminal && (since == null || !_key(t).isBefore(since))) t,
  ]..sort((a, b) => _key(b).compareTo(_key(a))); // most recent first

  final done = resolved.where((t) => t.status == TaskStatus.done).length;
  final missed = resolved.where((t) => t.status == TaskStatus.missed).length;
  final skipped = resolved.where((t) => t.status == TaskStatus.skipped).length;

  var streak = 0;
  for (final t in resolved) {
    if (t.status == TaskStatus.done) {
      streak++;
    } else if (t.status == TaskStatus.skipped) {
      continue; // neutral — a rest day doesn't break the run
    } else {
      break; // missed
    }
  }

  var misses = 0;
  for (final t in resolved) {
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
