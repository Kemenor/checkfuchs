import 'package:flutter/material.dart';
import 'package:fuchsbau/fuchsbau.dart';

/// Checkfuchs theme — delegates to the shared **Fuchsbau** design system
/// (the pinned tangerine triad, Figtree, status colours, quiet elevation, soft
/// rounding). checkfuchs-specific component themes get layered here as they
/// arrive; the foundation stays in one place (the `fuchsbau` package).
class CheckfuchsTheme {
  const CheckfuchsTheme._();

  static ThemeData get light => fuchsbauTheme(Brightness.light);
  static ThemeData get dark => fuchsbauTheme(Brightness.dark);
}
