/// Reminders (design-concept §2.4, §9) — the pure scheduling logic. A
/// notification's fire-time is computed from a Task's window; the device's local
/// scheduler (flutter_local_notifications) is told the concrete times. This file
/// has no platform code, so the timing rules are unit-tested directly.
library;

enum NotificationAnchor { start, end, absolute }

/// One reminder on a Task. `start`/`end`-anchored fire at `window edge + offset`;
/// `absolute` fires at a fixed [at]. The four UI presets (at start / upcoming /
/// due / reminder) are all just an `(anchor, offset)` (§2.4).
class TaskNotification {
  const TaskNotification({
    required this.anchor,
    this.offset = Duration.zero,
    this.at,
  });

  /// Fire at the window start (use a negative [offset] for "upcoming").
  const TaskNotification.atStart({this.offset = Duration.zero})
    : anchor = NotificationAnchor.start,
      at = null;

  /// Fire at the due edge (use a negative [offset] for "2h before due").
  const TaskNotification.atEnd({this.offset = Duration.zero})
    : anchor = NotificationAnchor.end,
      at = null;

  const TaskNotification.absolute(DateTime when)
    : anchor = NotificationAnchor.absolute,
      offset = Duration.zero,
      at = when;

  final NotificationAnchor anchor;
  final Duration offset;
  final DateTime? at;

  @override
  bool operator ==(Object other) =>
      other is TaskNotification &&
      other.anchor == anchor &&
      other.offset == offset &&
      other.at == at;

  @override
  int get hashCode => Object.hash(anchor, offset, at);

  /// The concrete fire instant for a task with this [start]/[end] window, or
  /// null when the anchor's date is missing (§2.4 validation: a `start`-anchored
  /// ping needs a `start`).
  DateTime? fireTime({DateTime? start, DateTime? end}) => switch (anchor) {
    NotificationAnchor.start => start?.add(offset),
    NotificationAnchor.end => end?.add(offset),
    NotificationAnchor.absolute => at,
  };
}

/// A reminder resolved to a concrete instant, tagged by its task.
class ScheduledNotification {
  const ScheduledNotification({required this.taskId, required this.fireAt});
  final int taskId;
  final DateTime fireAt;
}

/// Pick what to actually register with the OS (§: PLAN notifications): only
/// future fire-times, soonest first, capped at [cap] (the iOS 64-pending limit).
/// Inputs come from **open** tasks only — a completed task's reminders are simply
/// never in the list, which is how "cancel on terminal" falls out.
List<ScheduledNotification> selectScheduled(
  Iterable<ScheduledNotification> all,
  DateTime now, {
  int cap = 64,
}) {
  final future = all.where((n) => n.fireAt.isAfter(now)).toList()
    ..sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return future.length <= cap ? future : future.sublist(0, cap);
}
