import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/db/database.dart';
import '../domain/analytics.dart';
import '../domain/notification.dart';
import '../domain/task.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'edit_repeat_sheet.dart';
import 'reminder_editor.dart';

/// Tap a task → this sheet: rename, delete this occurrence, or delete the whole
/// series (recurring only). Delete is the one sanctioned use of `error` red
/// (DESIGN_SYSTEM §1.3). The full this-vs-series *editing* + turn-into-series
/// come later; this covers rename + delete.
Future<void> showTaskDetailSheet(
  BuildContext context,
  WidgetRef ref,
  Task task,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TaskDetailSheet(task: task),
  );
}

/// One window edge on the detail sheet: absolute day (+ clock time when one
/// is set — a midnight end reads as its evening's day, never "00:00").
class _WindowDateTile extends StatelessWidget {
  const _WindowDateTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.isEnd,
    required this.onTap,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final DateTime? value;
  final String placeholder;
  final bool isEnd;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final v = value;
    String text;
    if (v == null) {
      text = placeholder;
    } else {
      final wholeDay = v.hour == 0 && v.minute == 0;
      final day = isEnd && wholeDay
          ? v.subtract(const Duration(minutes: 1))
          : v;
      text = DateFormat.yMMMEd(locale).format(day);
      if (!wholeDay) text = '$text · ${DateFormat.Hm(locale).format(v)}';
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        text,
        style: v == null ? TextStyle(color: scheme.outline) : null,
      ),
      trailing: v == null
          ? const Icon(Symbols.chevron_right_rounded)
          : IconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              icon: const Icon(Symbols.close_rounded),
              onPressed: onClear,
            ),
      onTap: onTap,
    );
  }
}

class _TaskDetailSheet extends ConsumerStatefulWidget {
  const _TaskDetailSheet({required this.task});
  final Task task;

  @override
  ConsumerState<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<_TaskDetailSheet> {
  late final _controller = TextEditingController(text: widget.task.name);

  /// The live task — re-read after nested sheets mutate it (turn-into-series /
  /// stop-repeating change `templateId`, which drives most of this sheet).
  late Task _task = widget.task;
  late List<TaskNotification> _notifications = _task.notifications;
  bool _paused = false;
  HabitStats? _stats;
  List<LensRow> _lenses = const [];
  Set<int> _lensIds = const {};

  Future<void> _setReminders(List<TaskNotification> n) async {
    final hadNone = _notifications.isEmpty;
    setState(() => _notifications = n);
    final repo = ref.read(taskRepositoryProvider);
    if (hadNone && n.isNotEmpty) await ensureNotificationPermission(ref);
    // A series edit updates the defaults AND the open instances; a one-off
    // edit touches just this task.
    if (_task.templateId != null) {
      await repo.setTemplateNotifications(_task.templateId!, n);
    } else if (_task.id != null) {
      await repo.setTaskNotifications(_task.id!, n);
    }
    _task = _task.copyWith(notifications: n);
  }

  @override
  void initState() {
    super.initState();
    _loadSeriesInfo();
    _loadLensInfo();
  }

  Future<void> _loadLensInfo() async {
    final lenses = await ref
        .read(viewRepositoryProvider)
        .watchAllLenses()
        .first;
    final lensIds = _task.id == null
        ? const <int>{}
        : await ref.read(taskRepositoryProvider).taskLensIds(_task.id!);
    if (!mounted) return;
    setState(() {
      _lenses = lenses;
      _lensIds = lensIds;
    });
  }

  /// Choose the lenses this task (or its whole series — membership is a
  /// series property, not a per-occurrence one) lives in. Multi-select; the
  /// last lens can't be unticked because a task in no lens is invisible.
  Future<void> _pickLenses() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => _LensPickerDialog(
        title: l10n.lensSection,
        lenses: _lenses,
        initial: _lensIds,
      ),
    );
    if (picked == null || setEquals(picked, _lensIds)) return;
    final repo = ref.read(taskRepositoryProvider);
    if (_task.templateId != null) {
      await repo.setTemplateLenses(_task.templateId!, picked);
    } else if (_task.id != null) {
      await repo.setTaskLenses(_task.id!, picked);
    }
    if (mounted) setState(() => _lensIds = picked);
  }

  /// Edit one window edge of an open one-off. The date picker chooses the
  /// day; an existing wall-clock time survives the move (a 17:00 deadline
  /// pushed to the 29th is still 17:00), a bare date keeps whole-day
  /// semantics (due = midnight after, start = midnight of).
  Future<void> _editWindowDate({required bool isEnd}) async {
    final now = ref.read(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    final old = isEnd ? _task.end : _task.start;
    final oldDay = old == null ? null : DateTime(old.year, old.month, old.day);
    var first = isEnd ? (_task.start ?? today) : today;
    first = DateTime(first.year, first.month, first.day);
    if (oldDay != null && oldDay.isBefore(first)) first = oldDay;
    final picked = await showDatePicker(
      context: context,
      initialDate: oldDay ?? today,
      firstDate: first,
      lastDate: DateTime(today.year + 5, 12, 31),
    );
    if (picked == null) return;
    await _writeWindow(_apply(picked, old, isEnd: isEnd), isEnd: isEnd);
  }

  static DateTime _apply(DateTime day, DateTime? old, {required bool isEnd}) {
    final wholeDay = old == null || (old.hour == 0 && old.minute == 0);
    if (isEnd && wholeDay) return DateTime(day.year, day.month, day.day + 1);
    if (wholeDay) return DateTime(day.year, day.month, day.day);
    return DateTime(day.year, day.month, day.day, old.hour, old.minute);
  }

  Future<void> _writeWindow(DateTime? value, {required bool isEnd}) async {
    final start = isEnd ? _task.start : value;
    final end = isEnd ? value : _task.end;
    await ref.read(taskRepositoryProvider).setTaskWindow(_task.id!, start, end);
    if (mounted) {
      setState(() => _task = _task.copyWith(start: start, end: end));
    }
  }

  void _loadSeriesInfo() {
    final tid = _task.templateId;
    if (tid == null) {
      setState(() {
        _paused = false;
        _stats = null;
      });
      return;
    }
    final repo = ref.read(taskRepositoryProvider);
    repo.isTemplatePaused(tid).then((p) {
      if (mounted) setState(() => _paused = p);
    });
    repo.tasksForTemplate(tid).then((tasks) {
      if (mounted) setState(() => _stats = computeStats(tasks));
    });
  }

  Future<void> _editRepeat() async {
    await showEditRepeatSheet(context, ref, _task);
    if (!mounted || _task.id == null) return;
    // The nested sheet may have converted/stopped the series (the original
    // task row can be replaced by the first generated instance) — re-read.
    final fresh = await ref.read(taskRepositoryProvider).taskById(_task.id!);
    if (!mounted) return;
    if (fresh == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _task = fresh;
      _notifications = fresh.notifications;
    });
    _loadSeriesInfo();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _controller.text.trim();
    if (name.isNotEmpty && name != _task.name) {
      await ref.read(taskRepositoryProvider).renameTask(_task.id!, name);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete({required bool series}) async {
    final repo = ref.read(taskRepositoryProvider);
    if (series && _task.templateId != null) {
      await repo.deleteTemplate(_task.templateId!);
    } else {
      await repo.deleteTask(_task.id!);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final recurring = _task.templateId != null;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, viewInsets + 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: const InputDecoration(border: InputBorder.none),
              onSubmitted: (_) => _saveName(),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saveName,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(l10n.save),
              ),
            ),
            // Missed habit: the logging correction (§11 q7). Pops the sheet —
            // the stream re-renders the row as done.
            if (canCorrectMiss(_task)) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref
                      .read(taskRepositoryProvider)
                      .correctMissedTask(_task);
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Symbols.check_circle_rounded),
                label: Text(l10n.markDoneAnyway),
              ),
            ],
            if (_stats?.hasData ?? false) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Symbols.local_fire_department_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.dayStreak(_stats!.currentStreak),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    l10n.percentDone((_stats!.completionRate * 100).round()),
                    style: TextStyle(color: scheme.outline),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Symbols.notifications_none_rounded,
                  size: 20,
                  color: scheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.remindersSection,
                  style: TextStyle(
                    color: scheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ReminderEditor(
              value: _notifications,
              hasDay:
                  _task.occurrence != null ||
                  _task.end != null ||
                  _task.start != null,
              onChanged: _setReminders,
            ),
            const SizedBox(height: 4),
            if (_lenses.length > 1)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Symbols.filter_alt_rounded),
                title: Text(l10n.lensSection),
                subtitle: switch (_lenses.where(
                  (l) => _lensIds.contains(l.id),
                )) {
                  Iterable(isEmpty: true) => null,
                  final match => Text(match.map((l) => l.name).join(', ')),
                },
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: _pickLenses,
              ),
            // Window edges are editable on open one-offs only — a series'
            // window comes from its recurrence + slice rule.
            if (!recurring && _task.isOpen) ...[
              _WindowDateTile(
                icon: Symbols.today_rounded,
                label: l10n.starts,
                value: _task.start,
                placeholder: l10n.startsNow,
                isEnd: false,
                onTap: () => _editWindowDate(isEnd: false),
                onClear: () => _writeWindow(null, isEnd: false),
              ),
              _WindowDateTile(
                icon: Symbols.flag_rounded,
                label: l10n.dueLabel,
                value: _task.end,
                placeholder: l10n.noDueDate,
                isEnd: true,
                onTap: () => _editWindowDate(isEnd: true),
                onClear: () => _writeWindow(null, isEnd: true),
              ),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Symbols.event_repeat_rounded),
              title: Text(recurring ? l10n.editRepeat : l10n.makeItAHabit),
              trailing: const Icon(Symbols.chevron_right_rounded),
              onTap: _editRepeat,
            ),
            if (recurring)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Symbols.pause_circle_outline_rounded),
                title: Text(l10n.paused),
                subtitle: Text(l10n.pausedSubtitle),
                value: _paused,
                onChanged: (v) async {
                  await ref
                      .read(taskRepositoryProvider)
                      .pauseTemplate(
                        _task.templateId!,
                        v,
                        ref.read(clockProvider).now(),
                      );
                  if (mounted) setState(() => _paused = v);
                },
              ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => _delete(series: false),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              icon: const Icon(Symbols.delete_outline_rounded),
              label: Text(recurring ? l10n.deleteThisTask : l10n.deleteTask),
            ),
            if (recurring)
              TextButton.icon(
                onPressed: () => _delete(series: true),
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Symbols.delete_forever_rounded),
                label: Text(l10n.deleteWholeSeries),
              ),
          ],
        ),
      ),
    );
  }
}

/// Checkbox list over all lenses; OK returns the selection. The last ticked
/// lens is locked on — a task must live somewhere.
class _LensPickerDialog extends StatefulWidget {
  const _LensPickerDialog({
    required this.title,
    required this.lenses,
    required this.initial,
  });

  final String title;
  final List<LensRow> lenses;
  final Set<int> initial;

  @override
  State<_LensPickerDialog> createState() => _LensPickerDialogState();
}

class _LensPickerDialogState extends State<_LensPickerDialog> {
  late Set<int> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.only(top: 12),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final lens in widget.lenses)
              CheckboxListTile(
                value: _selected.contains(lens.id),
                title: Text(lens.name),
                onChanged: (on) => setState(() {
                  if (on == true) {
                    _selected = {..._selected, lens.id};
                  } else if (_selected.length > 1) {
                    _selected = {..._selected}..remove(lens.id);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
