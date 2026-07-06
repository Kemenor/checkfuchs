import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/db/database.dart';
import '../domain/task.dart' as domain;
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'recurrence_summary_l10n.dart';
import 'task_tile.dart';
import 'view_edit_screen.dart';
import 'view_icons.dart';

/// The Library (Settings): the unfiltered inventories behind the Views.
/// Lenses show what a View's dials choose to surface; these screens show
/// everything that exists — every task instance, every lens's raw pool,
/// every view.

final _allTasksProvider = StreamProvider.autoDispose<List<domain.Task>>(
  (ref) => ref.watch(taskRepositoryProvider).watchTasks(),
);

final _allLensesProvider = StreamProvider.autoDispose<List<LensRow>>(
  (ref) => ref.watch(viewRepositoryProvider).watchAllLenses(),
);

final _lensTaskCountsProvider = StreamProvider.autoDispose<Map<int, int>>(
  (ref) => ref.watch(viewRepositoryProvider).watchLensTaskCounts(),
);

final _lensViewNamesProvider =
    StreamProvider.autoDispose<Map<int, List<String>>>(
      (ref) => ref.watch(viewRepositoryProvider).watchLensViewNames(),
    );

final _lensTasksProvider = StreamProvider.autoDispose
    .family<List<domain.Task>, int>(
      (ref, lensId) => ref.watch(viewRepositoryProvider).watchLensTasks(lensId),
    );

class AllTasksScreen extends ConsumerWidget {
  const AllTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tasks = ref.watch(_allTasksProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.allTasksTitle)),
      body: tasks == null
          ? const Center(child: CircularProgressIndicator())
          : _TaskSections(tasks: tasks, splitKinds: true),
    );
  }
}

class LensTasksScreen extends ConsumerWidget {
  const LensTasksScreen({super.key, required this.lensId, required this.name});

  final int lensId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(_lensTasksProvider(lensId)).asData?.value;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: tasks == null
          ? const Center(child: CircularProgressIndicator())
          : _TaskSections(tasks: tasks),
    );
  }
}

/// Open instances first (soonest window edge on top), then the resolved ones
/// (newest outcome on top) — the full record, not just the current slice.
/// With [splitKinds] the open block differentiates the cyclical instances
/// (template-born habits) from the one-off to-dos.
class _TaskSections extends StatelessWidget {
  const _TaskSections({required this.tasks, this.splitKinds = false});

  final List<domain.Task> tasks;
  final bool splitKinds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (tasks.isEmpty) {
      return Center(child: Text(l10n.emptyTitle));
    }
    final far = DateTime(9999);
    int byEdge(domain.Task a, domain.Task b) =>
        (a.end ?? a.start ?? far).compareTo(b.end ?? b.start ?? far);
    final open = tasks.where((t) => t.isOpen).toList()..sort(byEdge);
    final resolved = tasks.where((t) => t.isTerminal).toList()
      ..sort(
        (a, b) => (b.resolvedAt ?? DateTime(0)).compareTo(
          a.resolvedAt ?? DateTime(0),
        ),
      );

    Widget section(String header, List<domain.Task> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FuchsbauSectionHeader(header),
        FuchsbauSettingsCard(
          children: [for (final t in items) TaskTile(task: t)],
        ),
      ],
    );

    final openBlocks = splitKinds
        ? [
            (l10n.habitsSection, open.where((t) => t.templateId != null)),
            (l10n.todosSection, open.where((t) => t.templateId == null)),
          ]
        : [(l10n.openSection, open)];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final (header, items) in openBlocks)
          if (items.isNotEmpty) section(header, items.toList()),
        if (resolved.isNotEmpty) section(l10n.resolvedSection, resolved),
      ],
    );
  }
}

class AllLensesScreen extends ConsumerWidget {
  const AllLensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lenses = ref.watch(_allLensesProvider).asData?.value;
    final counts = ref.watch(_lensTaskCountsProvider).asData?.value ?? {};
    final viewNames = ref.watch(_lensViewNamesProvider).asData?.value ?? {};
    return Scaffold(
      appBar: AppBar(title: Text(l10n.allLensesTitle)),
      body: lenses == null
          ? const Center(child: CircularProgressIndicator())
          : lenses.isEmpty
          ? Center(child: Text(l10n.emptyTitle))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                FuchsbauSettingsCard(
                  children: [
                    for (final lens in lenses)
                      ListTile(
                        contentPadding: fuchsbauCardRowPadding,
                        isThreeLine: true,
                        leading: const Icon(Symbols.filter_alt_rounded),
                        title: Text(lens.name),
                        subtitle: Text(
                          '${l10n.taskCount(counts[lens.id] ?? 0)} · '
                          '${lens.period == null ? l10n.periodContinuous : localizedRecurrenceSummary(context, lens.period)}\n'
                          '${switch (viewNames[lens.id]) {
                            null || [] => l10n.lensNoView,
                            final names => l10n.lensInViews(names.join(', ')),
                          }}',
                        ),
                        trailing: const Icon(Symbols.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LensTasksScreen(
                              lensId: lens.id,
                              name: lens.name,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class AllViewsScreen extends ConsumerWidget {
  const AllViewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final views = ref.watch(viewsProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.allViewsTitle)),
      body: views == null
          ? const Center(child: CircularProgressIndicator())
          : views.isEmpty
          ? Center(child: Text(l10n.emptyTitle))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                FuchsbauSettingsCard(
                  children: [
                    for (final v in views)
                      ListTile(
                        contentPadding: fuchsbauCardRowPadding,
                        leading: Icon(viewIcon(v.icon)),
                        title: Text(v.name),
                        trailing: const Icon(Symbols.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ViewEditScreen(viewId: v.id),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
