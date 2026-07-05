import 'package:checkfuchs/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime dt(int y, int m, int d, [int h = 0, int min = 0]) =>
    DateTime(y, m, d, h, min);

Task taskWith({
  DateTime? start,
  DateTime? end,
  TaskStatus status = TaskStatus.open,
}) => Task(
  name: 'Brush teeth',
  status: status,
  start: start,
  end: end,
  createdAt: dt(2026, 6, 1),
);

void main() {
  final morning = dt(2026, 6, 27, 8); // inside an 00:00–12:00 window

  group('phaseOf', () {
    test('pending before start', () {
      final t = taskWith(start: dt(2026, 6, 28), end: dt(2026, 6, 28, 12));
      expect(phaseOf(t, morning), TaskPhase.pending);
    });

    test('active within the window', () {
      final t = taskWith(start: dt(2026, 6, 27), end: dt(2026, 6, 27, 12));
      expect(phaseOf(t, morning), TaskPhase.active);
    });

    test('active when unbounded (no end)', () {
      final t = taskWith(); // no start, no end
      expect(phaseOf(t, morning), TaskPhase.active);
    });

    test('expired after end', () {
      final t = taskWith(start: dt(2026, 6, 27), end: dt(2026, 6, 27, 12));
      expect(phaseOf(t, dt(2026, 6, 27, 13)), TaskPhase.expired);
    });
  });

  group('action rules', () {
    final active = taskWith(start: dt(2026, 6, 27), end: dt(2026, 6, 27, 12));
    final pending = taskWith(start: dt(2026, 6, 28), end: dt(2026, 6, 28, 12));
    final expired = taskWith(start: dt(2026, 6, 27), end: dt(2026, 6, 27, 12));
    final unbounded = taskWith();

    test('Done only while active+open', () {
      expect(canComplete(active, morning), isTrue);
      expect(canComplete(pending, morning), isFalse); // pending
      expect(canComplete(expired, dt(2026, 6, 27, 13)), isFalse); // expired
      expect(canComplete(unbounded, morning), isTrue);
      expect(
        canComplete(active.copyWith(status: TaskStatus.done), morning),
        isFalse, // terminal
      );
    });

    test('Skip anytime while open except expired', () {
      expect(canSkip(active, morning), isTrue);
      expect(canSkip(pending, morning), isTrue); // pre-empt
      expect(canSkip(expired, dt(2026, 6, 27, 13)), isFalse);
      expect(
        canSkip(active.copyWith(status: TaskStatus.skipped), morning),
        isFalse,
      );
    });
  });

  group('copyWith clearing', () {
    final full = Task(
      name: 'Brush teeth',
      note: 'gently',
      status: TaskStatus.done,
      start: dt(2026, 6, 27),
      end: dt(2026, 6, 27, 12),
      occurrence: dt(2026, 6, 27),
      createdAt: dt(2026, 6, 1),
      resolvedAt: dt(2026, 6, 27, 8),
    );

    test('an explicit null clears end/note/resolvedAt/occurrence', () {
      final cleared = full.copyWith(
        end: null,
        note: null,
        resolvedAt: null,
        occurrence: null,
      );
      expect(cleared.end, isNull);
      expect(cleared.note, isNull);
      expect(cleared.resolvedAt, isNull);
      expect(cleared.occurrence, isNull);
      expect(cleared.start, full.start); // untouched fields survive
      expect(cleared.name, full.name);
    });

    test('omitting the arguments keeps the current values', () {
      expect(full.copyWith(), full);
    });
  });

  group('transitions', () {
    test('complete → Done with resolvedAt = now', () {
      final t = taskWith(start: dt(2026, 6, 27), end: dt(2026, 6, 27, 12));
      final done = complete(t, morning);
      expect(done.status, TaskStatus.done);
      expect(done.resolvedAt, morning);
    });

    test('skip → Skipped with resolvedAt = now', () {
      final t = taskWith(start: dt(2026, 6, 27), end: dt(2026, 6, 27, 12));
      final skipped = skip(t, morning);
      expect(skipped.status, TaskStatus.skipped);
      expect(skipped.resolvedAt, morning);
    });

    test('expireIfDue → Missed with resolvedAt = window end', () {
      final end = dt(2026, 6, 27, 12);
      final t = taskWith(start: dt(2026, 6, 27), end: end);
      final missed = expireIfDue(t, dt(2026, 6, 27, 13));
      expect(missed, isNotNull);
      expect(missed!.status, TaskStatus.missed);
      expect(missed.resolvedAt, end); // when it actually failed, not "now"
    });

    test(
      'expireIfDue is a no-op for active / pending / unbounded / terminal',
      () {
        final active = taskWith(
          start: dt(2026, 6, 27),
          end: dt(2026, 6, 27, 12),
        );
        expect(expireIfDue(active, morning), isNull);
        expect(
          expireIfDue(taskWith(), morning),
          isNull,
        ); // unbounded, never fails
        expect(
          expireIfDue(
            active.copyWith(status: TaskStatus.done),
            dt(2026, 6, 27, 13),
          ),
          isNull, // already terminal
        );
      },
    );

    test('window opened AND closed while away → straight to Missed', () {
      // created in advance for a 14–25 Jul window; opened the app in August.
      final end = dt(2026, 7, 25, 23, 59);
      final t = taskWith(start: dt(2026, 7, 14), end: end);
      final missed = expireIfDue(t, dt(2026, 8, 3));
      expect(missed?.status, TaskStatus.missed);
      expect(missed?.resolvedAt, end);
    });
  });
}
