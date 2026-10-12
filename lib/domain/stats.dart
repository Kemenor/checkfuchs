/// The Stats screen's numbers (examples/ui/09-stats.html), derived from the
/// task history. Pure: `(tasks, template names, now) → StatsSummary`, so every
/// tile is unit-tested without a database.
///
/// Conventions follow [computeStats] (concept §8): **Skip is neutral** — a
/// done-rate is `done / (done + missed)`; a skipped day neither helps nor
/// hurts. Done and missed are **check-in units** (§3.7, §8): each check-in is
/// a done placed on *its own day* (a Done from before check-ins sits on its
/// occurrence day), each check-in a closed cycle fell short is a missed. Every
/// other day-keyed number uses the instance's occurrence day (falling back to
/// resolvedAt, then createdAt).
library;

import 'analytics.dart';
import 'task.dart';

/// The four day bands, keyed by a task's window *start* hour.
enum StatsWindow { night, morning, afternoon, evening }

/// One day's state for one habit in a strip or grid.
enum DayMark { done, skipped, missed, open, none }

class HabitWeek {
  const HabitWeek({
    required this.templateId,
    required this.name,
    required this.days,
    required this.done,
    required this.resolved,
  });

  final int templateId;
  final String name;

  /// Seven entries, oldest → today.
  final List<DayMark> days;
  final int done;

  /// done + skipped + missed within the seven days.
  final int resolved;
}

class HabitStreak {
  const HabitStreak({
    required this.templateId,
    required this.name,
    required this.current,
    required this.best,
  });

  final int templateId;
  final String name;
  final int current;
  final int best;
}

class HabitHeat {
  const HabitHeat({
    required this.templateId,
    required this.name,
    required this.days,
  });

  final int templateId;
  final String name;

  /// Thirty entries, oldest → today.
  final List<DayMark> days;
}

/// The one-sentence insight; the UI localises it.
sealed class Insight {
  const Insight();
}

class WeakestWindowInsight extends Insight {
  const WeakestWindowInsight(this.window, this.rate);
  final StatsWindow window;
  final double rate;
}

class BestWeekdayInsight extends Insight {
  const BestWeekdayInsight(this.weekday);

  /// 1 = Monday … 7 = Sunday (DateTime.weekday).
  final int weekday;
}

class NoInsight extends Insight {
  const NoInsight();
}

class StatsSummary {
  const StatsSummary({
    required this.rate7,
    required this.rate30,
    required this.done7,
    required this.skipped7,
    required this.missed7,
    required this.week,
    required this.weekStart,
    required this.streaks,
    required this.byWindow,
    required this.missesByWeekday,
    required this.heat,
    required this.insight,
  });

  /// done / (done + missed) over the last 7 / 30 days; null with no data.
  final double? rate7;
  final double? rate30;
  final int done7;
  final int skipped7;
  final int missed7;

  final List<HabitWeek> week;

  /// Midnight of the first day of the week strip (today − 6).
  final DateTime weekStart;

  /// Sorted: longest current streak first.
  final List<HabitStreak> streaks;

  /// Done-rate per band over 30 days; null where nothing happened.
  final Map<StatsWindow, double?> byWindow;

  /// Seven counts, Monday first, over 30 days.
  final List<int> missesByWeekday;
  final List<HabitHeat> heat;
  final Insight insight;

  bool get hasHabits => week.isNotEmpty;
}

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _dayOf(Task t) =>
    _midnight(t.occurrence ?? t.resolvedAt ?? t.createdAt);
int _dayIndex(DateTime day, DateTime from) => DateTime.utc(
  day.year,
  day.month,
  day.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// The days [t]'s done units land on: one per check-in, or — a Done from
/// before check-ins existed — its own day.
Iterable<DateTime> _doneDays(Task t) => t.checkIns.isNotEmpty
    ? t.checkIns.map(_midnight)
    : t.status == TaskStatus.done
    ? [_dayOf(t)]
    : const [];

DayMark _mark(Task t) => switch (t.status) {
  TaskStatus.done => DayMark.done,
  TaskStatus.skipped => DayMark.skipped,
  TaskStatus.missed => DayMark.missed,
  TaskStatus.open => DayMark.open,
};

/// Terminal states outrank an open instance on the same day; done outranks
/// the rest (a re-materialised slot should never hide a completion).
int _rank(DayMark m) => switch (m) {
  DayMark.done => 4,
  DayMark.missed => 3,
  DayMark.skipped => 2,
  DayMark.open => 1,
  DayMark.none => 0,
};

double? _rate(int done, int missed) =>
    done + missed == 0 ? null : done / (done + missed);

StatsWindow? windowOf(Task t) {
  final start = t.start;
  if (start == null) return null;
  // An all-day (or longer) window says nothing about *when* — only bands
  // shorter than a day are bucketed. A multi-band task counts under its
  // first band.
  final end = t.end;
  if (end == null ||
      !end.difference(start).isNegative &&
          end.difference(start) >= const Duration(hours: 24)) {
    return null;
  }
  return switch (start.hour) {
    < 6 => StatsWindow.night,
    < 12 => StatsWindow.morning,
    < 18 => StatsWindow.afternoon,
    _ => StatsWindow.evening,
  };
}

StatsSummary computeStatsSummary(
  Iterable<Task> tasks,
  Map<int, String> templateNames,
  DateTime now,
) {
  final today = _midnight(now);
  final from7 = today.subtract(const Duration(days: 6));
  final from30 = today.subtract(const Duration(days: 29));

  final habits = [
    for (final t in tasks)
      if (t.templateId != null && _dayOf(t).compareTo(today) <= 0) t,
  ];
  // Only templates the caller still knows about (deleted series vanish).
  final byTemplate = <int, List<Task>>{};
  for (final t in habits) {
    if (!templateNames.containsKey(t.templateId)) continue;
    byTemplate.putIfAbsent(t.templateId!, () => []).add(t);
  }
  final ids = byTemplate.keys.toList()
    ..sort((a, b) => templateNames[a]!.compareTo(templateNames[b]!));

  // --- completion 7 / 30 ---------------------------------------------------
  // Done units on their check-in days (a running cycle's count already);
  // skipped cycles and missed units on the instance's day.
  var done7 = 0, skipped7 = 0, missed7 = 0, done30 = 0, missed30 = 0;
  for (final t in habits) {
    for (final day in _doneDays(t)) {
      if (day.isAfter(today)) continue;
      if (!day.isBefore(from30)) done30++;
      if (!day.isBefore(from7)) done7++;
    }
    final day = _dayOf(t);
    if (!day.isBefore(from30)) missed30 += t.missedUnits;
    if (!day.isBefore(from7)) {
      missed7 += t.missedUnits;
      if (t.status == TaskStatus.skipped) skipped7++;
    }
  }

  // --- per-habit strips, grids, streaks ------------------------------------
  final week = <HabitWeek>[];
  final heat = <HabitHeat>[];
  final streaks = <HabitStreak>[];
  for (final id in ids) {
    final name = templateNames[id]!;
    final instances = byTemplate[id]!;
    final days7 = List.filled(7, DayMark.none);
    final days30 = List.filled(30, DayMark.none);
    void put(DateTime day, DayMark m) {
      final i7 = _dayIndex(day, from7);
      if (i7 >= 0 && i7 < 7 && _rank(m) > _rank(days7[i7])) days7[i7] = m;
      final i30 = _dayIndex(day, from30);
      if (i30 >= 0 && i30 < 30 && _rank(m) > _rank(days30[i30])) {
        days30[i30] = m;
      }
    }

    for (final t in instances) {
      // Each check-in marks its own day done (the gym days show where they
      // happened); the instance's own state sits on its day as before.
      for (final day in _doneDays(t)) {
        put(day, DayMark.done);
      }
      if (t.status != TaskStatus.done) put(_dayOf(t), _mark(t));
    }
    final wDone = days7.where((m) => m == DayMark.done).length;
    final wResolved = days7
        .where(
          (m) =>
              m == DayMark.done || m == DayMark.skipped || m == DayMark.missed,
        )
        .length;
    week.add(
      HabitWeek(
        templateId: id,
        name: name,
        days: days7,
        done: wDone,
        resolved: wResolved,
      ),
    );
    heat.add(HabitHeat(templateId: id, name: name, days: days30));

    final stats = computeStats(instances);
    // Best run ever: consecutive met cycles (Done, or a running counter
    // already met), skips neutral, misses break.
    final chronological = [
      for (final t in instances)
        if (t.isTerminal || t.isMet) t,
    ]..sort((a, b) => _dayOf(a).compareTo(_dayOf(b)));
    var run = 0, best = 0;
    for (final t in chronological) {
      switch (t.status) {
        case TaskStatus.done:
        case TaskStatus.open: // only met ones are here
          run++;
          if (run > best) best = run;
        case TaskStatus.missed:
          run = 0;
        case TaskStatus.skipped:
          break;
      }
    }
    streaks.add(
      HabitStreak(
        templateId: id,
        name: name,
        current: stats.currentStreak,
        best: best < stats.currentStreak ? stats.currentStreak : best,
      ),
    );
  }
  streaks.sort((a, b) => b.current.compareTo(a.current));

  // --- by window, misses by weekday (30 days) -------------------------------
  final wDone = <StatsWindow, int>{};
  final wMissed = <StatsWindow, int>{};
  final missesByWeekday = List.filled(7, 0);
  for (final t in habits) {
    if (_dayOf(t).isBefore(from30)) continue;
    final w = windowOf(t);
    if (w != null) {
      wDone[w] = (wDone[w] ?? 0) + t.doneUnits;
      wMissed[w] = (wMissed[w] ?? 0) + t.missedUnits;
    }
    missesByWeekday[_dayOf(t).weekday - 1] += t.missedUnits;
  }
  final byWindow = {
    for (final w in StatsWindow.values)
      w: _rate(wDone[w] ?? 0, wMissed[w] ?? 0),
  };

  // --- insight -------------------------------------------------------------
  Insight insight = const NoInsight();
  StatsWindow? weakest;
  var weakestRate = 1.0;
  var windowsWithData = 0;
  for (final w in StatsWindow.values) {
    final n = (wDone[w] ?? 0) + (wMissed[w] ?? 0);
    if (n < 3) continue;
    windowsWithData++;
    final r = byWindow[w]!;
    if (r < weakestRate) {
      weakestRate = r;
      weakest = w;
    }
  }
  if (weakest != null && windowsWithData >= 2 && weakestRate < 0.75) {
    insight = WeakestWindowInsight(weakest, weakestRate);
  } else {
    final doneByWeekday = List.filled(7, 0);
    for (final t in habits) {
      for (final day in _doneDays(t)) {
        if (!day.isBefore(from30) && !day.isAfter(today)) {
          doneByWeekday[day.weekday - 1]++;
        }
      }
    }
    var bestDay = -1, bestCount = 0;
    for (var i = 0; i < 7; i++) {
      if (doneByWeekday[i] > bestCount) {
        bestCount = doneByWeekday[i];
        bestDay = i;
      }
    }
    if (bestCount >= 3) insight = BestWeekdayInsight(bestDay + 1);
  }

  return StatsSummary(
    rate7: _rate(done7, missed7),
    rate30: _rate(done30, missed30),
    done7: done7,
    skipped7: skipped7,
    missed7: missed7,
    week: week,
    weekStart: from7,
    streaks: streaks,
    byWindow: byWindow,
    missesByWeekday: missesByWeekday,
    heat: heat,
    insight: insight,
  );
}
