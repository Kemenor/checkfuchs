import 'package:flutter/material.dart';

/// Checkfuchs theme — inherits the Fuchsbau design system.
///
/// The brand is a **triadic** palette (Fuchsbau/DESIGN.md): fox tangerine with
/// indigo + emerald partners 120° apart. We do NOT use a single-seed
/// `ColorScheme.fromSeed` (it would derive secondary/tertiary from one hue and
/// collapse the triad). Instead we seed three schemes — one per hue — and graft
/// indigo onto `secondary` and emerald onto `tertiary`, so each role keeps a
/// tonally-correct container/on-colour set.
class FuchsbauColors {
  const FuchsbauColors._();

  static const foxOrange = Color(0xFFEA7A24); // 26° — primary / brand / active
  static const indigo = Color(0xFF8559D0); //   266° — secondary / structure / focus
  static const emerald = Color(0xFF1FA85D); //  146° — tertiary / positive / done
}

ColorScheme _triadScheme(Brightness brightness) {
  final base = ColorScheme.fromSeed(
    seedColor: FuchsbauColors.foxOrange,
    brightness: brightness,
  );
  final indigo = ColorScheme.fromSeed(
    seedColor: FuchsbauColors.indigo,
    brightness: brightness,
  );
  final emerald = ColorScheme.fromSeed(
    seedColor: FuchsbauColors.emerald,
    brightness: brightness,
  );
  return base.copyWith(
    secondary: indigo.primary,
    onSecondary: indigo.onPrimary,
    secondaryContainer: indigo.primaryContainer,
    onSecondaryContainer: indigo.onPrimaryContainer,
    tertiary: emerald.primary,
    onTertiary: emerald.onPrimary,
    tertiaryContainer: emerald.primaryContainer,
    onTertiaryContainer: emerald.onPrimaryContainer,
  );
}

ThemeData _theme(Brightness brightness) {
  final scheme = _triadScheme(brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    // Soft, friendly rounding (Fuchsbau): cards lg(20), FAB full pill.
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: StadiumBorder(),
    ),
  );
  // TODO(theme): bundle Figtree + the accessibility font picker; add a
  //   ThemeExtension for the status colours (taupe/amber). Deferred past Phase 0.
}

class CheckfuchsTheme {
  const CheckfuchsTheme._();

  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);
}
