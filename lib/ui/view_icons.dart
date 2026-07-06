import 'package:flutter/material.dart';

/// The curated View icon set (DESIGN_SYSTEM §3.3): each View carries a stable
/// slug; the bottom navigation bar and the new-view picker resolve it here.
/// Slugs are persisted — only ever *add* to this map, never rename entries.
const viewIcons = <String, IconData>{
  'home': Icons.home_rounded,
  'checklist': Icons.task_alt_rounded,
  'repeat': Icons.event_repeat_rounded,
  'calendar': Icons.event_rounded,
  'inbox': Icons.inbox_rounded,
  'star': Icons.star_rounded,
  'work': Icons.work_outline_rounded,
  'fitness': Icons.fitness_center_rounded,
  'school': Icons.school_rounded,
  'cart': Icons.shopping_cart_rounded,
  'leaf': Icons.eco_rounded,
  'heart': Icons.favorite_rounded,
};

/// Resolve a stored slug, falling back safely for unknown values.
IconData viewIcon(String slug) =>
    viewIcons[slug] ?? Icons.space_dashboard_rounded;
