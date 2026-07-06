import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// The curated View icon set (DESIGN_SYSTEM §3.3): each View carries a stable
/// slug; the bottom navigation bar and the new-view picker resolve it here.
/// Slugs are persisted — only ever *add* to this map, never rename entries.
const viewIcons = <String, IconData>{
  'home': Symbols.home_rounded,
  'checklist': Symbols.task_alt_rounded,
  'repeat': Symbols.event_repeat_rounded,
  'calendar': Symbols.event_rounded,
  'inbox': Symbols.inbox_rounded,
  'star': Symbols.star_rounded,
  'work': Symbols.work_outline_rounded,
  'fitness': Symbols.fitness_center_rounded,
  'school': Symbols.school_rounded,
  'cart': Symbols.shopping_cart_rounded,
  'leaf': Symbols.eco_rounded,
  'heart': Symbols.favorite_rounded,
};

/// Resolve a stored slug, falling back safely for unknown values.
IconData viewIcon(String slug) =>
    viewIcons[slug] ?? Symbols.space_dashboard_rounded;
