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
      fuchsbauTheme(Brightness.light, font: font);
  static ThemeData dark({FuchsbauFont font = FuchsbauFont.figtree}) =>
      fuchsbauTheme(Brightness.dark, font: font);
}
