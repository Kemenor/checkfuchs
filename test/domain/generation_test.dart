import 'package:checkfuchs/domain/generation.dart';
import 'package:checkfuchs/domain/recurrence.dart';
import 'package:checkfuchs/domain/task.dart';
import 'package:checkfuchs/domain/template.dart';
import 'package:checkfuchs/domain/window_rule.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day, [int h = 0, int min = 0]) =>
    DateTime(y, m, day, h, min);

Template daily({
  WindowRule rule = const UntilNextOccurrence(),
  bool paused = false,
  DateTime? anchor,
}) =>
    Template(
      id: 1,
      name: 'Brush teeth',
      recurrence: Recurrence.daily(anchor ?? d(2026, 6, 27)),
      windowRule: rule,
      paused: paused,
      createdAt: d(2026, 6, 27),
    );

Task only(ReconcileResult r) => r.changed.single;

void main() {
  group('brand-new template', () {
    test('materialises today as the current open instance', () {
      final r = reconcileTemplate(daily(), [], d(2026, 6, 27, 8));
      final t = only(r);
      expect(t.status, TaskStatus.open);
      expect(t.occurrence, d(2026, 6, 27));
      expect(phaseOf(t, d(2026, 6, 27, 8)), TaskPhase.active);
    });

    test('a morning habit made in the afternoon starts TOMORROW (no spurious miss)', () {
      final r = reconcileTemplate(daily(rule: Slice.morning), [], d(2026, 6, 27, 13));
      final t = only(r);
      expect(t.status, TaskStatus.open);
      expect(t.occurrence, d(2026, 6, 28));
      expect(phaseOf(t, d(2026, 6, 27, 13)), TaskPhase.pending);
    });

    test('a future-anchored template materialises its first occurrence, pending', () {
      final t = only(reconcileTemplate(
          daily(anchor: d(2026, 7, 1)), [], d(2026, 6, 27)));
      expect(t.occurrence, d(2026, 7, 1));
      expect(phaseOf(t, d(2026, 6, 27)), TaskPhase.pending);
    });
  });

  group('steady state', () {
    test('current open instance still in window → no change', () {
      final existing =
          daily().materialize(d(2026, 6, 27), d(2026, 6, 28), now: d(2026, 6, 27, 8));
      final r = reconcileTemplate(daily(), [existing], d(2026, 6, 27, 8));
      expect(r.isEmpty, isTrue);
    });

    test('window passed → expire to Missed AND generate the next (active)', () {
      final today =
          daily().materialize(d(2026, 6, 27), d(2026, 6, 28), now: d(2026, 6, 27));
      final r = reconcileTemplate(daily(), [today], d(2026, 6, 28, 0, 1));
      expect(r.changed.length, 2);
      expect(r.changed[0].status, TaskStatus.missed);
      expect(r.changed[0].resolvedAt, d(2026, 6, 28)); // window end, not "now"
      expect(r.changed[1].status, TaskStatus.open);
      expect(r.changed[1].occurrence, d(2026, 6, 28));
    });

    test('completing today generates tomorrow (pending)', () {
      final doneToday = daily()
          .materialize(d(2026, 6, 27), d(2026, 6, 28), now: d(2026, 6, 27))
          .copyWith(status: TaskStatus.done, resolvedAt: d(2026, 6, 27, 7));
      final t = only(reconcileTemplate(daily(), [doneToday], d(2026, 6, 27, 8)));
      expect(t.occurrence, d(2026, 6, 28));
      expect(phaseOf(t, d(2026, 6, 27, 8)), TaskPhase.pending);
    });
  });

  group('back-fill (app unopened for days)', () {
    test('fills each skipped day as Missed, leaves the current day open', () {
      // Daily habit anchored 06-24; last resolved was 06-24 (Missed); the app is
      // reopened on 06-27 noon, so 06-25 and 06-26 were skipped unseen.
      final habit = daily(anchor: d(2026, 6, 24));
      final old = Task(
        id: 5,
        templateId: 1,
        name: 'Brush teeth',
        status: TaskStatus.missed,
        start: d(2026, 6, 24),
        end: d(2026, 6, 25),
        occurrence: d(2026, 6, 24),
        createdAt: d(2026, 6, 24),
        resolvedAt: d(2026, 6, 25),
      );
      final r = reconcileTemplate(habit, [old], d(2026, 6, 27, 12));
      expect(r.changed.map((t) => t.occurrence),
          [d(2026, 6, 25), d(2026, 6, 26), d(2026, 6, 27)]);
      expect(r.changed[0].status, TaskStatus.missed);
      expect(r.changed[1].status, TaskStatus.missed);
      expect(r.changed[2].status, TaskStatus.open); // current day
    });
  });

  group('gating', () {
    final passedOpen =
        daily().materialize(d(2026, 6, 27), d(2026, 6, 28), now: d(2026, 6, 27))
            .copyWith(id: 9);

    test('paused: the open instance still Misses, but nothing new is generated', () {
      final r = reconcileTemplate(
          daily(paused: true), [passedOpen], d(2026, 6, 28, 0, 1));
      expect(only(r).status, TaskStatus.missed);
    });

    test('vacation: no generation', () {
      final r = reconcileTemplate(daily(), [], d(2026, 6, 27, 8),
          vacationActive: true);
      expect(r.isEmpty, isTrue);
    });
  });

  group('idempotency', () {
    test('reconcile∘reconcile produces no further change', () {
      final now = d(2026, 6, 27, 8);
      final first = reconcileTemplate(daily(), [], now);
      final second = reconcileTemplate(daily(), first.changed, now);
      expect(second.isEmpty, isTrue);
    });
  });
}
