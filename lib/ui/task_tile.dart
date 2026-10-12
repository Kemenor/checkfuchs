import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../domain/lens.dart';
import '../domain/task.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'goal_ring.dart';
import 'task_detail_sheet.dart';
import 'task_history_screen.dart';
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

    // A counter (§3.7) wears the segmented ring while it is live or missed:
    // orange below min, emerald once met. Tapping it adds a check-in; on a
    // missed counter it opens the sheet, where a forgotten check-in gets its
    // time (a 1-of-1 miss keeps its one-tap correction).
    final counter = task.isCounter && (task.isOpen || task.isMissed);
    final ringColor = switch (phase) {
      _ when task.isMissed => status.taupe,
      TaskPhase.pending => scheme.outline,
      TaskPhase.expired => status.taupe,
      _ when task.isMet => scheme.tertiary,
      _ => avoided ? status.amber : scheme.primary,
    };
    final canTap = counter
        ? task.isMissed || canCheckIn(task, now)
        : actionable;
    final Widget marker = counter
        ? GoalRing(count: task.count, goal: task.goal, color: ringColor)
        : Icon(icon, color: color);

    final row = ListTile(
      minVerticalPadding: 14,
      onTap: () => showTaskDetailSheet(context, ref, task),
      // Long-press: straight to a habit's history (the detail sheet has the
      // same row; this is the shortcut).
      onLongPress: task.templateId == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TaskHistoryScreen(
                  templateId: task.templateId!,
                  name: task.name,
                ),
              ),
            ),
      leading: IconButton(
        iconSize: 26,
        tooltip: !canTap
            ? null
            : task.isMissed
            ? l10n.markDoneAnyway
            : counter
            ? l10n.checkIn
            : l10n.markDone,
        icon: marker,
        onPressed: !canTap
            ? null
            : counter && task.isMissed
            ? () => showTaskDetailSheet(context, ref, task)
            : task.isMissed
            ? () => ref.read(taskRepositoryProvider).correctMissedTask(task)
            : () => ref
                  .read(taskRepositoryProvider)
                  .checkInTask(task, ref.read(clockProvider).now()),
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
      subtitle: (task.note ?? '').isEmpty
          ? null
          : Text(
              task.note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.outline, fontSize: 13),
            ),
      // Informative pills (§3.6): pending → when the window opens (muted);
      // active with a deadline → when it's due (amber). Anytime stays bare.
      trailing: switch (phase) {
        // A live counter shows its progress instead of the deadline: "1 / 2"
        // orange, "2 / 2–3" emerald once met, "9 · no limit" past min.
        _ when counter && task.isOpen && phase != TaskPhase.pending =>
          _StatusPill(
            label: goalProgressLabel(l10n, task),
            color: task.isMet ? scheme.tertiary : scheme.primary,
          ),
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
        // Resolved rows: the day they belong to, tinted by outcome — a lens
        // drill-in lists a week of the same habit, and without this every
        // "Brush teeth" looks alike.
        _ when task.isTerminal => _StatusPill(
          label: DateFormat.MMMEd(
            Localizations.localeOf(context).toString(),
          ).format(task.occurrence ?? task.resolvedAt ?? task.createdAt),
          color: switch (task.status) {
            TaskStatus.done => scheme.tertiary,
            TaskStatus.skipped => status.neutral,
            _ => status.taupe,
          },
        ),
        _ => null,
      },
    );

    // Terminal rows are display-only — no swipe affordances.
    if (task.isTerminal) return row;

    // A counter only offers the swipes that would do something: +1 while
    // there's room, Skip only below min (a met cycle can't fail). Pass stays.
    final canStart = !task.isCounter || canCheckIn(task, now);
    final canEnd = periodic || !task.isCounter || canSkip(task, now);

    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: switch ((canStart, canEnd)) {
        (true, true) => DismissDirection.horizontal,
        (true, false) => DismissDirection.startToEnd,
        (false, true) => DismissDirection.endToStart,
        (false, false) => DismissDirection.none,
      },
      // The reactive stream removes the row once it's no longer open, so we
      // don't let Dismissible animate it away itself (avoids a double-remove).
      confirmDismiss: (direction) async {
        final repo = ref.read(taskRepositoryProvider);
        final now = ref.read(clockProvider).now();
        if (direction == DismissDirection.startToEnd) {
          await repo.checkInTask(task, now);
        } else if (periodic && task.id != null && lens?.id != null) {
          await repo.passTask(task.id!, lens!.id!, now);
        } else {
          await repo.skipTask(task, now);
        }
        return false;
      },
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        icon: task.isCounter
            ? Symbols.add_circle_rounded
            : Symbols.check_circle_rounded,
        label: task.isCounter ? l10n.swipeCheckIn : l10n.swipeDone,
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
