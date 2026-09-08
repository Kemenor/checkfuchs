import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart'
    show FuchsbauSettingsCard, fuchsbauCardRowPadding;
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/debug/demo_data.dart';
import '../l10n/app_localizations.dart';
import '../notifications/background_refresh.dart';
import '../providers.dart';
import 'first_launch.dart';

/// Hidden developer/tester section, unlocked by long-pressing the app name in
/// the About dialog (the knabberfuchs pattern). Deliberately English-only
/// (never store-advertised, DEBUG-labelled) — the one sanctioned exception to
/// the no-hardcoded-strings rule.
class DebugSection extends ConsumerWidget {
  const DebugSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'DEBUG',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
        ),
        FuchsbauSettingsCard(
          children: [
            ListTile(
              contentPadding: fuchsbauCardRowPadding,
              leading: const Icon(Symbols.science_rounded),
              title: const Text('Load demo suite'),
              subtitle: const Text(
                'Wipe everything, seed the full demo dataset',
              ),
              onTap: () => _loadDemoSuite(context, ref),
            ),
            ListTile(
              contentPadding: fuchsbauCardRowPadding,
              leading: const Icon(Symbols.sync_rounded),
              title: const Text('Reconcile now'),
              subtitle: const Text('Run the expiry sweep + generation'),
              onTap: () => _reconcile(context, ref),
            ),
            ListTile(
              contentPadding: fuchsbauCardRowPadding,
              leading: const Icon(Symbols.notifications_active_rounded),
              title: const Text('Pending notifications'),
              subtitle: const Text('What the OS has scheduled'),
              onTap: () => _showPending(context, ref),
            ),
            ListTile(
              contentPadding: fuchsbauCardRowPadding,
              leading: const Icon(Symbols.restart_alt_rounded),
              title: Text(
                'Reset to intro',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: const Text(
                'Factory reset: wipe everything, run first launch again',
              ),
              onTap: () => _resetToIntro(context, ref),
            ),
            ListTile(
              contentPadding: fuchsbauCardRowPadding,
              leading: const Icon(Symbols.visibility_off_rounded),
              title: const Text('Hide debug menu'),
              subtitle: const Text('Long-press the name in About to unhide'),
              onTap: () =>
                  ref.read(settingsProvider.notifier).toggleDebugMenu(),
            ),
            ListTile(
              contentPadding: fuchsbauCardRowPadding,
              leading: const Icon(Symbols.settings_backup_restore_rounded),
              title: const Text('Run background refresh'),
              subtitle: const Text('One-off WorkManager pass (bg isolate)'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                await runBackgroundRefreshOnce();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Background refresh enqueued — see logcat'),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Wipe + seed the full demo suite (localized content — the same dataset
  /// backs the store screenshots). Confirm first: it replaces everything.
  Future<void> _loadDemoSuite(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load demo suite?'),
        content: const Text(
          'This wipes all tasks, habits, views, lenses and vacations, then '
          'seeds the demo dataset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Load'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await loadDemoData(
      ref.read(databaseProvider),
      ref.read(clockProvider).now(),
      l10n,
    );
    messenger.showSnackBar(const SnackBar(content: Text('Demo suite loaded')));
  }

  /// Factory reset: wipe content, reseed the default View/Lens (the carrier
  /// sheet needs a lens to land in), clear the onboarding flag, and run the
  /// first-launch flow right away.
  Future<void> _resetToIntro(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to intro?'),
        content: const Text(
          'This wipes all tasks, habits, views, lenses and vacations, then '
          'shows the first-launch intro again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final db = ref.read(databaseProvider);
    final views = ref.read(viewRepositoryProvider);
    try {
      await db.transaction(() async {
        await wipeContent(db);
        await views.seedDefaultsUnwrapped(
          lensName: l10n.seedLensDefault,
          viewName: l10n.seedViewHome,
        );
      });
      await ref.read(settingsProvider.notifier).resetOnboarding();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Reset failed: $e')));
      return;
    }
    if (!context.mounted) return;
    await runFirstLaunch(context, ref);
  }

  Future<void> _reconcile(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final now = ref.read(clockProvider).now();
    await ref.read(taskRepositoryProvider).reconcileAll(now);
    await ref.read(viewRepositoryProvider).refreshSurfaced(now);
    messenger.showSnackBar(const SnackBar(content: Text('Reconciled')));
  }

  Future<void> _showPending(BuildContext context, WidgetRef ref) async {
    final pending = await ref.read(notificationSchedulerProvider).pending();
    if (!context.mounted) return;
    final fmt = DateFormat('EEE d MMM HH:mm');
    // The plugin doesn't expose fire times back; show id + title, and the
    // count — timing lives in `adb shell dumpsys alarm` when needed.
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Pending: ${pending.length}  (${fmt.format(DateTime.now())})',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: pending.isEmpty
              ? const Text('Nothing scheduled.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in pending)
                      ListTile(
                        dense: true,
                        title: Text(p.title ?? '(no title)'),
                        subtitle: Text('id ${p.id}'),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
