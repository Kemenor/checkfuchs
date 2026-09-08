import 'package:flutter/material.dart';

import '../domain/window_rule.dart';
import '../l10n/app_localizations.dart';

/// The friendly active-window picker (Anytime / Night / Morning / Afternoon /
/// Evening)
/// over the general [WindowRule] — shared by the create-task sheet and the
/// first-run onboarding sheet.
enum WindowChoice {
  anytime,
  night,
  morning,
  afternoon,
  evening;

  String label(AppLocalizations l10n) => switch (this) {
    WindowChoice.anytime => l10n.windowAnytime,
    WindowChoice.night => l10n.windowNight,
    WindowChoice.morning => l10n.windowMorning,
    WindowChoice.afternoon => l10n.windowAfternoon,
    WindowChoice.evening => l10n.windowEvening,
  };

  WindowRule toRule() => switch (this) {
    WindowChoice.anytime => const UntilNextOccurrence(),
    WindowChoice.night => Slice.night,
    WindowChoice.morning => Slice.morning,
    WindowChoice.afternoon => Slice.afternoon,
    WindowChoice.evening => Slice.evening,
  };

  /// (start, end) for a one-off created at [now]. "Anytime" = unbounded (never
  /// misses). A slice whose window has already fully passed today rolls to
  /// tomorrow — otherwise a "Morning" task created in the afternoon would be
  /// born expired: uncompletable, unskippable, and dead on arrival. Bounds are
  /// built civilly (calendar date + wall-clock time), so they're DST-safe.
  (DateTime?, DateTime?) oneOffWindow(DateTime now) {
    if (this == WindowChoice.anytime) return (null, null);
    final (fromHour, toHour) = _hours;

    DateTime at(DateTime d, int hour) =>
        DateTime(d.year, d.month, d.day + (hour ~/ 24), hour % 24);

    var day = DateTime(now.year, now.month, now.day);
    var end = at(day, toHour);
    if (!end.isAfter(now)) {
      day = DateTime(day.year, day.month, day.day + 1);
      end = at(day, toHour);
    }
    return (at(day, fromHour), end);
  }

  /// A one-off window pinned to explicit dates: [startDate]/[dueDate] choose
  /// the days, the slice supplies the wall-clock edges within them ("due
  /// morning of the 29th"). Anytime spans whole days — a bare due date means
  /// "open from now until the end of that day", a start+due pair spans the
  /// range ("the month of May"). Unset dates fall back to [oneOffWindow].
  (DateTime?, DateTime?) datedWindow(
    DateTime now,
    DateTime? startDate,
    DateTime? dueDate,
  ) {
    final (fromHour, toHour) = this == WindowChoice.anytime ? (0, 24) : _hours;
    DateTime at(DateTime d, int hour) =>
        DateTime(d.year, d.month, d.day + (hour ~/ 24), hour % 24);

    final (defaultStart, defaultEnd) = oneOffWindow(now);
    return (
      startDate == null ? defaultStart : at(startDate, fromHour),
      dueDate == null ? defaultEnd : at(dueDate, toHour),
    );
  }

  /// The wall-clock band (from, to) in hours — mirrors the [Slice] presets.
  (int, int) get _hours => switch (this) {
    WindowChoice.anytime => (0, 24),
    WindowChoice.night => (0, 6),
    WindowChoice.morning => (6, 12),
    WindowChoice.afternoon => (12, 18),
    WindowChoice.evening => (18, 24),
  };
}

/// The multi-band active-window picker state (examples/ui/07): any set of
/// the preset bands plus custom bands. Empty = Anytime. "Morning + Evening"
/// means *one* task, done once in either band (the gap is honoured by
/// `phaseOf`); people who want it twice make two tasks.
class WindowSelection {
  const WindowSelection({this.presets = const {}, this.custom = const []});

  static const anytime = WindowSelection();

  /// Rebuild the picker state from a stored rule — bands that match a preset
  /// become that chip, the rest custom rows. Null when the rule has no chip
  /// form (a [FixedDuration]); callers then keep the rule untouched.
  static WindowSelection? fromRule(WindowRule rule) => switch (rule) {
    UntilNextOccurrence() => anytime,
    Slice(:final from, :final to) => fromBands([Band(from: from, to: to)]),
    MultiSlice(:final bands) => fromBands(bands),
    FixedDuration() => null,
  };

  /// The picker state for a one-off from its stored edges: explicit bands
  /// win; a same-day start…end pair is one band; anything else is Anytime.
  static WindowSelection fromEdges(
    DateTime? start,
    DateTime? end,
    List<Band>? bands,
  ) {
    if (bands != null && bands.isNotEmpty) return fromBands(bands);
    if (start == null || end == null) return anytime;
    final span = end.difference(start);
    if (span <= Duration.zero || span >= const Duration(hours: 24)) {
      return anytime;
    }
    final from = Duration(hours: start.hour, minutes: start.minute);
    return fromBands([Band(from: from, to: from + span)]);
  }

  static WindowSelection fromBands(List<Band> bands) {
    final presets = <WindowChoice>{};
    final custom = <Band>[];
    for (final b in bands) {
      final match = WindowChoice.values.where(
        (c) =>
            c != WindowChoice.anytime &&
            Duration(hours: c._hours.$1) == b.from &&
            Duration(hours: c._hours.$2) == b.to,
      );
      match.isEmpty ? custom.add(b) : presets.add(match.first);
    }
    return WindowSelection(presets: presets, custom: custom);
  }

  /// Preset bands (never [WindowChoice.anytime]).
  final Set<WindowChoice> presets;

  /// Extra bands added via "Custom…", in insertion order.
  final List<Band> custom;

  bool get isAnytime => presets.isEmpty && custom.isEmpty;

  /// All bands, merged and sorted.
  List<Band> get bands => Band.normalize([
    for (final p in presets)
      Band(
        from: Duration(hours: p._hours.$1),
        to: Duration(hours: p._hours.$2),
      ),
    ...custom,
  ]);

  /// Whether the merged bands leave a gap (needs `Task.bands`).
  bool get hasGaps => bands.length > 1;

  WindowSelection toggle(WindowChoice c) => c == WindowChoice.anytime
      ? anytime
      : WindowSelection(
          presets: presets.contains(c)
              ? ({...presets}..remove(c))
              : {...presets, c},
          custom: custom,
        );

  WindowSelection addCustom(Band b) =>
      WindowSelection(presets: presets, custom: [...custom, b]);

  WindowSelection replaceCustom(int i, Band b) => WindowSelection(
    presets: presets,
    custom: [for (var k = 0; k < custom.length; k++) k == i ? b : custom[k]],
  );

  WindowSelection removeCustom(int i) => WindowSelection(
    presets: presets,
    custom: [
      for (var k = 0; k < custom.length; k++)
        if (k != i) custom[k],
    ],
  );

  /// The series rule: Anytime → until-next; one band → [Slice]; several →
  /// [MultiSlice].
  WindowRule toRule() {
    final b = bands;
    if (b.isEmpty) return const UntilNextOccurrence();
    if (b.length == 1) return Slice(from: b.first.from, to: b.first.to);
    return MultiSlice(b);
  }

  /// (start, end) for a one-off created at [now] — the envelope; see
  /// [WindowChoice.oneOffWindow] for the roll-to-tomorrow rule.
  (DateTime?, DateTime?) oneOffWindow(DateTime now) {
    final b = bands;
    if (b.isEmpty) return (null, null);
    DateTime at(DateTime day, Duration o) => DateTime(
      day.year,
      day.month,
      day.day + o.inDays,
      (o - Duration(days: o.inDays)).inHours,
      o.inMinutes % 60,
    );
    var day = DateTime(now.year, now.month, now.day);
    var end = at(day, b.last.to);
    if (!end.isAfter(now)) {
      day = DateTime(day.year, day.month, day.day + 1);
      end = at(day, b.last.to);
    }
    return (at(day, b.first.from), end);
  }

  /// Date-pinned one-off window (see [WindowChoice.datedWindow]).
  (DateTime?, DateTime?) datedWindow(
    DateTime now,
    DateTime? startDate,
    DateTime? dueDate,
  ) {
    final b = bands;
    final (from, to) = b.isEmpty
        ? (Duration.zero, const Duration(hours: 24))
        : (b.first.from, b.last.to);
    DateTime at(DateTime day, Duration o) => DateTime(
      day.year,
      day.month,
      day.day + o.inDays,
      (o - Duration(days: o.inDays)).inHours,
      o.inMinutes % 60,
    );
    final (defaultStart, defaultEnd) = b.isEmpty
        ? WindowChoice.anytime.datedWindow(now, null, null)
        : oneOffWindow(now);
    return (
      startDate == null ? defaultStart : at(startDate, from),
      dueDate == null ? defaultEnd : at(dueDate, to),
    );
  }

  /// "06:00–12:00, 18:00–24:00" in the locale's 24h/12h style.
  String describe(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final always24 = MediaQuery.alwaysUse24HourFormatOf(context);
    String f(Duration o) {
      final h = o.inHours, m = o.inMinutes % 60;
      if (h == 24) {
        return always24
            ? '24:00'
            : loc.formatTimeOfDay(
                const TimeOfDay(hour: 0, minute: 0),
                alwaysUse24HourFormat: always24,
              );
      }
      return loc.formatTimeOfDay(
        TimeOfDay(hour: h, minute: m),
        alwaysUse24HourFormat: always24,
      );
    }

    return bands.map((b) => '${f(b.from)}–${f(b.to)}').join(', ');
  }
}
