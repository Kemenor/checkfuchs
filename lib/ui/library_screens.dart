import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../domain/lens.dart';
import '../domain/task.dart' as domain;
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'name_prompt_dialog.dart';
import 'recurrence_summary_l10n.dart';
import 'task_tile.dart';
import 'view_edit_screen.dart';
import 'view_icons.dart';

/// The Library (Settings): the unfiltered inventories behind the Views.
/// Lenses show what a View's dials choose to surface; these screens show
/// everything that exists — every task instance, every lens's raw pool,
/// every view.

final _lensTaskCountsProvider = StreamProvider.autoDispose<Map<int, int>>(
  (ref) => ref.watch(viewRepositoryProvider).watchLensTaskCounts(),
);

final _lensViewNamesProvider =
    StreamProvider.autoDispose<Map<int, List<String>>>(
      (ref) => ref.watch(viewRepositoryProvider).watchLensViewNames(),
    );

final _lensMembersProvider = StreamProvider.autoDispose
    .family<List<LensMember>, int>(
      (ref, lensId) =>
          ref.watch(viewRepositoryProvider).watchLensMembers(lensId),
    );

class AllTasksScreen extends ConsumerWidget {
  const AllTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tasks = ref.watch(tasksProvider).asData?.value;
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
    final members = ref.watch(_lensMembersProvider(lensId)).asData?.value;
    final lens = ref
        .watch(allLensesProvider)
        .asData
        ?.value
        .where((l) => l.id == lensId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: members == null
          ? const Center(child: CircularProgressIndicator())
          : _TaskSections(
              tasks: [for (final m in members) m.task],
              orderOf: {
                for (final m in members)
                  if (m.task.id != null) m.task.id!: m.order,
              },
              manualLensId: lens?.ordering == LensOrdering.manual
                  ? lensId
                  : null,
            ),
    );
  }
}

/// Open instances first (soonest window edge on top), then the resolved ones
/// (newest outcome on top). With [splitKinds] the open block differentiates
/// the one-off to-dos from the cyclical habit instances — and habit outcomes
/// are dropped from Resolved entirely (the habit already has its row above;
/// its history belongs to the lens drill-in). Resolved defaults to the last
/// 30 days with a load-all button, so the record doesn't scroll forever.
class _TaskSections extends ConsumerStatefulWidget {
  const _TaskSections({
    required this.tasks,
    this.splitKinds = false,
    this.orderOf = const {},
    this.manualLensId,
  });

  final List<domain.Task> tasks;
  final bool splitKinds;

  /// Membership order per task id (only meaningful for a manual lens).
  final Map<int, int> orderOf;

  /// When set, the Open block is a drag-to-reorder list writing this lens's
  /// membership order.
  final int? manualLensId;

  @override
  ConsumerState<_TaskSections> createState() => _TaskSectionsState();
}

class _TaskSectionsState extends ConsumerState<_TaskSections> {
  bool _allResolved = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tasks = widget.tasks;
    if (tasks.isEmpty) {
      return Center(child: Text(l10n.emptyTitle));
    }
    final far = DateTime(9999);
    int byEdge(domain.Task a, domain.Task b) =>
        (a.end ?? a.start ?? far).compareTo(b.end ?? b.start ?? far);
    final now = ref.read(clockProvider).now();
    final allOpen = tasks.where((t) => t.isOpen).toList();
    final upcoming =
        allOpen
            .where((t) => domain.phaseOf(t, now) == domain.TaskPhase.pending)
            .toList()
          ..sort(byEdge);
    final open =
        allOpen
            .where((t) => domain.phaseOf(t, now) != domain.TaskPhase.pending)
            .toList()
          ..sort(
            widget.manualLensId != null
                ? (a, b) => (widget.orderOf[a.id] ?? 0).compareTo(
                    widget.orderOf[b.id] ?? 0,
                  )
                : byEdge,
          );

    final allResolved =
        tasks
            .where(
              (t) =>
                  t.isTerminal && (!widget.splitKinds || t.templateId == null),
            )
            .toList()
          ..sort(
            (a, b) => (b.resolvedAt ?? DateTime(0)).compareTo(
              a.resolvedAt ?? DateTime(0),
            ),
          );
    final cutoff = ref
        .read(clockProvider)
        .now()
        .subtract(const Duration(days: 30));
    final resolved = _allResolved
        ? allResolved
        : allResolved
              .where((t) => t.resolvedAt?.isAfter(cutoff) ?? false)
              .toList();
    final olderCount = allResolved.length - resolved.length;

    Widget section(String header, List<domain.Task> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FuchsbauSectionHeader(header),
        FuchsbauSettingsCard(
          children: [for (final t in items) TaskTile(task: t)],
        ),
      ],
    );

    // Manual lens: the Open block reorders by drag; the handle is the only
    // drag start so the tile's own tap/swipe keep working.
    Widget manualSection(String header, List<domain.Task> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FuchsbauSectionHeader(header),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            l10n.reorderHint,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        FuchsbauSettingsCard(
          children: [
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorderItem: (from, to) {
                final ids = [for (final t in items) t.id!];
                final moved = ids.removeAt(from);
                ids.insert(to, moved);
                ref
                    .read(viewRepositoryProvider)
                    .setMemberOrder(widget.manualLensId!, ids);
              },
              itemBuilder: (context, i) => Row(
                key: ValueKey('manual-${items[i].id}'),
                children: [
                  Expanded(child: TaskTile(task: items[i])),
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Symbols.drag_indicator_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    final openBlocks = widget.splitKinds
        ? [
            (l10n.todosSection, open.where((t) => t.templateId == null)),
            (l10n.habitsSection, open.where((t) => t.templateId != null)),
          ]
        : [(l10n.openSection, open)];

    return ListView(
      padding: EdgeInsets.only(
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        for (final (header, items) in openBlocks)
          if (items.isNotEmpty)
            widget.manualLensId != null
                ? manualSection(header, items.toList())
                : section(header, items.toList()),
        if (upcoming.isNotEmpty) section(l10n.upcomingSection, upcoming),
        if (resolved.isNotEmpty) section(l10n.resolvedSection, resolved),
        if (olderCount > 0) ...[
          if (resolved.isEmpty) FuchsbauSectionHeader(l10n.resolvedSection),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _allResolved = true),
              child: Text(l10n.showAllResolved(allResolved.length)),
            ),
          ),
        ],
      ],
    );
  }
}

class AllLensesScreen extends ConsumerWidget {
  const AllLensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lenses = ref.watch(allLensesProvider).asData?.value;
    final counts = ref.watch(_lensTaskCountsProvider).asData?.value ?? {};
    final viewNames = ref.watch(_lensViewNamesProvider).asData?.value ?? {};
    return Scaffold(
      appBar: AppBar(title: Text(l10n.allLensesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'newLens',
        onPressed: () async {
          final r = await promptName(context, l10n.newLens);
          if (r == null || !context.mounted) return;
          final id = await ref.read(viewRepositoryProvider).createLens(r.$1);
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => LensEditScreen(lensId: id)),
          );
        },
        icon: const Icon(Symbols.add_rounded),
        label: Text(l10n.newLens),
      ),
      body: lenses == null
          ? const Center(child: CircularProgressIndicator())
          : lenses.isEmpty
          ? Center(child: Text(l10n.emptyTitle))
          : ListView(
              padding: EdgeInsets.only(
                top: 12,
                bottom: 96 + MediaQuery.paddingOf(context).bottom,
              ),
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
                        // The lens's own editor (dials, rename, delete); its
                        // task list is one row further in.
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LensEditScreen(lensId: lens.id),
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
              padding: EdgeInsets.only(
                top: 12,
                bottom: 12 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    l10n.reorderHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                // Drag = bottom-bar order.
                FuchsbauSettingsCard(
                  children: [
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: views.length,
                      onReorderItem: (from, to) {
                        final ids = [for (final v in views) v.id];
                        final moved = ids.removeAt(from);
                        ids.insert(to, moved);
                        ref.read(viewRepositoryProvider).setViewOrder(ids);
                      },
                      itemBuilder: (context, i) => ListTile(
                        key: ValueKey('view-${views[i].id}'),
                        contentPadding: fuchsbauCardRowPadding,
                        leading: Icon(viewIcon(views[i].icon)),
                        title: Text(views[i].name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Symbols.chevron_right_rounded),
                            const SizedBox(width: 8),
                            ReorderableDragStartListener(
                              index: i,
                              child: const Icon(Symbols.drag_indicator_rounded),
                            ),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ViewEditScreen(viewId: views[i].id),
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
