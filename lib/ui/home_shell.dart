import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/db/database.dart';
import '../data/repositories/view_repository.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'create_task_sheet.dart';
import 'name_prompt_dialog.dart';
import 'first_launch.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'task_tile.dart';
import 'view_edit_screen.dart';
import 'view_icons.dart';

/// The home surface (Phase 4): a bottom navigation bar destination per View
/// (DESIGN_SYSTEM §3.3 — the Fuchsbau family pattern, thumb-reachable), each
/// View rendered through the View → Lens → `derive` pipeline. Reconciles +
/// seeds defaults on launch/resume.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _selectedView = 0;
  bool _onSettings = false;

  /// The Stats tab (Settings → Stats tab, default on) is selected.
  bool _onStats = false;

  /// First-run onboarding considered this session (also on resume-startups),
  /// so the check runs at most once per app run.
  bool _onboardingChecked = false;

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
    final l10n = AppLocalizations.of(context);
    await ref
        .read(viewRepositoryProvider)
        .seedDefaults(
          lensName: l10n.seedLensDefault,
          viewName: l10n.seedViewHome,
        );
    await ref
        .read(notificationSchedulerProvider)
        .localize(
          name: l10n.notificationChannelName,
          description: l10n.notificationChannelDescription,
        );
    await ref.read(taskRepositoryProvider).reconcileAll(now);
    await ref.read(viewRepositoryProvider).refreshSurfaced(now);
    await _maybeShowOnboarding();
  }

  /// First run only (PLAN Phase 8): when the database has never held a
  /// template or a task, offer to seed the carrier — the first daily habit.
  /// The stored flag is stamped on *showing*, so a dismissal never re-nags;
  /// [_onboardingChecked] keeps resume-startups from re-checking in-session.
  /// Runs after the first frame ([_startup] is post-frame), so a Navigator is
  /// up when the sheet shows.
  Future<void> _maybeShowOnboarding() async {
    if (_onboardingChecked) return;
    _onboardingChecked = true;

    // Read the row directly — the settings controller's async load may not
    // have landed yet during startup.
    final db = ref.read(databaseProvider);
    final row = await db.select(db.appSettings).getSingleOrNull();
    if (row?.onboardingDone ?? false) return;
    final anyTemplate = await (db.select(db.templates)..limit(1)).get();
    final anyTask = await (db.select(db.tasks)..limit(1)).get();
    if (anyTemplate.isNotEmpty || anyTask.isNotEmpty) return;

    if (!mounted) return;
    // Three ideas first (Task → Lens → View), then a clean start or the
    // example dataset.
    await runFirstLaunch(context, ref);
  }

  Future<void> _newView() async {
    final r = await promptName(
      context,
      AppLocalizations.of(context).newView,
      withIcon: true,
    );
    if (r != null) {
      await ref.read(viewRepositoryProvider).createView(r.$1, icon: r.$2);
    }
  }

  /// Name, then straight into the dials — creating a lens should end with a
  /// shaped lens, not a name and a scavenger hunt through Edit this view.
  Future<void> _newLens(int viewId) async {
    final r = await promptName(context, AppLocalizations.of(context).newLens);
    if (r == null) return;
    final lensId = await ref
        .read(viewRepositoryProvider)
        .createLensInView(viewId, r.$1);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LensEditScreen(viewId: viewId, lensId: lensId),
      ),
    );
  }

  /// The bar: the user's Views (up to 4; beyond that the fourth slot becomes
  /// "More", a sheet with the rest) plus the fixed **Settings** destination —
  /// the knabberfuchs family layout (DESIGN_SYSTEM §3.3).
  Widget? _navBar(List<ViewRow> vs, AppLocalizations l10n, bool statsTab) {
    if (vs.isEmpty) return null; // still seeding
    const maxViewSlots = 4;
    final overflow = vs.length > maxViewSlots;
    final shown = overflow ? vs.sublist(0, maxViewSlots - 1) : vs;
    final statsIndex = shown.length + (overflow ? 1 : 0);
    final settingsIndex = statsIndex + (statsTab ? 1 : 0);
    final idx = _selectedView.clamp(0, vs.length - 1);
    return NavigationBar(
      selectedIndex: _onSettings
          ? settingsIndex
          : (statsTab && _onStats)
          ? statsIndex
          : (idx >= shown.length ? shown.length : idx),
      onDestinationSelected: (i) {
        if (i == settingsIndex) {
          setState(() {
            _onSettings = true;
            _onStats = false;
          });
        } else if (statsTab && i == statsIndex) {
          setState(() {
            _onStats = true;
            _onSettings = false;
          });
        } else if (overflow && i == shown.length) {
          _showMoreViews(vs.sublist(shown.length), shown.length);
        } else {
          setState(() {
            _onSettings = false;
            _onStats = false;
            _selectedView = i;
          });
        }
      },
      // Five destinations leave ~72dp per label: shrink the type a notch so
      // a long view name ("Gewohnheiten") ellipsizes instead of wrapping.
      labelTextStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.labelMedium?.copyWith(
          fontSize: shown.length + (overflow ? 1 : 0) + (statsTab ? 1 : 0) >= 4
              ? 11
              : null,
        ),
      ),
      destinations: [
        for (final v in shown)
          NavigationDestination(
            icon: Icon(viewIcon(v.icon)),
            selectedIcon: Icon(viewIcon(v.icon), fill: 1),
            label: v.name,
          ),
        if (overflow)
          NavigationDestination(
            icon: const Icon(Symbols.more_horiz_rounded),
            label: l10n.moreLabel,
          ),
        if (statsTab)
          NavigationDestination(
            icon: const Icon(Symbols.insights_rounded),
            selectedIcon: const Icon(Symbols.insights_rounded, fill: 1),
            label: l10n.statsTitle,
          ),
        NavigationDestination(
          icon: const Icon(Symbols.settings_rounded),
          selectedIcon: const Icon(Symbols.settings_rounded, fill: 1),
          label: l10n.settings,
        ),
      ],
    );
  }

  /// The small secondary FAB's sheet (knabberfuchs pattern): the structure
  /// actions — new view/lens and this view's dial-editing — behind one
  /// affordance.
  void _showStructureSheet(int currentViewId) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.dashboard_customize_rounded),
              title: Text(l10n.newView),
              onTap: () {
                Navigator.pop(ctx);
                _newView();
              },
            ),
            ListTile(
              leading: const Icon(Symbols.filter_alt_rounded),
              title: Text(l10n.newLensHere),
              onTap: () {
                Navigator.pop(ctx);
                _newLens(currentViewId);
              },
            ),
            ListTile(
              leading: const Icon(Symbols.tune_rounded),
              title: Text(l10n.editThisView),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ViewEditScreen(viewId: currentViewId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreViews(List<ViewRow> rest, int offset) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i < rest.length; i++)
              ListTile(
                leading: Icon(viewIcon(rest[i].icon)),
                title: Text(rest[i].name),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _onSettings = false;
                    _onStats = false;
                    _selectedView = offset + i;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  /// A View's page: its own app bar and the knabberfuchs FAB pair — the big
  /// `+ Add` (THE action, one tap) and the small structure-sheet FAB.
  Widget _tasksPage(int viewId, AppLocalizations l10n) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: _ViewBody(viewId: viewId, l10n: l10n),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'homeStructure',
            tooltip: l10n.structureTooltip,
            onPressed: () => _showStructureSheet(viewId),
            child: const Icon(Symbols.dashboard_customize_rounded),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'homeAdd',
            onPressed: () => showCreateTaskSheet(context, ref, viewId: viewId),
            icon: const Icon(Symbols.add_rounded),
            label: Text(l10n.addTask),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final views = ref.watch(viewsProvider);
    // Activate the reminder sync (Phase 5): the provider listens to the task
    // stream and re-fills the OS schedule on every change.
    ref.watch(notificationSyncProvider);
    final statsTab = ref.watch(settingsProvider.select((s) => s.statsTab));

    return Scaffold(
      body: _onSettings
          ? const SettingsScreen()
          : (statsTab && _onStats)
          ? const StatsScreen()
          : views.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(l10n.somethingWentWrong)),
              data: (vs) {
                if (vs.isEmpty) {
                  // Seeding the first view.
                  return const Center(child: CircularProgressIndicator());
                }
                final idx = _selectedView.clamp(0, vs.length - 1);
                return _tasksPage(vs[idx].id, l10n);
              },
            ),
      bottomNavigationBar: views.maybeWhen(
        data: (vs) => _navBar(vs, l10n, statsTab),
        orElse: () => null,
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
        // Every lens renders its card, even empty ones (a lens with nothing
        // to do earns its "well done", it doesn't vanish) — the guidance
        // empty-state only shows when the view has no lenses at all.
        if (vs == null || vs.sections.isEmpty) {
          return _EmptyState(l10n: l10n);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            for (final s in vs.sections)
              _LensCard(
                section: s,
                onAddTask: () => showCreateTaskSheet(
                  context,
                  ref,
                  viewId: viewId,
                  lensId: s.lens.id,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A lens card. The breakdown header counts every current outcome; when the
/// statusFilter keeps some of those rows out of the list, tapping the header
/// peeks at them (a transient expand — the persisted filter is untouched).
class _LensCard extends StatefulWidget {
  const _LensCard({required this.section, required this.onAddTask});

  final LensSection section;

  /// Opens the create sheet with this lens preselected (the header +).
  final VoidCallback onAddTask;

  @override
  State<_LensCard> createState() => _LensCardState();
}

class _LensCardState extends State<_LensCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final hidden = section.hiddenTerminals;
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final rows = [...section.shown, if (_expanded) ...hidden];
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
                children: [
                  Expanded(
                    child: Text(
                      section.lens.name.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .5,
                        color: scheme.outline,
                      ),
                    ),
                  ),
                  if (hidden.isEmpty)
                    _Breakdown(
                      done: section.doneCount,
                      missed: section.missedCount,
                      left: section.openCount,
                    )
                  else
                    Tooltip(
                      message: _expanded
                          ? l10n.hideOutcomes
                          : l10n.showOutcomes,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Breakdown(
                                done: section.doneCount,
                                missed: section.missedCount,
                                left: section.openCount,
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                _expanded
                                    ? Symbols.expand_less_rounded
                                    : Symbols.expand_more_rounded,
                                size: 16,
                                color: scheme.outline,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 20,
                    tooltip: l10n.addTask,
                    icon: Icon(Symbols.add_rounded, color: scheme.outline),
                    onPressed: widget.onAddTask,
                  ),
                ],
              ),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text(
                  l10n.emptyLensCard,
                  style: TextStyle(color: scheme.outline),
                ),
              ),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              TaskTile(
                task: rows[i],
                lens: section.domainLens,
                avoided: section.isAvoided(rows[i]),
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
              Symbols.task_alt_rounded,
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
