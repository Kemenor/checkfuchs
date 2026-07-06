import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recurrence.dart';
import '../domain/task.dart';
import '../domain/template.dart';
import '../domain/window_rule.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'recurrence_editor.dart';
import 'reminder_presets.dart';

/// Create a task or habit (Phase 3): name + recurrence (Off = one-off) + an
/// active-window picker. A recurrence makes a Template; "Off" makes a one-off
/// Task. Reconciles so the first instance appears immediately.
Future<void> showCreateTaskSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CreateTaskSheet(),
  );
}

enum _WindowChoice {
  anytime,
  morning,
  afternoon,
  evening;

  String label(AppLocalizations l10n) => switch (this) {
    _WindowChoice.anytime => l10n.windowAnytime,
    _WindowChoice.morning => l10n.windowMorning,
    _WindowChoice.afternoon => l10n.windowAfternoon,
    _WindowChoice.evening => l10n.windowEvening,
  };

  WindowRule toRule() => switch (this) {
    _WindowChoice.anytime => const UntilNextOccurrence(),
    _WindowChoice.morning => Slice.morning,
    _WindowChoice.afternoon => Slice.afternoon,
    _WindowChoice.evening => Slice.evening,
  };

  /// (start, end) for a one-off created at [now]. "Anytime" = unbounded (never
  /// misses). A slice whose window has already fully passed today rolls to
  /// tomorrow — otherwise a "Morning" task created in the afternoon would be
  /// born expired: uncompletable, unskippable, and dead on arrival. Bounds are
  /// built civilly (calendar date + wall-clock time), so they're DST-safe.
  (DateTime?, DateTime?) oneOffWindow(DateTime now) {
    final (int fromHour, int toHour) = switch (this) {
      _WindowChoice.anytime => (0, 0),
      _WindowChoice.morning => (0, 12),
      _WindowChoice.afternoon => (12, 18),
      _WindowChoice.evening => (18, 24),
    };
    if (this == _WindowChoice.anytime) return (null, null);

    DateTime at(DateTime d, int hour) =>
        DateTime(d.year, d.month, d.day + (hour ~/ 24), hour % 24);

    var day = DateTime(now.year, now.month, now.day);
    var end = at(day, toHour);
    if (!end.isAfter(now)) {
      day = DateTime(day.year, day.month, day.day + 1);
      end = at(day, toHour);
    }
    return (at(day, fromHour), end);
  }
}

class _CreateTaskSheet extends ConsumerStatefulWidget {
  const _CreateTaskSheet();

  @override
  ConsumerState<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends ConsumerState<_CreateTaskSheet> {
  final _controller = TextEditingController();
  Recurrence? _recurrence;
  _WindowChoice _window = _WindowChoice.anytime;
  Set<ReminderPreset> _reminders = const {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(taskRepositoryProvider);
    final now = ref.read(clockProvider).now();

    final notifications = ReminderPreset.toNotifications(_reminders);
    if (_recurrence != null) {
      await repo.createTemplate(
        Template(
          name: name,
          recurrence: _recurrence!,
          windowRule: _window.toRule(),
          createdAt: now,
          notifications: notifications,
        ),
      );
    } else {
      final (start, end) = _window.oneOffWindow(now);
      await repo.createTask(
        Task(
          name: name,
          start: start,
          end: end,
          createdAt: now,
          notifications: notifications,
        ),
      );
    }
    await repo.reconcileAll(now);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final now = ref.read(clockProvider).now();
    final anchor = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, viewInsets + 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.newTask, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.nameLabel,
                  hintText: l10n.taskNameHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _SectionLabel(l10n.activeWindowSection),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final w in _WindowChoice.values)
                    ChoiceChip(
                      label: Text(w.label(l10n)),
                      selected: _window == w,
                      onSelected: (_) => setState(() => _window = w),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionLabel(l10n.remindersSection),
              const SizedBox(height: 8),
              ReminderPresetChips(
                selected: _reminders,
                onChanged: (s) => setState(() => _reminders = s),
              ),
              const SizedBox(height: 20),
              _SectionLabel(l10n.repeatSection),
              const SizedBox(height: 10),
              RecurrenceEditor(
                anchor: anchor,
                onChanged: (r) => setState(() => _recurrence = r),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _controller.text.trim().isEmpty ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.outline,
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
      ),
    );
  }
}
