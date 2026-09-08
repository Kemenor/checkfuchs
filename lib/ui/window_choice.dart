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
