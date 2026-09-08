import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../domain/task.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';

/// A habit's past: every generated occurrence, newest first, with its
/// outcome — and the corrections the model allows per row: a done/skipped
/// one can be reopened, a missed one marked done after the fact (§11 q7).
/// Reached from the detail sheet's History row or a long-press on the tile.
class TaskHistoryScreen extends ConsumerWidget {
  const TaskHistoryScreen({
    super.key,
    required this.templateId,
    required this.name,
  });

  final int templateId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final status = FuchsbauStatusColors.of(context);
    final locale = Localizations.localeOf(context).toString();
    final all = ref.watch(tasksProvider).asData?.value;
    final rows = all == null
        ? null
        : ([
            for (final t in all)
              if (t.templateId == templateId) t,
          ]..sort((a, b) {
            final ka = a.occurrence ?? a.start ?? a.createdAt;
            final kb = b.occurrence ?? b.start ?? b.createdAt;
            return kb.compareTo(ka);
          }));

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: rows == null
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
          ? Center(child: Text(l10n.historyEmpty))
          : ListView(
              padding: EdgeInsets.only(
                top: 12,
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                FuchsbauSettingsCard(
                  children: [
                    for (final t in rows)
                      ListTile(
                        contentPadding: fuchsbauCardRowPadding,
                        leading: switch (t.status) {
                          TaskStatus.done => Icon(
                            Symbols.check_circle_rounded,
                            color: scheme.tertiary,
                          ),
                          TaskStatus.skipped => Icon(
                            Symbols.remove_circle_outline_rounded,
                            color: status.neutral,
                          ),
                          TaskStatus.missed => Icon(
                            Symbols.radio_button_unchecked_rounded,
                            color: status.taupe,
                          ),
                          TaskStatus.open => Icon(
                            Symbols.radio_button_unchecked_rounded,
                            color: scheme.primary,
                          ),
                        },
                        title: Text(
                          DateFormat.yMMMEd(
                            locale,
                          ).format(t.occurrence ?? t.start ?? t.createdAt),
                        ),
                        subtitle: Text(switch (t.status) {
                          TaskStatus.done => l10n.statsLegendDone,
                          TaskStatus.skipped => l10n.statsLegendSkipped,
                          TaskStatus.missed => l10n.statsLegendMissed,
                          TaskStatus.open => l10n.statsLegendOpen,
                        }),
                        trailing: canReopen(t)
                            ? IconButton(
                                tooltip: l10n.reopenTask,
                                icon: const Icon(Symbols.undo_rounded),
                                onPressed: () => ref
                                    .read(taskRepositoryProvider)
                                    .reopenTask(t),
                              )
                            : canCorrectMiss(t)
                            ? IconButton(
                                tooltip: l10n.markDoneAnyway,
                                icon: const Icon(Symbols.check_circle_rounded),
                                onPressed: () => ref
                                    .read(taskRepositoryProvider)
                                    .correctMissedTask(t),
                              )
                            : null,
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
