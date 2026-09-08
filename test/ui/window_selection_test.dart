import 'package:checkfuchs/domain/window_rule.dart';
import 'package:checkfuchs/ui/window_choice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const h = Duration(hours: 1);
  final now = DateTime(2026, 7, 6, 15); // Monday afternoon

  group('WindowSelection', () {
    test('empty = anytime → until-next rule, unbounded one-off', () {
      const s = WindowSelection.anytime;
      expect(s.isAnytime, isTrue);
      expect(s.toRule(), isA<UntilNextOccurrence>());
      expect(s.oneOffWindow(now), (null, null));
    });

    test('one preset → a Slice; toggling anytime clears everything', () {
      final s = WindowSelection.anytime.toggle(WindowChoice.morning);
      expect(s.toRule(), Slice.morning);
      expect(s.hasGaps, isFalse);
      expect(s.toggle(WindowChoice.anytime).isAnytime, isTrue);
    });

    test('morning + evening → MultiSlice with a gap; envelope one-off', () {
      final s = WindowSelection.anytime
          .toggle(WindowChoice.morning)
          .toggle(WindowChoice.evening);
      expect(s.hasGaps, isTrue);
      expect(
        s.toRule(),
        MultiSlice([Slice.morning.asBand, Slice.evening.asBand]),
      );
      // 15:00 today: the envelope (06→24) hasn't ended → today.
      expect(s.oneOffWindow(now), (
        DateTime(2026, 7, 6, 6),
        DateTime(2026, 7, 7),
      ));
    });

    test('adjacent presets merge into one band (no gap)', () {
      final s = WindowSelection.anytime
          .toggle(WindowChoice.morning)
          .toggle(WindowChoice.afternoon);
      expect(s.bands, [Band(from: h * 6, to: h * 18)]);
      expect(s.hasGaps, isFalse);
      expect(s.toRule(), Slice(from: h * 6, to: h * 18));
    });

    test('custom bands add, replace, remove', () {
      var s = WindowSelection.anytime.addCustom(Band(from: h * 13, to: h * 14));
      expect(s.custom, hasLength(1));
      s = s.replaceCustom(0, Band(from: h * 13, to: h * 15));
      expect(s.bands.single.to, h * 15);
      s = s.removeCustom(0);
      expect(s.isAnytime, isTrue);
    });

    test('a passed envelope rolls the one-off to tomorrow', () {
      final s = WindowSelection.anytime.toggle(WindowChoice.morning);
      expect(s.oneOffWindow(now), (
        DateTime(2026, 7, 7, 6),
        DateTime(2026, 7, 7, 12),
      ));
    });

    test('dated window uses the first from / last to on the pinned days', () {
      final s = WindowSelection.anytime
          .toggle(WindowChoice.night)
          .toggle(WindowChoice.evening);
      final (start, end) = s.datedWindow(
        now,
        DateTime(2026, 7, 10),
        DateTime(2026, 7, 12),
      );
      expect(start, DateTime(2026, 7, 10));
      expect(end, DateTime(2026, 7, 13));
    });
  });
}
