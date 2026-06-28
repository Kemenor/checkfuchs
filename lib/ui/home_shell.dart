import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/task.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'create_task_sheet.dart';
import 'task_tile.dart';

/// The Today surface (Phase 2 carrier MVP): one continuous "everything" lens of
/// the open Tasks. Reconciles on launch + resume so misses back-fill and the
/// current instances appear. Views, multiple lenses, and the full design come
/// in later phases.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reconcile());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reconcile();
  }

  Future<void> _reconcile() => ref
      .read(taskRepositoryProvider)
      .reconcileAll(ref.read(clockProvider).now());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tasks = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final open = all.where((t) => t.isOpen).toList();
          return open.isEmpty
              ? _EmptyState(l10n: l10n)
              : _TodayLens(open: open);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'homeAdd',
        onPressed: () => showCreateTaskSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.addTask),
      ),
    );
  }
}

class _TodayLens extends StatelessWidget {
  const _TodayLens({required this.open});

  final List<Task> open;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Text(
            '${open.length} to do',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5,
                ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < open.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                TaskTile(task: open[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt_rounded,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(l10n.emptyTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.emptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
