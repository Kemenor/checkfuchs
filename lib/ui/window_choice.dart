import '../domain/window_rule.dart';
import '../l10n/app_localizations.dart';

/// The friendly active-window picker (Anytime / Morning / Afternoon / Evening)
/// over the general [WindowRule] — shared by the create-task sheet and the
/// first-run onboarding sheet.
enum WindowChoice {
  anytime,
  morning,
  afternoon,
  evening;

  String label(AppLocalizations l10n) => switch (this) {
    WindowChoice.anytime => l10n.windowAnytime,
    WindowChoice.morning => l10n.windowMorning,
    WindowChoice.afternoon => l10n.windowAfternoon,
    WindowChoice.evening => l10n.windowEvening,
  };

  WindowRule toRule() => switch (this) {
    WindowChoice.anytime => const UntilNextOccurrence(),
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
    final (int fromHour, int toHour) = switch (this) {
      WindowChoice.anytime => (0, 0),
      WindowChoice.morning => (0, 12),
      WindowChoice.afternoon => (12, 18),
      WindowChoice.evening => (18, 24),
    };
    if (this == WindowChoice.anytime) return (null, null);

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
}
