import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../domain/notification.dart';
import '../l10n/app_localizations.dart';
import 'reminder_presets.dart';

/// Reminders as a list (examples/ui/07): the three preset chips, plus custom
/// "N days before · HH:MM" rows (a `day`-anchored notification each) and an
/// "At a time…" adder. Emits the full notification list every change.
class ReminderEditor extends StatelessWidget {
  const ReminderEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.hasDay = true,
  });

  final List<TaskNotification> value;
  final ValueChanged<List<TaskNotification>> onChanged;

  /// Whether the task has a day for `day`-anchored rows to hang on (an
  /// occurrence, or a due/start date). When false the rows are still kept
  /// but a hint explains they need a due date.
  final bool hasDay;

  List<TaskNotification> get _custom => [
    for (final n in value)
      if (n.anchor == NotificationAnchor.day ||
          n.anchor == NotificationAnchor.absolute)
        n,
  ];

  void _setPresets(Set<ReminderPreset> presets) =>
      onChanged([...ReminderPreset.toNotifications(presets), ..._custom]);

  void _replaceCustom(List<TaskNotification> custom) => onChanged([
    for (final n in value)
      if (n.anchor != NotificationAnchor.day &&
          n.anchor != NotificationAnchor.absolute)
        n,
    ...custom,
  ]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final custom = _custom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReminderPresetChips(
          selected: ReminderPreset.fromNotifications(value),
          onChanged: _setPresets,
        ),
        for (var i = 0; i < custom.length; i++)
          if (custom[i].anchor == NotificationAnchor.absolute)
            _AbsoluteRow(
              key: ValueKey('absolute-reminder-$i'),
              notification: custom[i],
              onChanged: (n) => _replaceCustom([
                for (var k = 0; k < custom.length; k++) k == i ? n : custom[k],
              ]),
              onRemove: () => _replaceCustom([
                for (var k = 0; k < custom.length; k++)
                  if (k != i) custom[k],
              ]),
            )
          else
            _CustomRow(
              key: ValueKey('custom-reminder-$i'),
              notification: custom[i],
              onChanged: (n) => _replaceCustom([
                for (var k = 0; k < custom.length; k++) k == i ? n : custom[k],
              ]),
              onRemove: () => _replaceCustom([
                for (var k = 0; k < custom.length; k++)
                  if (k != i) custom[k],
              ]),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            // With a day to hang on: "N days before at HH:MM". Without one
            // (an undated one-off): a fixed date and time.
            onPressed: () => _replaceCustom([
              ...custom,
              hasDay
                  ? TaskNotification.onDay(timeOfDay: const Duration(hours: 9))
                  : TaskNotification.absolute(_tomorrowAt9()),
            ]),
            icon: const Icon(Symbols.add_alarm_rounded),
            label: Text(l10n.remindAtTime),
          ),
        ),
        if (!hasDay && custom.any((n) => n.anchor == NotificationAnchor.day))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              l10n.remindNeedsDueDate,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ),
      ],
    );
  }
}

/// One custom row: [−] N days before [+] · time.
class _CustomRow extends StatelessWidget {
  const _CustomRow({
    super.key,
    required this.notification,
    required this.onChanged,
    required this.onRemove,
  });

  final TaskNotification notification;
  final ValueChanged<TaskNotification> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loc = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final days = notification.daysBefore;
    final time = notification.timeOfDay;
    final tod = TimeOfDay(hour: time.inHours, minute: time.inMinutes % 60);

    void set({int? daysBefore, Duration? timeOfDay}) => onChanged(
      TaskNotification.onDay(
        daysBefore: daysBefore ?? days,
        timeOfDay: timeOfDay ?? time,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Symbols.alarm_rounded, size: 20, color: scheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.remindDaysBeforeMore,
                  icon: const Icon(Symbols.remove_rounded),
                  onPressed: () => set(daysBefore: days + 1),
                ),
                Flexible(
                  child: Text(
                    days == 0
                        ? l10n.remindOnTheDay
                        : l10n.remindDaysBefore(days),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.remindDaysBeforeFewer,
                  icon: const Icon(Symbols.add_rounded),
                  onPressed: days == 0 ? null : () => set(daysBefore: days - 1),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: tod,
              );
              if (picked != null) {
                set(
                  timeOfDay: Duration(
                    hours: picked.hour,
                    minutes: picked.minute,
                  ),
                );
              }
            },
            child: Text(loc.formatTimeOfDay(tod)),
          ),
          IconButton(
            tooltip: loc.deleteButtonTooltip,
            icon: const Icon(Symbols.close_rounded),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

DateTime _tomorrowAt9() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1, 9);
}

/// A reminder at a fixed date and time — for one-offs without a due date.
class _AbsoluteRow extends StatelessWidget {
  const _AbsoluteRow({
    super.key,
    required this.notification,
    required this.onChanged,
    required this.onRemove,
  });

  final TaskNotification notification;
  final ValueChanged<TaskNotification> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final at = notification.at ?? _tomorrowAt9();
    final locale = Localizations.localeOf(context).toString();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Symbols.alarm_rounded, size: 20, color: scheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: at,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime(at.year + 5, 12, 31),
                );
                if (d == null) return;
                onChanged(
                  TaskNotification.absolute(
                    DateTime(d.year, d.month, d.day, at.hour, at.minute),
                  ),
                );
              },
              child: Text(DateFormat.yMMMEd(locale).format(at)),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: at.hour, minute: at.minute),
              );
              if (t == null) return;
              onChanged(
                TaskNotification.absolute(
                  DateTime(at.year, at.month, at.day, t.hour, t.minute),
                ),
              );
            },
            child: Text(
              loc.formatTimeOfDay(TimeOfDay(hour: at.hour, minute: at.minute)),
            ),
          ),
          IconButton(
            tooltip: loc.deleteButtonTooltip,
            icon: const Icon(Symbols.close_rounded),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
