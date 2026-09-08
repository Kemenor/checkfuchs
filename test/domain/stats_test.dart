import 'package:checkfuchs/domain/stats.dart';
import 'package:checkfuchs/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day, [int h = 0]) => DateTime(y, m, day, h);

Task inst(int template, DateTime occ, TaskStatus status, {int startHour = 8}) =>
    Task(
      id: occ.millisecondsSinceEpoch ~/ 1000 + template,
      templateId: template,
      name: 't$template',
      status: status,
      start: DateTime(occ.year, occ.month, occ.day, startHour),
      end: DateTime(occ.year, occ.month, occ.day, startHour + 4),
      occurrence: occ,
      createdAt: occ,
      resolvedAt: status == TaskStatus.open
          ? null
          : occ.add(const Duration(hours: 9)),
    );

void main() {
  final now = d(2026, 9, 8, 15); // Tuesday
  const names = {1: 'Brush teeth', 2: 'Journal'};

  group('completion rates', () {
    test('done / (done + missed), skips neutral, per 7 and 30 days', () {
      final tasks = [
        // last 7 days: 4 done, 1 missed, 1 skipped
        inst(1, d(2026, 9, 2), TaskStatus.done),
        inst(1, d(2026, 9, 3), TaskStatus.done),
        inst(1, d(2026, 9, 4), TaskStatus.missed),
        inst(1, d(2026, 9, 5), TaskStatus.skipped),
        inst(1, d(2026, 9, 6), TaskStatus.done),
        inst(1, d(2026, 9, 7), TaskStatus.done),
        inst(1, d(2026, 9, 8), TaskStatus.open),
        // older, inside 30 days: 1 missed
        inst(1, d(2026, 8, 20), TaskStatus.missed),
        // outside 30 days: ignored
        inst(1, d(2026, 8, 1), TaskStatus.missed),
      ];
      final s = computeStatsSummary(tasks, names, now);
      expect(s.rate7, closeTo(4 / 5, 1e-9));
      expect(s.rate30, closeTo(4 / 6, 1e-9));
      expect((s.done7, s.skipped7, s.missed7), (4, 1, 1));
    });

    test('no data → null rates, empty week', () {
      final s = computeStatsSummary(const [], names, now);
      expect(s.rate7, isNull);
      expect(s.rate30, isNull);
      expect(s.hasHabits, isFalse);
      expect(s.insight, isA<NoInsight>());
    });
  });

  group('week strip', () {
    test('seven marks oldest → today, done/resolved counts', () {
      final tasks = [
        inst(2, d(2026, 9, 2), TaskStatus.done),
        inst(2, d(2026, 9, 3), TaskStatus.missed),
        inst(2, d(2026, 9, 5), TaskStatus.skipped),
        inst(2, d(2026, 9, 8), TaskStatus.open),
      ];
      final s = computeStatsSummary(tasks, names, now);
      expect(s.weekStart, d(2026, 9, 2));
      final w = s.week.single;
      expect(w.name, 'Journal');
      expect(w.days, [
        DayMark.done,
        DayMark.missed,
        DayMark.none,
        DayMark.skipped,
        DayMark.none,
        DayMark.none,
        DayMark.open,
      ]);
      expect((w.done, w.resolved), (1, 3));
    });

    test('a done outranks an open re-materialised slot on the same day', () {
      final tasks = [
        inst(1, d(2026, 9, 8), TaskStatus.done),
        inst(1, d(2026, 9, 8), TaskStatus.open),
      ];
      final s = computeStatsSummary(tasks, names, now);
      expect(s.week.single.days.last, DayMark.done);
    });

    test('templates missing from the name map are dropped', () {
      final s = computeStatsSummary(
        [inst(9, d(2026, 9, 8), TaskStatus.done)],
        names,
        now,
      );
      expect(s.hasHabits, isFalse);
    });
  });

  group('streaks', () {
    test('current from analytics, best is the longest run ever', () {
      final tasks = [
        inst(1, d(2026, 8, 20), TaskStatus.done),
        inst(1, d(2026, 8, 21), TaskStatus.done),
        inst(1, d(2026, 8, 22), TaskStatus.done),
        inst(1, d(2026, 8, 23), TaskStatus.missed),
        inst(1, d(2026, 9, 6), TaskStatus.done),
        inst(1, d(2026, 9, 7), TaskStatus.skipped),
        inst(1, d(2026, 9, 8), TaskStatus.done),
      ];
      final st = computeStatsSummary(tasks, names, now).streaks.single;
      expect(st.current, 2);
      expect(st.best, 3);
    });

    test('sorted by current streak, longest first', () {
      final tasks = [
        inst(1, d(2026, 9, 8), TaskStatus.done),
        inst(2, d(2026, 9, 7), TaskStatus.done),
        inst(2, d(2026, 9, 8), TaskStatus.done),
      ];
      final s = computeStatsSummary(tasks, names, now);
      expect(s.streaks.map((e) => e.name), ['Journal', 'Brush teeth']);
    });
  });

  group('by window and weekday', () {
    test('buckets by start hour; misses counted per weekday', () {
      final tasks = [
        inst(1, d(2026, 9, 1), TaskStatus.done, startHour: 7), // morning
        inst(1, d(2026, 9, 2), TaskStatus.missed, startHour: 7),
        inst(1, d(2026, 9, 3), TaskStatus.done, startHour: 19), // evening
        inst(1, d(2026, 9, 4), TaskStatus.done, startHour: 19),
        inst(1, d(2026, 9, 5), TaskStatus.missed, startHour: 2), // night
        inst(1, d(2026, 9, 6), TaskStatus.skipped, startHour: 13), // afternoon
      ];
      final s = computeStatsSummary(tasks, names, now);
      expect(s.byWindow[StatsWindow.morning], closeTo(.5, 1e-9));
      expect(s.byWindow[StatsWindow.evening], closeTo(1, 1e-9));
      expect(s.byWindow[StatsWindow.night], closeTo(0, 1e-9));
      expect(s.byWindow[StatsWindow.afternoon], isNull); // only a skip
      // 2 Sep 2026 = Wednesday (index 2), 5 Sep = Saturday (index 5).
      expect(s.missesByWeekday, [0, 0, 1, 0, 0, 1, 0]);
    });

    test('windowOf: all-day and open-ended windows are not bucketed', () {
      final day = DateTime(2026, 9, 1);
      expect(
        windowOf(
          Task(
            name: 'x',
            createdAt: now,
            start: day,
            end: DateTime(2026, 9, 2),
          ),
        ),
        isNull,
      );
      expect(windowOf(Task(name: 'x', createdAt: now, start: day)), isNull);
      expect(
        windowOf(
          Task(
            name: 'x',
            createdAt: now,
            start: DateTime(2026, 9, 1, 18),
            end: DateTime(2026, 9, 2),
          ),
        ),
        StatsWindow.evening,
      );
    });

    test('windowOf: no start → no window', () {
      expect(windowOf(Task(name: 'x', createdAt: now)), isNull);
    });
  });

  group('heatmap', () {
    test('thirty entries, today last', () {
      final s = computeStatsSummary(
        [
          inst(1, d(2026, 8, 10), TaskStatus.done),
          inst(1, d(2026, 9, 8), TaskStatus.missed),
        ],
        names,
        now,
      );
      final h = s.heat.single;
      expect(h.days, hasLength(30));
      expect(h.days.first, DayMark.done); // 10 Aug = today − 29
      expect(h.days.last, DayMark.missed);
    });
  });

  group('insight', () {
    test('weakest window when two windows have data and one is < 75%', () {
      final tasks = [
        for (var i = 1; i <= 4; i++)
          inst(1, d(2026, 9, i), TaskStatus.done, startHour: 7),
        inst(1, d(2026, 9, 5), TaskStatus.done, startHour: 19),
        inst(1, d(2026, 9, 6), TaskStatus.missed, startHour: 19),
        inst(1, d(2026, 9, 7), TaskStatus.missed, startHour: 19),
      ];
      final ins = computeStatsSummary(tasks, names, now).insight;
      expect(ins, isA<WeakestWindowInsight>());
      expect((ins as WeakestWindowInsight).window, StatsWindow.evening);
      expect(ins.rate, closeTo(1 / 3, 1e-9));
    });

    test('best weekday when windows are fine', () {
      final tasks = [
        // three Mondays done (24, 31 Aug, 7 Sep 2026)
        inst(1, d(2026, 8, 24), TaskStatus.done),
        inst(1, d(2026, 8, 31), TaskStatus.done),
        inst(1, d(2026, 9, 7), TaskStatus.done),
        inst(1, d(2026, 9, 8), TaskStatus.done),
      ];
      final ins = computeStatsSummary(tasks, names, now).insight;
      expect(ins, isA<BestWeekdayInsight>());
      expect((ins as BestWeekdayInsight).weekday, DateTime.monday);
    });
  });
}
