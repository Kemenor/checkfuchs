import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../domain/recurrence.dart';
import '../domain/task.dart';
import '../domain/template.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'recurrence_editor.dart';
import 'reminder_presets.dart';
import 'window_choice.dart';

final _lensesProvider = StreamProvider.autoDispose<List<LensRow>>(
  (ref) => ref.watch(viewRepositoryProvider).watchAllLenses(),
);

/// Create a task or habit (Phase 3): name + lens (the bucket it lives in,
/// defaulting to the current view's first lens) + recurrence (Off = one-off)
/// + an active-window picker. A recurrence makes a Template; "Off" makes a
/// one-off Task. Reconciles so the first instance appears immediately.
Future<void> showCreateTaskSheet(
  BuildContext context,
  WidgetRef ref, {
  int? viewId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CreateTaskSheet(viewId: viewId),
  );
}

class _CreateTaskSheet extends ConsumerStatefulWidget {
  const _CreateTaskSheet({this.viewId});

  final int? viewId;

  @override
  ConsumerState<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends ConsumerState<_CreateTaskSheet> {
  final _controller = TextEditingController();
  Recurrence? _recurrence;
  WindowChoice _window = WindowChoice.anytime;
  Set<ReminderPreset> _reminders = const {};
  int? _lensId;

  @override
  void initState() {
    super.initState();
    // Default bucket: the first lens of the view the sheet was opened from.
    final viewId = widget.viewId;
    if (viewId != null) {
      ref.read(viewRepositoryProvider).watchViewLenses(viewId).first.then((
        entries,
      ) {
        if (mounted && _lensId == null && entries.isNotEmpty) {
          setState(() => _lensId = entries.first.lens.id);
        }
      });
    }
  }

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
        defaultLensId: _lensId,
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
        lensId: _lensId,
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
              // The bucket: which lens this task lives in (concept §4.6 —
              // membership is data; views merely arrange lenses).
              ...switch (ref.watch(_lensesProvider).asData?.value) {
                null || [] || [_] => const [],
                final lenses => [
                  const SizedBox(height: 20),
                  _SectionLabel(l10n.lensSection),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final lens in lenses)
                        ChoiceChip(
                          label: Text(lens.name),
                          selected: _lensId == lens.id,
                          onSelected: (_) => setState(() => _lensId = lens.id),
                        ),
                    ],
                  ),
                ],
              },
              const SizedBox(height: 20),
              _SectionLabel(l10n.activeWindowSection),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final w in WindowChoice.values)
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
