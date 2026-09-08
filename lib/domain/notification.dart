/// Reminders (design-concept §2.4, §9) — the pure scheduling logic. A
/// notification's fire-time is computed from a Task's window; the device's local
/// scheduler (flutter_local_notifications) is told the concrete times. This file
/// has no platform code, so the timing rules are unit-tested directly.
library;

/// `day` anchors at the midnight of the task's day (its occurrence, else its
/// due day, else its start day): "2 days before at 18:00" is
/// `offset = -2 days + 18 h`. Appended last so stored indices stay stable.
enum NotificationAnchor { start, end, absolute, day }

/// One reminder on a Task. `start`/`end`-anchored fire at `window edge + offset`;
/// `absolute` fires at a fixed [at]; `day`-anchored at `day midnight + offset`.
/// The UI presets (at start / upcoming / due) and the custom "N days before at
/// HH:MM" rows are all just an `(anchor, offset)` (§2.4).
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

  /// "[daysBefore] days before, at [timeOfDay]" relative to the task's day.
  TaskNotification.onDay({int daysBefore = 0, required Duration timeOfDay})
    : anchor = NotificationAnchor.day,
      offset = timeOfDay - Duration(days: daysBefore),
      at = null;

  /// For a `day` anchor: how many days before the task's day it fires.
  int get daysBefore =>
      anchor == NotificationAnchor.day ? -_split(offset).$1 : 0;

  /// For a `day` anchor: the wall-clock time it fires at.
  Duration get timeOfDay =>
      anchor == NotificationAnchor.day ? _split(offset).$2 : Duration.zero;

  /// Split an offset into (whole days, non-negative remainder): -2d+18h →
  /// (-2, 18h).
  static (int, Duration) _split(Duration d) {
    var days = d.inDays;
    var rest = d - Duration(days: days);
    if (rest.isNegative) {
      days -= 1;
      rest += const Duration(days: 1);
    }
    return (days, rest);
  }

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
  /// ping needs a `start`; a `day`-anchored one needs a [day] — the occurrence,
  /// else the due day, else the start day).
  DateTime? fireTime({DateTime? start, DateTime? end, DateTime? day}) {
    switch (anchor) {
      case NotificationAnchor.start:
        return start?.add(offset);
      case NotificationAnchor.end:
        return end?.add(offset);
      case NotificationAnchor.absolute:
        return at;
      case NotificationAnchor.day:
        final base = day ?? end ?? start;
        if (base == null) return null;
        final (days, rest) = _split(offset);
        // Civil arithmetic: calendar days + wall-clock time, DST-safe.
        return DateTime(
          base.year,
          base.month,
          base.day + days,
          rest.inHours,
          rest.inMinutes % 60,
        );
    }
  }
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
