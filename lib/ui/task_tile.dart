import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../domain/lens.dart';
import '../domain/task.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'task_detail_sheet.dart';
import 'when_label.dart';

/// A single Task row (DESIGN_SYSTEM §3.1): the state marker on the left (tap
/// the ring to complete), the name, and swipe actions — right-swipe **Done**,
/// left-swipe **Skip** (or **Pass** in a periodic lens). Terminal states render
/// with the locked §2 markers: filled emerald check (Done), neutral
/// remove-circle (Skipped), struck taupe name (Missed) — never as open rows.
/// An [avoided] series renders its active marker in soft amber (§8 avoidance
/// surfacing — information, never a forced action).
class TaskTile extends ConsumerWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.lens,
    this.avoided = false,
  });

  final Task task;

  /// The lens this row is shown through — enables the periodic-only Pass swipe.
  final Lens? lens;

  /// The series is past the consecutive-miss avoidance threshold.
  final bool avoided;

  /// Done, with an Undo snackbar — a mis-tap or mis-swipe shouldn't be
  /// permanent. The row leaves the list via the stream; Undo reopens it.
  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(taskRepositoryProvider)
        .completeTask(task, ref.read(clockProvider).now());
    _offerUndo(messenger, ref, l10n.markedDone(task.name), l10n.undo);
  }

  void _offerUndo(
    ScaffoldMessengerState messenger,
    WidgetRef ref,
    String text,
    String undoLabel,
  ) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: undoLabel,
          onPressed: () async {
            final fresh = await ref
                .read(taskRepositoryProvider)
                .taskById(task.id!);
            if (fresh != null) {
              await ref.read(taskRepositoryProvider).reopenTask(fresh);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final status = FuchsbauStatusColors.of(context);
    final now = ref.read(clockProvider).now();
    final phase = phaseOf(task, now);

    // §2 state markers. Emerald rides scheme.tertiary, indigo scheme.secondary.
    final (IconData icon, Color color, bool actionable) = switch (task.status) {
      TaskStatus.done => (Symbols.check_circle_rounded, scheme.tertiary, false),
      TaskStatus.skipped => (
        Symbols.remove_circle_outline_rounded,
        status.neutral,
        false,
      ),
      // A missed *habit* stays tappable: "I did it, forgot to log it" (§11
      // q7). One-offs are display-only — a hard deadline is irrevocable.
      TaskStatus.missed => (
        Symbols.radio_button_unchecked_rounded,
        status.taupe,
        canCorrectMiss(task),
      ),
      TaskStatus.open => switch (phase) {
        // Avoidance (§1 "soft amber — information, not a command"): the ring
        // changes colour, the action stays exactly the same.
        TaskPhase.active => (
          Symbols.radio_button_unchecked_rounded,
          avoided ? status.amber : scheme.primary,
          true,
        ),
        TaskPhase.pending => (Symbols.schedule_rounded, scheme.outline, false),
        TaskPhase.expired => (
          Symbols.radio_button_unchecked_rounded,
          status.taupe,
          false,
        ),
      },
    };

    final periodic = lens?.isPeriodic ?? false;

    final row = ListTile(
      minVerticalPadding: 14,
      onTap: () => showTaskDetailSheet(context, ref, task),
      leading: IconButton(
        iconSize: 26,
        tooltip: !actionable
            ? null
            : task.status == TaskStatus.missed
            ? l10n.markDoneAnyway
            : l10n.markDone,
        icon: Icon(icon, color: color),
        onPressed: !actionable
            ? null
            : task.status == TaskStatus.missed
            ? () => ref.read(taskRepositoryProvider).correctMissedTask(task)
            : () => _complete(context, ref),
      ),
      title: Text(
        task.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: task.status == TaskStatus.missed ? status.taupe : null,
          decoration: task.status == TaskStatus.missed
              ? TextDecoration.lineThrough
              : null,
          decorationColor: status.taupe,
        ),
      ),
      // Informative pills (§3.6): pending → when the window opens (muted);
      // active with a deadline → when it's due (amber). Anytime stays bare.
      trailing: switch (phase) {
        TaskPhase.pending when task.isOpen && task.start != null => _StatusPill(
          label: whenLabel(
            l10n,
            Localizations.localeOf(context).toString(),
            now,
            task.start!,
            isEnd: false,
          ),
          color: scheme.outline,
        ),
        TaskPhase.active when task.isOpen && task.end != null => _StatusPill(
          label: whenLabel(
            l10n,
            Localizations.localeOf(context).toString(),
            now,
            task.end!,
            isEnd: true,
          ),
          color: status.amber,
        ),
        _ => null,
      },
    );

    // Terminal rows are display-only — no swipe affordances.
    if (task.isTerminal) return row;

    return Dismissible(
      key: ValueKey('task-${task.id}'),
      // The reactive stream removes the row once it's no longer open, so we
      // don't let Dismissible animate it away itself (avoids a double-remove).
      confirmDismiss: (direction) async {
        final repo = ref.read(taskRepositoryProvider);
        final now = ref.read(clockProvider).now();
        if (direction == DismissDirection.startToEnd) {
          await _complete(context, ref);
        } else if (periodic && task.id != null && lens?.id != null) {
          await repo.passTask(task.id!, lens!.id!, now);
        } else {
          final messenger = ScaffoldMessenger.of(context);
          await repo.skipTask(task, now);
          _offerUndo(messenger, ref, l10n.markedSkipped(task.name), l10n.undo);
        }
        return false;
      },
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        icon: Symbols.check_circle_rounded,
        label: l10n.swipeDone,
        color: scheme.tertiary,
      ),
      secondaryBackground: periodic
          ? _SwipeBackground(
              alignment: Alignment.centerRight,
              icon: Symbols.arrow_forward_rounded,
              label: l10n.swipePass,
              color: scheme.secondary,
            )
          : _SwipeBackground(
              alignment: Alignment.centerRight,
              icon: Symbols.remove_circle_outline_rounded,
              label: l10n.swipeSkip,
              color: status.neutral,
            ),
      child: row,
    );
  }
}

/// Uppercase tinted status pill (DESIGN_SYSTEM §3.6).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: .5,
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.color,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: color.withValues(alpha: .18),
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
