import 'package:checkfuchs/data/db/converters.dart';
import 'package:checkfuchs/domain/notification.dart';
import 'package:checkfuchs/domain/task.dart';
import 'package:checkfuchs/domain/template.dart';
import 'package:checkfuchs/domain/recurrence.dart';
import 'package:checkfuchs/domain/window_rule.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day, [int h = 0, int min = 0]) =>
    DateTime(y, m, day, h, min);

void main() {
  const h = Duration(hours: 1);
  final morning = Band(from: h * 6, to: h * 12);
  final evening = Band(from: h * 18, to: h * 24);

  group('Band', () {
    test('contains is per civil day, end-exclusive', () {
      expect(morning.contains(d(2026, 7, 6, 6)), isTrue);
      expect(morning.contains(d(2026, 7, 6, 11, 59)), isTrue);
      expect(morning.contains(d(2026, 7, 6, 12)), isFalse);
      expect(evening.contains(d(2026, 7, 6, 23, 30)), isTrue);
    });

    test('normalize sorts and merges overlapping or touching bands', () {
      final out = Band.normalize([
        evening,
        Band(from: h * 11, to: h * 13),
        morning,
      ]);
      expect(out, [Band(from: h * 6, to: h * 13), evening]);
    });
  });

  group('MultiSlice', () {
    final rule = MultiSlice([evening, morning]);

    test('resolves to the envelope, bands stay sorted', () {
      expect(rule.resolve(d(2026, 7, 6), d(2026, 7, 7)), (
        start: d(2026, 7, 6, 6),
        end: d(2026, 7, 7),
      ));
      expect(rule.bands, [morning, evening]);
    });

    test('materialize stamps the bands on the instance', () {
      final t = Template(
        id: 1,
        name: 'Walk',
        recurrence: Recurrence.daily(d(2026, 7, 6)),
        windowRule: rule,
        createdAt: d(2026, 7, 6),
      ).materialize(d(2026, 7, 6), d(2026, 7, 7), now: d(2026, 7, 6));
      expect(t.bands, [morning, evening]);
      // A plain slice carries no bands: the envelope says it all.
      final s = Template(
        id: 2,
        name: 'Tea',
        recurrence: Recurrence.daily(d(2026, 7, 6)),
        windowRule: Slice.morning,
        createdAt: d(2026, 7, 6),
      ).materialize(d(2026, 7, 6), d(2026, 7, 7), now: d(2026, 7, 6));
      expect(s.bands, isNull);
    });

    test('round-trips through the window rule converter', () {
      const c = WindowRuleConverter();
      expect(c.fromSql(c.toSql(rule)), rule);
      final weekend = MultiSlice([morning], days: 2);
      expect(c.fromSql(c.toSql(weekend)), weekend);
      expect(c.fromSql(c.toSql(weekend)), isNot(MultiSlice([morning])));
      final week = UntilNextOccurrence.withBands([morning, evening]);
      expect(c.fromSql(c.toSql(week)), week);
      expect(c.fromSql(c.toSql(week)), isNot(const UntilNextOccurrence()));
      expect(
        c.fromSql(c.toSql(const UntilNextOccurrence())),
        const UntilNextOccurrence(),
      );
    });

    test('multi-day: the bands repeat on each day of the span', () {
      // Saturday occurrence, open for the weekend, mornings only.
      final weekend = MultiSlice([morning], days: 2);
      expect(weekend.resolve(d(2026, 7, 4), d(2026, 7, 18)), (
        start: d(2026, 7, 4, 6),
        end: d(2026, 7, 5, 12),
      ));
      final t = Template(
        id: 3,
        name: 'Sheets',
        recurrence: Recurrence.weekly(d(2026, 7, 4), interval: 2),
        windowRule: weekend,
        createdAt: d(2026, 7, 4),
      ).materialize(d(2026, 7, 4), d(2026, 7, 18), now: d(2026, 7, 4));
      expect(phaseOf(t, d(2026, 7, 4, 8)), TaskPhase.active);
      expect(phaseOf(t, d(2026, 7, 4, 15)), TaskPhase.pending); // gap
      expect(phaseOf(t, d(2026, 7, 5, 8)), TaskPhase.active); // day 2
      expect(phaseOf(t, d(2026, 7, 5, 13)), TaskPhase.expired);
    });

    test('until-next with bands: any morning until the next occurrence', () {
      final week = UntilNextOccurrence.withBands([morning]);
      expect(week.resolve(d(2026, 7, 6), d(2026, 7, 13)), (
        start: d(2026, 7, 6, 6),
        end: d(2026, 7, 12, 12),
      ));
    });
  });

  group('phaseOf with bands', () {
    final task = Task(
      name: 'Walk',
      start: d(2026, 7, 6, 6),
      end: d(2026, 7, 7),
      createdAt: d(2026, 7, 6),
      bands: [morning, evening],
    );

    test('active inside a band, pending in the gap, expired after the end', () {
      expect(phaseOf(task, d(2026, 7, 6, 5)), TaskPhase.pending);
      expect(phaseOf(task, d(2026, 7, 6, 8)), TaskPhase.active);
      expect(phaseOf(task, d(2026, 7, 6, 14)), TaskPhase.pending); // the gap
      expect(phaseOf(task, d(2026, 7, 6, 20)), TaskPhase.active);
      expect(phaseOf(task, d(2026, 7, 7, 0, 1)), TaskPhase.expired);
      expect(canComplete(task, d(2026, 7, 6, 14)), isFalse);
      expect(canSkip(task, d(2026, 7, 6, 14)), isTrue);
    });

    test('bands round-trip through the task column codec', () {
      expect(bandsFromSql(bandsToSql(task.bands)), task.bands);
      expect(bandsToSql(null), isNull);
    });
  });

  group('day-anchored reminders', () {
    test('onDay splits into daysBefore + timeOfDay', () {
      final n = TaskNotification.onDay(daysBefore: 2, timeOfDay: h * 18);
      expect(n.daysBefore, 2);
      expect(n.timeOfDay, h * 18);
      // Days *after* (a multi-day window): -1 = the second day.
      final after = TaskNotification.onDay(daysBefore: -1, timeOfDay: h * 9);
      expect(after.daysBefore, -1);
      expect(after.timeOfDay, h * 9);
      expect(after.fireTime(day: d(2026, 7, 4)), d(2026, 7, 5, 9));
      final same = TaskNotification.onDay(timeOfDay: h * 9);
      expect(same.daysBefore, 0);
      expect(same.timeOfDay, h * 9);
    });

    test('fires at day midnight + offset, civil arithmetic', () {
      final n = TaskNotification.onDay(daysBefore: 2, timeOfDay: h * 18);
      // Occurrence wins over the window edges.
      expect(
        n.fireTime(
          start: d(2026, 3, 1),
          end: d(2026, 4, 1),
          day: d(2026, 3, 31),
        ),
        d(2026, 3, 29, 18),
      );
      // One-off: the due day, else the start day, else nothing.
      expect(n.fireTime(end: d(2026, 7, 10, 12)), d(2026, 7, 8, 18));
      expect(n.fireTime(start: d(2026, 7, 10, 12)), d(2026, 7, 8, 18));
      expect(n.fireTime(), isNull);
    });

    test('survives the notification list converter', () {
      const c = NotificationListConverter();
      final list = [
        const TaskNotification.atStart(),
        TaskNotification.onDay(daysBefore: 1, timeOfDay: h * 9),
      ];
      expect(c.fromSql(c.toSql(list)), list);
    });
  });
}
