import 'package:flutter/material.dart';
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
      if (n.anchor == NotificationAnchor.day) n,
  ];

  void _setPresets(Set<ReminderPreset> presets) =>
      onChanged([...ReminderPreset.toNotifications(presets), ..._custom]);

  void _replaceCustom(List<TaskNotification> custom) => onChanged([
    for (final n in value)
      if (n.anchor != NotificationAnchor.day) n,
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
            onPressed: () => _replaceCustom([
              ...custom,
              TaskNotification.onDay(timeOfDay: const Duration(hours: 9)),
            ]),
            icon: const Icon(Symbols.add_alarm_rounded),
            label: Text(l10n.remindAtTime),
          ),
        ),
        if (custom.isNotEmpty && !hasDay)
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
