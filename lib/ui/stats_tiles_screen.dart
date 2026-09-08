import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'stats_tiles.dart';

/// Edit tiles: every Stats tile as a switch row with a drag handle. Enabled
/// tiles keep the user's order; disabled ones sit below in canonical order.
/// Every change persists immediately.
class StatsTilesScreen extends ConsumerWidget {
  const StatsTilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabledIds = ref.watch(settingsProvider).effectiveStatsTiles;
    final enabled = enabledTiles(enabledIds);
    final all = orderedTiles(enabledIds);
    final controller = ref.read(settingsProvider.notifier);

    void persist(List<StatsTile> order, Set<StatsTile> on) {
      controller.setStatsTiles([
        for (final t in order)
          if (on.contains(t)) t.id,
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsEditTiles)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              l10n.statsEditTilesHint,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: EdgeInsets.only(
                top: 8,
                bottom: 8 + MediaQuery.paddingOf(context).bottom,
              ),
              buildDefaultDragHandles: false,
              itemCount: all.length,
              onReorderItem: (from, to) {
                final order = [...all];
                final moved = order.removeAt(from);
                order.insert(to, moved);
                persist(order, enabled.toSet());
              },
              itemBuilder: (context, i) {
                final tile = all[i];
                final on = enabled.contains(tile);
                return Material(
                  key: ValueKey(tile.id),
                  color: scheme.surface,
                  child: SwitchListTile(
                    contentPadding: fuchsbauCardRowPadding,
                    secondary: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: Icon(
                            Symbols.drag_indicator_rounded,
                            color: scheme.outline,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(tile.icon, color: scheme.outline),
                      ],
                    ),
                    title: Text(
                      tile.title(l10n),
                      style: on ? null : TextStyle(color: scheme.outline),
                    ),
                    subtitle: Text(tile.subtitle(l10n)),
                    value: on,
                    onChanged: (v) {
                      final set = enabled.toSet();
                      v ? set.add(tile) : set.remove(tile);
                      // Newly enabled tiles land after the enabled ones.
                      persist(all, set);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
