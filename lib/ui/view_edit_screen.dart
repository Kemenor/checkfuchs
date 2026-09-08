import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/db/database.dart';
import '../data/repositories/view_repository.dart';
import '../domain/lens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'library_screens.dart';
import 'name_prompt_dialog.dart';
import 'recurrence_editor.dart';
import 'recurrence_summary_l10n.dart';
import 'view_icons.dart';

/// The statusFilter bitmask (view_lens.status_filter, concept §4.6).
const _showDone = 1, _showSkipped = 2, _showMissed = 4;

final _viewRowProvider = StreamProvider.autoDispose.family<ViewRow?, int>(
  (ref, viewId) => ref.watch(viewRepositoryProvider).watchView(viewId),
);

final _viewLensesProvider = StreamProvider.autoDispose
    .family<List<ViewLensEntry>, int>(
      (ref, viewId) =>
          ref.watch(viewRepositoryProvider).watchViewLenses(viewId),
    );

/// Edit a View and the dials of its lenses (PLAN Phase 4, deferred UI):
/// rename/re-icon/delete the View, and per lens the full dial set —
/// `showCount`, `ordering`, `selection`, `period` (Off = continuous),
/// `dormantAfter`, plus the View↔Lens `statusFilter` chips. Settings-card
/// anatomy (DESIGN_SYSTEM: uppercase section headers + cards), live-updating
/// from the repository streams.
class ViewEditScreen extends ConsumerWidget {
  const ViewEditScreen({super.key, required this.viewId});

  final int viewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(_viewRowProvider(viewId)).asData?.value;
    final lenses = ref.watch(_viewLensesProvider(viewId)).asData?.value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editThisView)),
      body: (view == null || lenses == null)
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.only(
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                FuchsbauSectionHeader(l10n.viewSection),
                FuchsbauSettingsCard(
                  children: [
                    ListTile(
                      contentPadding: fuchsbauCardRowPadding,
                      leading: Icon(viewIcon(view.icon)),
                      title: Text(view.name),
                      trailing: const Icon(Symbols.edit_rounded),
                      onTap: () => _renameView(context, ref, view),
                    ),
                    _DeleteTile(
                      title: l10n.deleteView,
                      body: l10n.confirmDeleteViewBody,
                      onConfirmed: () async {
                        await ref
                            .read(viewRepositoryProvider)
                            .deleteView(viewId);
                        // Back to the shell — the bar clamps its index itself.
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                FuchsbauSectionHeader(l10n.lensesSection),
                for (final entry in lenses)
                  _LensDialsCard(
                    key: ValueKey(entry.lens.id),
                    viewId: viewId,
                    entry: entry,
                  ),
              ],
            ),
    );
  }

  Future<void> _renameView(
    BuildContext context,
    WidgetRef ref,
    ViewRow view,
  ) async {
    final r = await promptName(
      context,
      AppLocalizations.of(context).renameView,
      withIcon: true,
      initialName: view.name,
      initialIcon: view.icon,
    );
    if (r == null) return;
    final repo = ref.read(viewRepositoryProvider);
    await repo.renameView(view.id, r.$1);
    await repo.setViewIcon(view.id, r.$2);
  }
}

/// One lens's dials standalone — pushed right after "New lens here" (with a
/// [viewId], so the View↔Lens statusFilter chips are offered too) and from
/// Settings → Library → All lenses (no view: the lens's own dials only).
/// Pops itself if the lens is deleted.
class LensEditScreen extends ConsumerWidget {
  const LensEditScreen({super.key, this.viewId, required this.lensId});

  final int? viewId;
  final int lensId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final viewId = this.viewId;
    final ViewLensEntry? entry;
    if (viewId != null) {
      ref.listen(_viewLensesProvider(viewId), (_, next) {
        final entries = next.asData?.value;
        if (entries != null && entries.every((e) => e.lens.id != lensId)) {
          Navigator.of(context).maybePop();
        }
      });
      final entries = ref.watch(_viewLensesProvider(viewId)).asData?.value;
      entry = entries?.where((e) => e.lens.id == lensId).firstOrNull;
    } else {
      ref.listen(allLensesProvider, (_, next) {
        final lenses = next.asData?.value;
        if (lenses != null && lenses.every((l) => l.id != lensId)) {
          Navigator.of(context).maybePop();
        }
      });
      final lens = ref
          .watch(allLensesProvider)
          .asData
          ?.value
          .where((l) => l.id == lensId)
          .firstOrNull;
      entry = lens == null ? null : ViewLensEntry(lens: lens, statusFilter: 0);
    }
    return Scaffold(
      appBar: AppBar(title: Text(entry?.lens.name ?? '')),
      body: entry == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.only(
                top: 12,
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                if (viewId == null)
                  FuchsbauSettingsCard(
                    children: [
                      ListTile(
                        contentPadding: fuchsbauCardRowPadding,
                        leading: const Icon(Symbols.checklist_rounded),
                        title: Text(l10n.allTasksTitle),
                        trailing: const Icon(Symbols.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LensTasksScreen(
                              lensId: lensId,
                              name: entry!.lens.name,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                _LensDialsCard(
                  key: ValueKey(entry.lens.id),
                  viewId: viewId,
                  entry: entry,
                ),
              ],
            ),
    );
  }
}

/// One lens's full dial set as a settings card: name header (tap = rename),
/// the pickers, the period editor, the statusFilter chips (only when opened
/// for a specific view — the filter is a View↔Lens property), and delete.
class _LensDialsCard extends ConsumerWidget {
  const _LensDialsCard({super.key, required this.viewId, required this.entry});

  final int? viewId;
  final ViewLensEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lens = entry.lens;
    final repo = ref.read(viewRepositoryProvider);
    final viewId = this.viewId;

    // Offer -1 (all) and 1..5 — plus the stored value if it's ever outside
    // that range, so the picker never lies about the current state.
    final showCountOptions = <int, String>{
      Lens.showAll: l10n.showCountAll,
      for (var n = 1; n <= 5; n++) n: '$n',
    };
    showCountOptions.putIfAbsent(lens.showCount, () => '${lens.showCount}');

    final dormantValue = lens.dormantAfter ?? 0;
    final dormantOptions = <int, String>{
      0: l10n.dormantOff,
      for (final n in const [2, 3, 5]) n: l10n.dormantPeriods(n),
    };
    dormantOptions.putIfAbsent(
      dormantValue,
      () => l10n.dormantPeriods(dormantValue),
    );

    return FuchsbauSettingsCard(
      children: [
        ListTile(
          key: ValueKey('lens-name-${lens.id}'),
          contentPadding: fuchsbauCardRowPadding,
          leading: const Icon(Symbols.filter_alt_rounded),
          title: Text(lens.name),
          trailing: const Icon(Symbols.edit_rounded),
          onTap: () => _renameLens(context, ref, lens),
        ),
        FuchsbauChoicePicker<int>(
          key: ValueKey('show-count-${lens.id}'),
          icon: Symbols.format_list_numbered_rounded,
          title: l10n.showCountDial,
          value: lens.showCount,
          options: showCountOptions,
          onChanged: (v) => repo.updateLensDials(lens.id, showCount: v),
        ),
        FuchsbauChoicePicker<LensOrdering>(
          key: ValueKey('ordering-${lens.id}'),
          icon: Symbols.swap_vert_rounded,
          title: l10n.orderingDial,
          value: lens.ordering,
          options: {
            LensOrdering.automatic: l10n.orderingAutomatic,
            LensOrdering.dueDate: l10n.orderingDueDate,
            LensOrdering.manual: l10n.orderingManual,
          },
          onChanged: (v) => repo.updateLensDials(lens.id, ordering: v),
        ),
        // Which members fill the slots — only meaningful with a slot limit.
        if (lens.showCount != Lens.showAll)
          FuchsbauChoicePicker<LensSelection>(
            key: ValueKey('selection-${lens.id}'),
            icon: Symbols.casino_rounded,
            title: l10n.selectionDial,
            value: lens.selection,
            options: {
              LensSelection.top: l10n.selectionTop,
              LensSelection.random: l10n.selectionRandom,
            },
            onChanged: (v) => repo.updateLensDials(lens.id, selection: v),
          ),
        _PeriodTile(key: ValueKey('period-${lens.id}'), lens: lens),
        // Dormancy only exists on periodic lenses (concept §4.3).
        if (lens.period != null)
          FuchsbauChoicePicker<int>(
            key: ValueKey('dormant-${lens.id}'),
            icon: Symbols.bedtime_rounded,
            title: l10n.dormantDial,
            value: dormantValue,
            options: dormantOptions,
            onChanged: (v) => repo.updateLensDials(
              lens.id,
              dormantAfter: Value(v == 0 ? null : v),
            ),
          ),
        if (viewId != null)
          _StatusFilterRow(
            key: ValueKey('status-filter-${lens.id}'),
            filter: entry.statusFilter,
            onChanged: (f) => repo.setStatusFilter(viewId, lens.id, f),
          ),
        _DeleteTile(
          key: ValueKey('delete-lens-${lens.id}'),
          title: l10n.deleteLens,
          body: l10n.confirmDeleteLensBody,
          onConfirmed: () => repo.deleteLens(lens.id),
        ),
      ],
    );
  }

  Future<void> _renameLens(
    BuildContext context,
    WidgetRef ref,
    LensRow lens,
  ) async {
    final r = await promptName(
      context,
      AppLocalizations.of(context).renameLens,
      initialName: lens.name,
    );
    if (r != null) {
      await ref.read(viewRepositoryProvider).renameLens(lens.id, r.$1);
    }
  }
}

/// The `period` dial: an expandable row hosting the shared [RecurrenceEditor]
/// (Off = continuous, matching design §4.3 — the same primitive as task
/// recurrence). Every editor change writes through immediately.
class _PeriodTile extends ConsumerWidget {
  const _PeriodTile({super.key, required this.lens});

  final LensRow lens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    return ExpansionTile(
      leading: const Icon(Symbols.event_repeat_rounded),
      title: Text(l10n.periodDial),
      subtitle: Text(
        lens.period == null
            ? l10n.periodContinuous
            : localizedRecurrenceSummary(context, lens.period),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: RecurrenceEditor(
            key: ValueKey('period-editor-${lens.id}'),
            anchor: lens.period?.anchor ?? today,
            initial: lens.period,
            onChanged: (r) => ref
                .read(viewRepositoryProvider)
                .updateLensDials(lens.id, period: Value(r)),
          ),
        ),
      ],
    );
  }
}

/// The View↔Lens statusFilter: which terminal states ride along with the
/// always-shown open tasks (default open-only). Three chips, one bit each.
class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final int filter;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    Widget chip(String label, int bit) => FilterChip(
      label: Text(label),
      selected: filter & bit != 0,
      onSelected: (on) => onChanged(on ? filter | bit : filter & ~bit),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.statusFilterLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              chip(l10n.filterShowDone, _showDone),
              chip(l10n.filterShowSkipped, _showSkipped),
              chip(l10n.filterShowMissed, _showMissed),
            ],
          ),
        ],
      ),
    );
  }
}

/// A delete row in the sanctioned `error` red, gated by a confirm dialog.
class _DeleteTile extends StatelessWidget {
  const _DeleteTile({
    super.key,
    required this.title,
    required this.body,
    required this.onConfirmed,
  });

  final String title;
  final String body;
  final Future<void> Function() onConfirmed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: fuchsbauCardRowPadding,
      leading: Icon(Symbols.delete_outline_rounded, color: scheme.error),
      title: Text(title, style: TextStyle(color: scheme.error)),
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          ),
        );
        if (confirmed == true) await onConfirmed();
      },
    );
  }
}
