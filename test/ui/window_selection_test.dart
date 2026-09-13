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

    test('one preset → until-next with a band; same day → a Slice', () {
      final s = WindowSelection.anytime.toggle(WindowChoice.morning);
      expect(s.toRule(), UntilNextOccurrence.withBands([Slice.morning.asBand]));
      expect(s.withDays(1).toRule(), Slice.morning);
      expect(s.hasGaps, isFalse);
      expect(s.toggle(WindowChoice.anytime).isAnytime, isTrue);
    });

    test('morning + evening → MultiSlice with a gap; envelope one-off', () {
      final s = WindowSelection.anytime
          .toggle(WindowChoice.morning)
          .toggle(WindowChoice.evening);
      expect(s.hasGaps, isTrue);
      expect(
        s.withDays(1).toRule(),
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
      expect(s.withDays(1).toRule(), Slice(from: h * 6, to: h * 18));
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

    test(
      'a future start with no due date ends on that day, never before it',
      () {
        final morning = WindowSelection.anytime.toggle(WindowChoice.morning);
        final (s1, e1) = morning.datedWindow(now, DateTime(2026, 7, 15), null);
        expect(s1, DateTime(2026, 7, 15, 6));
        expect(e1, DateTime(2026, 7, 15, 12));
        final (s2, e2) = WindowSelection.anytime.datedWindow(
          now,
          DateTime(2026, 7, 15),
          null,
        );
        expect(s2, DateTime(2026, 7, 15));
        expect(e2, isNull); // Anytime: open-ended, never misses
      },
    );

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

  group('fromRule / fromEdges', () {
    test('round-trips the chip-representable rules', () {
      expect(
        WindowSelection.fromRule(const UntilNextOccurrence())!.isAnytime,
        isTrue,
      );
      final fromSlice = WindowSelection.fromRule(Slice.morning)!;
      expect(fromSlice.presets, {WindowChoice.morning});
      expect(fromSlice.days, 1);
      final multi = MultiSlice([
        Slice.evening.asBand,
        Band(from: h * 13, to: h * 14),
      ]);
      final sel = WindowSelection.fromRule(multi)!;
      expect(sel.presets, {WindowChoice.evening});
      expect(sel.custom, [Band(from: h * 13, to: h * 14)]);
      expect(sel.toRule(), multi);
      expect(
        WindowSelection.fromRule(const FixedDuration(Duration(days: 7)))!.days,
        7,
      );
    });

    test('fromEdges: bands win, same-day span is one band, else anytime', () {
      expect(
        WindowSelection.fromEdges(null, null, [Slice.night.asBand]).presets,
        {WindowChoice.night},
      );
      final s = WindowSelection.fromEdges(
        DateTime(2026, 7, 6, 6),
        DateTime(2026, 7, 6, 12),
        null,
      );
      expect(s.presets, {WindowChoice.morning});
      expect(
        WindowSelection.fromEdges(
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 31),
          null,
        ).isAnytime,
        isTrue,
      );
    });
  });

  group('open for N days', () {
    test('days → FixedDuration and back; bands and days are independent', () {
      final s = WindowSelection.anytime.withDays(2);
      expect(s.isAnytime, isFalse);
      expect(s.allDay, isTrue);
      expect(s.toRule(), const FixedDuration(Duration(days: 2)));
      expect(WindowSelection.fromRule(s.toRule())!.days, 2);
      // "Weekend mornings": 2 days × morning → a multi-day MultiSlice.
      final weekend = s.toggle(WindowChoice.morning);
      expect(weekend.days, 2);
      expect(weekend.toRule(), MultiSlice([Slice.morning.asBand], days: 2));
      final back = WindowSelection.fromRule(weekend.toRule())!;
      expect(back.days, 2);
      expect(back.presets, {WindowChoice.morning});
      expect(weekend.toggle(WindowChoice.anytime).days, 2);
      expect(weekend.withDays(null).presets, {WindowChoice.morning});
      expect(
        WindowSelection.fromRule(
          UntilNextOccurrence.withBands([Slice.evening.asBand]),
        )!.presets,
        {WindowChoice.evening},
      );
      expect(s.withDays(null).isAnytime, isTrue);
      // A non-whole-day duration has no chip form.
      expect(
        WindowSelection.fromRule(const FixedDuration(Duration(hours: 36))),
        isNull,
      );
    });
  });
}
