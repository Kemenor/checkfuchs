import 'package:checkfuchs/domain/derive.dart';
import 'package:checkfuchs/domain/lens.dart';
import 'package:checkfuchs/domain/recurrence.dart';
import 'package:checkfuchs/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

Task task(int id,
        {DateTime? end,
        DateTime? occ,
        TaskStatus status = TaskStatus.open}) =>
    Task(
      id: id,
      name: 't$id',
      status: status,
      end: end,
      occurrence: occ,
      createdAt: d(2026, 6, 1),
    );

LensMember mem(Task t, {int order = 0, DateTime? surfacedAt}) =>
    LensMember(task: t, order: order, surfacedAt: surfacedAt);

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
  });
}
