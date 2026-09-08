import 'package:checkfuchs/domain/derive.dart';
import 'package:checkfuchs/domain/lens.dart';
import 'package:checkfuchs/domain/recurrence.dart';
import 'package:checkfuchs/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day, [int h = 0]) => DateTime(y, m, day, h);

Task task(
  int id, {
  DateTime? end,
  DateTime? occ,
  TaskStatus status = TaskStatus.open,
  DateTime? resolvedAt,
}) => Task(
  id: id,
  name: 't$id',
  status: status,
  end: end,
  occurrence: occ,
  createdAt: d(2026, 6, 1),
  resolvedAt: resolvedAt,
);

LensMember mem(
  Task t, {
  int order = 0,
  DateTime? surfacedAt,
  DateTime? passedAt,
}) => LensMember(
  task: t,
  order: order,
  surfacedAt: surfacedAt,
  passedAt: passedAt,
);

List<int> ids(List<Task> ts) => [for (final t in ts) t.id!];

void main() {
  final now = d(2026, 6, 27);

  test('manual ordering + showCount picks the lowest-order open member', () {
    const lens = Lens(name: 'w', ordering: LensOrdering.manual, showCount: 1);
    final members = [
      mem(task(1), order: 2),
      mem(task(2), order: 0),
      mem(task(3), order: 1),
    ];
    expect(ids(projectLens(lens, members, now)), [2]);
  });

  test('showAll returns every open member, ordered', () {
    const lens = Lens(name: 'w', ordering: LensOrdering.manual);
    final members = [
      mem(task(1), order: 2),
      mem(task(2), order: 0),
      mem(task(3), order: 1),
    ];
    expect(ids(projectLens(lens, members, now)), [2, 3, 1]);
  });

  test('only the nearest pending instance of a series is shown', () {
    // Today's active instance + two pre-skipped-then-reopened future ones.
    Task inst(int id, int day) => Task(
      id: id,
      templateId: 9,
      name: 'Brush teeth',
      start: d(2026, 6, day),
      end: d(2026, 6, day + 1),
      occurrence: d(2026, 6, day),
      createdAt: d(2026, 6, 1),
    );
    final lens = Lens(
      id: 1,
      name: 'daily',
      showCount: Lens.showAll,
      ordering: LensOrdering.automatic,
      selection: LensSelection.top,
    );
    final shown = projectLens(lens, [
      mem(inst(1, 27)), // active (now = 27 June)
      mem(inst(3, 29)), // pending, later
      mem(inst(2, 28)), // pending, nearest
      mem(task(4)), // an unrelated one-off stays
    ], d(2026, 6, 27, 8));
    expect(ids(shown), unorderedEquals([1, 2, 4]));
  });

  test('terminal tasks are excluded', () {
    const lens = Lens(name: 'w');
    final members = [
      mem(task(1)),
      mem(task(2, status: TaskStatus.done)),
      mem(task(3, status: TaskStatus.missed)),
    ];
    expect(ids(projectLens(lens, members, now)), [1]);
  });

  test('dueDate ordering: earliest end first, unbounded last', () {
    const lens = Lens(name: 'w', ordering: LensOrdering.dueDate);
    final members = [
      mem(task(1, end: d(2026, 6, 29))),
      mem(task(2, end: d(2026, 6, 27))),
      mem(task(3)), // unbounded → last
    ];
    expect(ids(projectLens(lens, members, now)), [2, 1, 3]);
  });

  test('automatic ordering is FIFO by occurrence', () {
    const lens = Lens(name: 'w', ordering: LensOrdering.automatic);
    final members = [
      mem(task(1, occ: d(2026, 6, 26))),
      mem(task(2, occ: d(2026, 6, 24))),
      mem(task(3, occ: d(2026, 6, 25))),
    ];
    expect(ids(projectLens(lens, members, now)), [2, 3, 1]);
  });

  test('random selection returns showCount items, deterministic per seed', () {
    const lens = Lens(name: 'w', selection: LensSelection.random, showCount: 2);
    final members = [for (var i = 1; i <= 5; i++) mem(task(i))];
    final a = ids(projectLens(lens, members, now, randomSeed: 7));
    final b = ids(projectLens(lens, members, now, randomSeed: 7));
    expect(a, hasLength(2));
    expect(a, b); // same seed → same pick
  });

  group('periodic hold-till-rollover (§4.3)', () {
    // Weekly period anchored Monday 06-01 → the period at `now` (06-27) runs
    // 06-22 .. 06-29.
    final weekly = Lens(
      name: 'week',
      period: Recurrence.weekly(d(2026, 6, 1)),
      showCount: 1,
      ordering: LensOrdering.manual,
    );

    final members = [
      mem(
        task(1, status: TaskStatus.done, resolvedAt: d(2026, 6, 24)),
        order: 0,
      ),
      mem(task(2), order: 1),
    ];

    test('a member resolved this period stays shown and blocks refill', () {
      // "nicely done": the completed top member keeps its slot — the next
      // candidate does NOT surface before the rollover.
      expect(ids(projectLens(weekly, members, now)), [1]);
    });

    test('after the rollover the next candidate surfaces', () {
      expect(ids(projectLens(weekly, members, d(2026, 6, 29))), [2]);
    });

    test('a resolution from a previous period does not hold', () {
      final stale = [
        mem(
          task(1, status: TaskStatus.done, resolvedAt: d(2026, 6, 20)),
          order: 0,
        ),
        mem(task(2), order: 1),
      ];
      expect(ids(projectLens(weekly, stale, now)), [2]);
    });
  });

  group('Pass (§4.4)', () {
    final weekly = Lens(
      name: 'week',
      period: Recurrence.weekly(d(2026, 6, 1)),
      showCount: 1,
      ordering: LensOrdering.manual,
    );

    final members = [
      mem(task(1), order: 0, passedAt: d(2026, 6, 26)),
      mem(task(2), order: 1),
    ];

    test(
      'a member passed this period is set aside; the slot shows another',
      () {
        expect(ids(projectLens(weekly, members, now)), [2]);
      },
    );

    test('after the rollover the passed member is back', () {
      expect(ids(projectLens(weekly, members, d(2026, 6, 30))), [1]);
    });
  });

  group('random selection rotates between periods', () {
    // Enough members that a frozen seed would show as a single distinct pick;
    // two different seeds *may* coincide on one day, but not across all of them.
    final members = [for (var i = 1; i <= 12; i++) mem(task(i))];

    test('continuous lens: seed derives from the civil day', () {
      const lens = Lens(
        name: 'w',
        selection: LensSelection.random,
        showCount: 1,
      );
      expect(
        ids(projectLens(lens, members, d(2026, 6, 27))),
        ids(projectLens(lens, members, DateTime(2026, 6, 27, 21))),
        reason: 'same day → same seed → same pick',
      );
      final picks = {
        for (var day = 1; day <= 14; day++)
          ...ids(projectLens(lens, members, d(2026, 6, day))),
      };
      expect(
        picks.length,
        greaterThan(1),
        reason: 'the pick must rotate across days, not freeze forever',
      );
    });

    test('periodic lens: stable within a period, reshuffles on rollover', () {
      final lens = Lens(
        name: 'w',
        selection: LensSelection.random,
        showCount: 1,
        period: Recurrence.weekly(d(2026, 6, 1)),
      );
      expect(
        ids(projectLens(lens, members, d(2026, 6, 23))),
        ids(projectLens(lens, members, d(2026, 6, 27))),
        reason: 'same period → same seed → same pick',
      );
      final picks = {
        for (var week = 0; week < 10; week++)
          ...ids(projectLens(lens, members, d(2026, 6, 1 + week * 7))),
      };
      expect(picks.length, greaterThan(1));
    });
  });

  group('dormancy (periodic)', () {
    final weekly = Lens(
      name: 'week',
      period: Recurrence.weekly(d(2026, 6, 1)),
      dormantAfter: 3,
    );

    test('periodsElapsed counts rollovers in (from, now]', () {
      expect(
        periodsElapsed(weekly.period!, d(2026, 6, 1), d(2026, 6, 22)),
        3, // 06-08, 06-15, 06-22
      );
    });

    test('periodsElapsed is 0 when now is before from', () {
      expect(periodsElapsed(weekly.period!, d(2026, 6, 15), d(2026, 6, 10)), 0);
    });

    test('periodsElapsed counts a rollover exactly at now', () {
      // now == the 06-08 rollover instant → it counts (inclusive upper bound).
      expect(periodsElapsed(weekly.period!, d(2026, 6, 1), d(2026, 6, 8)), 1);
    });

    test('a member sat 3 periods unworked is Dormant → hidden', () {
      final m = mem(task(1), surfacedAt: d(2026, 6, 1));
      expect(isDormant(m, weekly, now), isTrue);
      expect(projectLens(weekly, [m], now), isEmpty);
    });

    test('a recently-surfaced member is shown', () {
      final m = mem(task(2), surfacedAt: d(2026, 6, 22));
      expect(isDormant(m, weekly, now), isFalse);
      expect(ids(projectLens(weekly, [m], now)), [2]);
    });

    test('a never-surfaced member (surfacedAt null) never goes dormant', () {
      final m = mem(task(3)); // surfacedAt stays null
      expect(isDormant(m, weekly, now), isFalse);
      expect(ids(projectLens(weekly, [m], now)), [3]);
    });

    test('dormancy lasts exactly one period, then candidate again', () {
      final m = mem(task(1), surfacedAt: d(2026, 6, 1));
      // rollovers: 06-08, 06-15, 06-22, 06-29
      expect(isDormant(m, weekly, d(2026, 6, 21)), isFalse); // 2 elapsed
      expect(isDormant(m, weekly, d(2026, 6, 23)), isTrue); // 3 → dormant
      expect(isDormant(m, weekly, d(2026, 6, 28)), isTrue); // still resting
      expect(isDormant(m, weekly, d(2026, 6, 29)), isFalse); // 4 → resurfaces
      expect(ids(projectLens(weekly, [m], d(2026, 6, 29))), [1]);
    });
  });
}
