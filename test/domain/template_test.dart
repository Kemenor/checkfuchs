import 'package:checkfuchs/domain/recurrence.dart';
import 'package:checkfuchs/domain/task.dart';
import 'package:checkfuchs/domain/template.dart';
import 'package:checkfuchs/domain/window_rule.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day, [int h = 0]) => DateTime(y, m, day, h);

void main() {
  final occ = d(2026, 6, 27);
  final next = d(2026, 6, 28);

  group('window rules', () {
    test('morning slice → 00:00–12:00', () {
      expect(Slice.morning.resolve(occ, next),
          (start: d(2026, 6, 27, 0), end: d(2026, 6, 27, 12)));
    });

    test('evening slice → 18:00–24:00', () {
      expect(Slice.evening.resolve(occ, next),
          (start: d(2026, 6, 27, 18), end: d(2026, 6, 28, 0)));
    });

    test('until-next → occurrence midnight to next occurrence midnight', () {
      expect(const UntilNextOccurrence().resolve(occ, next),
          (start: d(2026, 6, 27), end: d(2026, 6, 28)));
    });

    test('fixed duration → occurrence + length', () {
      expect(const FixedDuration(Duration(days: 7)).resolve(occ, next),
          (start: d(2026, 6, 27), end: d(2026, 7, 4)));
    });
  });

  group('materialize', () {
    final daily = Template(
      id: 1,
      name: 'Brush teeth',
      recurrence: Recurrence.daily(occ),
      windowRule: Slice.morning,
      createdAt: d(2026, 6, 1),
    );

    test('stamps the window, occurrence, template link, open status', () {
      final t = daily.materialize(occ, next, now: d(2026, 6, 27, 6));
      expect(t.templateId, 1);
      expect(t.name, 'Brush teeth');
      expect(t.status, TaskStatus.open);
      expect(t.start, d(2026, 6, 27, 0));
      expect(t.end, d(2026, 6, 27, 12));
      expect(t.occurrence, d(2026, 6, 27));
      expect(t.createdAt, d(2026, 6, 27, 6));
    });

    test('default window rule is back-to-back (until next)', () {
      final habit = Template(
        name: 'Weigh',
        recurrence: Recurrence.daily(occ),
        createdAt: d(2026, 6, 1),
      );
      final t = habit.materialize(occ, next, now: d(2026, 6, 27));
      expect(t.start, d(2026, 6, 27));
      expect(t.end, d(2026, 6, 28));
    });
  });

  group('generatesAt (pause §3.5)', () {
    Template tmpl({bool paused = false, DateTime? resumeOn}) => Template(
          name: 'x',
          recurrence: Recurrence.daily(occ),
          paused: paused,
          resumeOn: resumeOn,
          createdAt: d(2026, 6, 1),
        );
    final now = d(2026, 6, 27);

    test('not paused → generates', () {
      expect(tmpl().generatesAt(now), isTrue);
    });
    test('paused, no resume → suspended indefinitely', () {
      expect(tmpl(paused: true).generatesAt(now), isFalse);
    });
    test('paused, resume in the past → resumed', () {
      expect(tmpl(paused: true, resumeOn: d(2026, 6, 20)).generatesAt(now), isTrue);
    });
    test('paused, resume in the future → still suspended', () {
      expect(tmpl(paused: true, resumeOn: d(2026, 7, 1)).generatesAt(now), isFalse);
    });
  });
}
