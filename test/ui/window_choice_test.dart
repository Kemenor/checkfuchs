import 'package:checkfuchs/ui/window_choice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 6, 15); // Monday afternoon

  group('datedWindow', () {
    test('no dates falls back to the slice defaults', () {
      expect(WindowChoice.anytime.datedWindow(now, null, null), (null, null));
      // Evening at 15:00 → tonight's slice.
      expect(WindowChoice.evening.datedWindow(now, null, null), (
        DateTime(2026, 7, 6, 18),
        DateTime(2026, 7, 7),
      ));
    });

    test('bare due date: open from now until the end of that day', () {
      final (start, end) = WindowChoice.anytime.datedWindow(
        now,
        null,
        DateTime(2026, 7, 29),
      );
      expect(start, isNull);
      expect(end, DateTime(2026, 7, 30)); // midnight after the 29th
    });

    test('start + due spans the range ("month of May")', () {
      expect(
        WindowChoice.anytime.datedWindow(
          now,
          DateTime(2027, 5, 1),
          DateTime(2027, 5, 31),
        ),
        (DateTime(2027, 5, 1), DateTime(2027, 6, 1)),
      );
    });

    test('slice shapes the hours within the pinned days', () {
      // "Due the morning of the 29th."
      expect(
        WindowChoice.morning.datedWindow(now, null, DateTime(2026, 7, 29)).$2,
        DateTime(2026, 7, 29, 12),
      );
      // Night on a bare due date ends at 06:00 that day.
      expect(
        WindowChoice.night.datedWindow(now, null, DateTime(2026, 7, 29)).$2,
        DateTime(2026, 7, 29, 6),
      );
      // Evening start on the 10th opens at 18:00.
      expect(
        WindowChoice.evening.datedWindow(now, DateTime(2026, 7, 10), null).$1,
        DateTime(2026, 7, 10, 18),
      );
    });
  });
}
