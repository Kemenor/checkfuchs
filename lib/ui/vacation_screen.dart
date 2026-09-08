import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';

/// Vacation periods (design-concept §6) — schedule time away in advance.
/// Pauses recurring generation while active; hard deadlines still pass.
class VacationScreen extends ConsumerWidget {
  const VacationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vacations = ref.watch(vacationsProvider);
    final fmt = DateFormat.MMMd(Localizations.localeOf(context).toString());

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vacation)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.vacationIntro,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(
            child: vacations.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(l10n.somethingWentWrong)),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noVacations,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.only(
                        bottom: 96 + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        for (final v in list)
                          ListTile(
                            leading: const Icon(Symbols.beach_access_rounded),
                            title: Text(
                              '${fmt.format(v.start)} – ${fmt.format(v.end)}',
                            ),
                            trailing: IconButton(
                              tooltip: l10n.delete,
                              icon: Icon(
                                Symbols.delete_outline_rounded,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(l10n.deleteVacationTitle),
                                    content: Text(
                                      '${fmt.format(v.start)} – ${fmt.format(v.end)}',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text(l10n.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text(l10n.delete),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok != true) return;
                                await ref
                                    .read(taskRepositoryProvider)
                                    .deleteVacation(v.id);
                                await ref
                                    .read(taskRepositoryProvider)
                                    .reconcileAll(
                                      ref.read(clockProvider).now(),
                                    );
                              },
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addVacation',
        onPressed: () => _add(context, ref),
        icon: const Icon(Symbols.add_rounded),
        label: Text(l10n.addTask),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final now = ref.read(clockProvider).now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (range == null) return;
    final repo = ref.read(taskRepositoryProvider);
    await repo.addVacation(
      DateTime(range.start.year, range.start.month, range.start.day),
      DateTime(range.end.year, range.end.month, range.end.day, 23, 59),
    );
    await repo.reconcileAll(ref.read(clockProvider).now());
  }
}
