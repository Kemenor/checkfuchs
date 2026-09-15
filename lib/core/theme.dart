import 'package:flutter/material.dart';
import 'package:fuchsbau/fuchsbau.dart';

/// Checkfuchs theme — delegates to the shared **Fuchsbau** design system
/// (the pinned tangerine triad, Figtree, status colours, quiet elevation, soft
/// rounding). checkfuchs-specific component themes get layered here as they
/// arrive; the foundation stays in one place (the `fuchsbau` package).
/// The app entry MUST build its themes through here (not `fuchsbauTheme`
/// directly) so every caller carries the user's typeface setting — dropping
/// [font] silently discards the accessibility font picker.
class CheckfuchsTheme {
  const CheckfuchsTheme._();

  static ThemeData light({FuchsbauFont font = FuchsbauFont.figtree}) =>
      _themed(fuchsbauTheme(Brightness.light, font: font));
  static ThemeData dark({FuchsbauFont font = FuchsbauFont.figtree}) =>
      _themed(fuchsbauTheme(Brightness.dark, font: font));

  /// The FAB is the app's primary action and must read as a button. Material's
  /// default fill is `primaryContainer`, which in this palette is orange mixed
  /// into the card colour — 1.09:1 against the page, i.e. an invisible button.
  /// The family default is tangerine (fuchsbau DESIGN.md §4); it is applied
  /// here, app-level, exactly as knabberfuchs applies its emerald one.
  static ThemeData _themed(ThemeData base) => base.copyWith(
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
      backgroundColor: base.colorScheme.primary,
      foregroundColor: base.colorScheme.onPrimary,
    ),
  );
}
