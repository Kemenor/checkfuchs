import 'package:flutter/material.dart';

import '../domain/notification.dart';
import '../l10n/app_localizations.dart';

/// The friendly reminder presets (PLAN Phase 5) over the general
/// `(anchor, offset)` form — the 80% of concept §2.4 without exposing it.
enum ReminderPreset {
  whenOpens(TaskNotification.atStart()),
  beforeDue(TaskNotification.atEnd(offset: Duration(hours: -2))),
  atDue(TaskNotification.atEnd());

  const ReminderPreset(this.notification);

  final TaskNotification notification;

  String label(AppLocalizations l10n) => switch (this) {
    ReminderPreset.whenOpens => l10n.remindWhenOpens,
    ReminderPreset.beforeDue => l10n.remindBeforeDue,
    ReminderPreset.atDue => l10n.remindAtDue,
  };

  static List<TaskNotification> toNotifications(Set<ReminderPreset> presets) =>
      [
        for (final p in ReminderPreset.values)
          if (presets.contains(p)) p.notification,
      ];

  /// The presets present in [notifications] (unknown/custom entries are simply
  /// not representable as chips — none can be created yet).
  static Set<ReminderPreset> fromNotifications(
    List<TaskNotification> notifications,
  ) => {
    for (final p in ReminderPreset.values)
      if (notifications.contains(p.notification)) p,
  };
}

/// Multi-select preset chips — used by the create sheet (template/one-off
/// defaults) and the detail sheet (edit this instance / the series).
class ReminderPresetChips extends StatelessWidget {
  const ReminderPresetChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<ReminderPreset> selected;
  final ValueChanged<Set<ReminderPreset>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      children: [
        for (final p in ReminderPreset.values)
          FilterChip(
            label: Text(p.label(l10n)),
            selected: selected.contains(p),
            onSelected: (on) {
              final next = {...selected};
              on ? next.add(p) : next.remove(p);
              onChanged(next);
            },
          ),
      ],
    );
  }
}
