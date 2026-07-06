import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart';

import '../data/db/database.dart';
import '../data/repositories/view_repository.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'create_task_sheet.dart';
import 'settings_screen.dart';
import 'task_tile.dart';
import 'vacation_screen.dart';

/// The home surface (Phase 4): a tab per View, each View rendered through the
/// View → Lens → `derive` pipeline. Reconciles + seeds defaults on launch/resume.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _selectedView = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _startup();
  }

  Future<void> _startup() async {
    final now = ref.read(clockProvider).now();
    await ref.read(viewRepositoryProvider).seedDefaults();
    await ref.read(taskRepositoryProvider).reconcileAll(now);
    await ref.read(viewRepositoryProvider).refreshSurfaced(now);
  }

  Future<void> _newView() async {
    final name = await _promptName(
      context,
      AppLocalizations.of(context).newView,
    );
    if (name != null) await ref.read(viewRepositoryProvider).createView(name);
  }

  Future<void> _newLens(int viewId) async {
    final name = await _promptName(
      context,
      AppLocalizations.of(context).newLens,
    );
    if (name != null) {
      await ref.read(viewRepositoryProvider).createLensInView(viewId, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final views = ref.watch(viewsProvider);
    // Activate the reminder sync (Phase 5): the provider listens to the task
    // stream and re-fills the OS schedule on every change.
    ref.watch(notificationSyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          views.maybeWhen(
            data: (vs) => PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (v == 'view') _newView();
                if (v == 'lens' && vs.isNotEmpty) {
                  _newLens(vs[_selectedView.clamp(0, vs.length - 1)].id);
                }
                if (v == 'vacation') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VacationScreen()),
                  );
                }
                if (v == 'settings') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'view', child: Text(l10n.newView)),
                PopupMenuItem(value: 'lens', child: Text(l10n.newLensHere)),
                PopupMenuItem(value: 'vacation', child: Text(l10n.vacation)),
                PopupMenuItem(value: 'settings', child: Text(l10n.settings)),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: views.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.somethingWentWrong)),
        data: (vs) {
          if (vs.isEmpty) {
            return const Center(child: CircularProgressIndicator()); // seeding
          }
          final idx = _selectedView.clamp(0, vs.length - 1);
          return Column(
            children: [
              if (vs.length > 1)
                _ViewTabs(
                  views: vs,
                  selected: idx,
                  onSelect: (i) => setState(() => _selectedView = i),
                ),
              Expanded(
                child: _ViewBody(viewId: vs[idx].id, l10n: l10n),
              ),
            ],
          );
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

class _ViewTabs extends StatelessWidget {
  const _ViewTabs({
    required this.views,
    required this.selected,
    required this.onSelect,
  });

  final List<ViewRow> views;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: views.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (_, i) {
          final on = i == selected;
          return InkWell(
            onTap: () => onSelect(i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    views[i].name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: on ? scheme.onSurface : scheme.outline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 3,
                    width: 22,
                    decoration: BoxDecoration(
                      color: on ? scheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ViewBody extends ConsumerWidget {
  const _ViewBody({required this.viewId, required this.l10n});

  final int viewId;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(viewStateProvider(viewId));
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.somethingWentWrong)),
      data: (vs) {
        if (vs == null || vs.sections.every((s) => s.shown.isEmpty)) {
          return _EmptyState(l10n: l10n);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [for (final s in vs.sections) _LensCard(section: s)],
        );
      },
    );
  }
}

class _LensCard extends StatelessWidget {
  const _LensCard({required this.section});

  final LensSection section;

  @override
  Widget build(BuildContext context) {
    if (section.shown.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    section.lens.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                      color: scheme.outline,
                    ),
                  ),
                  _Breakdown(
                    done: section.doneCount,
                    missed: section.missedCount,
                    left: section.openCount,
                  ),
                ],
              ),
            ),
            for (var i = 0; i < section.shown.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              TaskTile(
                task: section.shown[i],
                lens: section.domainLens,
                avoided: section.isAvoided(section.shown[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The text-breakdown header (DESIGN_SYSTEM §3.2): "1 done · 1 missed · 2 left",
/// zero parts omitted, the `missed` segment in taupe.
class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.done,
    required this.missed,
    required this.left,
  });

  final int done;
  final int missed;
  final int left;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final taupe = FuchsbauStatusColors.of(context).taupe;
    final base = TextStyle(
      fontSize: 12,
      color: scheme.outline,
      fontWeight: FontWeight.w600,
    );

    final parts = <TextSpan>[
      if (done > 0) TextSpan(text: l10n.countDone(done)),
      if (missed > 0)
        TextSpan(
          text: l10n.countMissed(missed),
          style: TextStyle(color: taupe),
        ),
      if (left > 0) TextSpan(text: l10n.countLeft(left)),
    ];
    if (parts.isEmpty) return Text(l10n.allDone, style: base);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0) const TextSpan(text: ' · '),
            parts[i],
          ],
        ],
      ),
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
            Icon(
              Icons.task_alt_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(l10n.emptyTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.emptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _promptName(BuildContext context, String title) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _NamePromptDialog(title: title),
  );
  return (name != null && name.isNotEmpty) ? name : null;
}

/// Owns its [TextEditingController] so it is disposed with the dialog's own
/// lifecycle — disposing right after `showDialog` resolves races the pop
/// transition, which may still be painting the field.
class _NamePromptDialog extends StatefulWidget {
  const _NamePromptDialog({required this.title});

  final String title;

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: l10n.nameLabel),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.create),
        ),
      ],
    );
  }
}
