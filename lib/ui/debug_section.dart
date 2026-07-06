import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/notification.dart';
import '../domain/recurrence.dart';
import '../domain/task.dart';
import '../domain/template.dart';
import '../domain/window_rule.dart';
import '../providers.dart';
import 'settings_screen.dart' show SettingsCard, cardRowPadding;

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
        SettingsCard(
          children: [
            ListTile(
              contentPadding: cardRowPadding,
              leading: const Icon(Icons.science_outlined),
              title: const Text('Load test data'),
              subtitle: const Text('Seed demo habits + one-offs'),
              onTap: () => _seed(context, ref),
            ),
            ListTile(
              contentPadding: cardRowPadding,
              leading: const Icon(Icons.sync),
              title: const Text('Reconcile now'),
              subtitle: const Text('Run the expiry sweep + generation'),
              onTap: () => _reconcile(context, ref),
            ),
            ListTile(
              contentPadding: cardRowPadding,
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Pending notifications'),
              subtitle: const Text('What the OS has scheduled'),
              onTap: () => _showPending(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _seed(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(taskRepositoryProvider);
    final now = ref.read(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    await repo.createTemplate(
      Template(
        name: 'Brush teeth',
        recurrence: Recurrence.daily(today),
        windowRule: Slice.evening,
        createdAt: now,
        notifications: const [TaskNotification.atStart()],
      ),
    );
    await repo.createTemplate(
      Template(
        name: 'Water plants',
        recurrence: Recurrence.weekly(today, on: {Weekday.sat}),
        createdAt: now,
      ),
    );
    await repo.createTemplate(
      Template(
        name: 'Stretch',
        recurrence: Recurrence.daily(today),
        windowRule: Slice.morning,
        createdAt: now,
      ),
    );
    await repo.createTask(Task(name: 'Call the dentist', createdAt: now));
    await repo.reconcileAll(now);
    messenger.showSnackBar(
      const SnackBar(content: Text('Seeded 3 habits + 1 one-off')),
    );
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
