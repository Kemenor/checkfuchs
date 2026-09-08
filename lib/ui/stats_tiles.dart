import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';

/// The Stats tiles (examples/ui/09-stats.html). Adding a tile = one entry
/// here + its widget in stats_screen.dart; the Edit tiles screen and the
/// settings JSON pick it up unchanged.
enum StatsTile {
  completion('completion', Symbols.percent_rounded),
  week('week', Symbols.date_range_rounded),
  streaks('streaks', Symbols.local_fire_department_rounded),
  insight('insight', Symbols.lightbulb_rounded),
  heatmap('heatmap', Symbols.grid_on_rounded),
  byWindow('byWindow', Symbols.schedule_rounded),
  missesByWeekday('missesByWeekday', Symbols.bar_chart_rounded);

  const StatsTile(this.id, this.icon);

  final String id;
  final IconData icon;

  static StatsTile? byId(String id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }

  String title(AppLocalizations l10n) => switch (this) {
    StatsTile.completion => l10n.tileCompletion,
    StatsTile.week => l10n.tileWeek,
    StatsTile.streaks => l10n.tileStreaks,
    StatsTile.insight => l10n.tileInsight,
    StatsTile.heatmap => l10n.tileHeatmap,
    StatsTile.byWindow => l10n.tileByWindow,
    StatsTile.missesByWeekday => l10n.tileMissesByWeekday,
  };

  String subtitle(AppLocalizations l10n) => switch (this) {
    StatsTile.completion => l10n.tileCompletionSub,
    StatsTile.week => l10n.tileWeekSub,
    StatsTile.streaks => l10n.tileStreaksSub,
    StatsTile.insight => l10n.tileInsightSub,
    StatsTile.heatmap => l10n.tileHeatmapSub,
    StatsTile.byWindow => l10n.tileByWindowSub,
    StatsTile.missesByWeekday => l10n.tileMissesByWeekdaySub,
  };
}

/// Enabled tiles in display order, unknown ids dropped.
List<StatsTile> enabledTiles(List<String> ids) => [
  for (final id in ids) ?StatsTile.byId(id),
];

/// Every tile: the enabled ones in their stored order, then the rest in
/// canonical order — the Edit tiles list.
List<StatsTile> orderedTiles(List<String> ids) {
  final on = enabledTiles(ids);
  return [
    ...on,
    for (final t in StatsTile.values)
      if (!on.contains(t)) t,
  ];
}
