/// The Task — the only object with a completion status (design-concept §2) — and
/// its pure state machine. No I/O: every function is `(task, now) → task/bool`,
/// so the whole lifecycle is unit-testable against a [FixedClock].
library;

import 'notification.dart';
import 'window_rule.dart';

/// The four live-or-terminal states (§2.2). Only `open` is non-terminal.
enum TaskStatus { open, done, skipped, missed }

/// Where `now` sits relative to a Task's window — **derived, never stored** (§2.3).
enum TaskPhase {
  /// `now < start` — exists but not yet actionable.
  pending,

  /// within the window (or unbounded) and still open — actionable.
  active,

  /// `now > end` while still open — due to become `Missed`.
  expired,
}

class Task {
  const Task({
    this.id,
    this.templateId,
    required this.name,
    this.note,
    this.status = TaskStatus.open,
    this.start,
    this.end,
    this.occurrence,
    required this.createdAt,
    this.resolvedAt,
    this.notifications = const [],
    this.bands,
  });

  final int? id;

  /// The generating Template; null = a standalone one-off (§3, §2.1).
  final int? templateId;
  final String name;
  final String? note;
  final TaskStatus status;

  /// Window (§2.3). `start` absent ⇒ active immediately; `end` absent ⇒ endless
  /// & unfailable (only `Done`/`Skipped`, never `Missed`).
  final DateTime? start;
  final DateTime? end;

  /// The occurrence date this instance fills (for a generated Task) — used to
  /// match stored tasks to projection slots (§3.4). Null for standalone one-offs.
  final DateTime? occurrence;

  final DateTime createdAt;

  /// When it went terminal; null while open. Required for analytics (§2.1).
  final DateTime? resolvedAt;

  /// Reminders on this instance (§2.4). Stamped from the Template's defaults
  /// at materialisation; editable per instance. All **discrete** — the
  /// reactive layer schedules only open tasks, so resolving one cancels its
  /// pings by construction.
  final List<TaskNotification> notifications;

  /// Active bands *within* `start`…`end`, repeating each civil day of the
  /// window ("morning or evening"). Null = the whole span is active. Only the
  /// phase reads this; `start`/`end` stay the envelope everything else uses.
  final List<Band>? bands;

  bool get isOpen => status == TaskStatus.open;
  bool get isTerminal => !isOpen;

  /// Nullable fields use a sentinel default so they can be *cleared* by passing
  /// an explicit `null` (e.g. removing a due date, or nulling `resolvedAt` for
  /// a Missed→Done correction) — `?? this.x` could never express that.
  static const _unset = Object();

  Task copyWith({
    int? id,
    Object? templateId = _unset,
    String? name,
    Object? note = _unset,
    TaskStatus? status,
    Object? start = _unset,
    Object? end = _unset,
    Object? occurrence = _unset,
    DateTime? createdAt,
    Object? resolvedAt = _unset,
    List<TaskNotification>? notifications,
    Object? bands = _unset,
  }) {
    return Task(
      id: id ?? this.id,
      templateId: identical(templateId, _unset)
          ? this.templateId
          : templateId as int?,
      name: name ?? this.name,
      note: identical(note, _unset) ? this.note : note as String?,
      status: status ?? this.status,
      start: identical(start, _unset) ? this.start : start as DateTime?,
      end: identical(end, _unset) ? this.end : end as DateTime?,
      occurrence: identical(occurrence, _unset)
          ? this.occurrence
          : occurrence as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: identical(resolvedAt, _unset)
          ? this.resolvedAt
          : resolvedAt as DateTime?,
      notifications: notifications ?? this.notifications,
      bands: identical(bands, _unset) ? this.bands : bands as List<Band>?,
    );
  }

  static bool _sameNotifications(
    List<TaskNotification> a,
    List<TaskNotification> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is Task &&
      other.id == id &&
      other.templateId == templateId &&
      other.name == name &&
      other.note == note &&
      other.status == status &&
      other.start == start &&
      other.end == end &&
      other.occurrence == occurrence &&
      other.createdAt == createdAt &&
      other.resolvedAt == resolvedAt &&
      _sameNotifications(other.notifications, notifications) &&
      _sameBands(other.bands, bands);

  static bool _sameBands(List<Band>? a, List<Band>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    templateId,
    name,
    note,
    status,
    start,
    end,
    occurrence,
    createdAt,
    resolvedAt,
    Object.hashAll(notifications),
    bands == null ? null : Object.hashAll(bands!),
  );

  @override
  String toString() => 'Task(#$id "$name" $status start:$start end:$end)';
}

// ---------------------------------------------------------------------------
// State machine — pure transitions over (task, now)
// ---------------------------------------------------------------------------

/// Where `now` sits in the task's window. Independent of [TaskStatus]; it only
/// describes time. (`start` null ⇒ never pending; `end` null ⇒ never expired.)
/// With [Task.bands], the gaps between bands read as `pending` — the window
/// hasn't expired, but the task isn't actionable right now.
TaskPhase phaseOf(Task t, DateTime now) {
  if (t.start != null && now.isBefore(t.start!)) return TaskPhase.pending;
  if (t.end != null && now.isAfter(t.end!)) return TaskPhase.expired;
  final bands = t.bands;
  if (bands != null && bands.isNotEmpty && !bands.any((b) => b.contains(now))) {
    return TaskPhase.pending;
  }
  return TaskPhase.active;
}

/// `Done` — user action, allowed **only while Active** (§2.5).
bool canComplete(Task t, DateTime now) =>
    t.isOpen && phaseOf(t, now) == TaskPhase.active;

/// `Skip` — user action, allowed **anytime while Open** (Pending or Active), but
/// not once the window has expired (it's about to become `Missed`).
bool canSkip(Task t, DateTime now) =>
    t.isOpen && phaseOf(t, now) != TaskPhase.expired;

/// Apply `Done`.
Task complete(Task t, DateTime now) {
  assert(canComplete(t, now), 'complete() requires an active, open task');
  return t.copyWith(status: TaskStatus.done, resolvedAt: now);
}

/// Apply `Skip`.
Task skip(Task t, DateTime now) {
  assert(canSkip(t, now), 'skip() requires an open, non-expired task');
  return t.copyWith(status: TaskStatus.skipped, resolvedAt: now);
}

/// Auto-transition an open task whose window has passed → `Missed`. Returns the
/// updated task, or `null` if nothing changes. `resolvedAt` is the window **end**
/// (when it actually failed), so back-filling on a later open stays truthful.
Task? expireIfDue(Task t, DateTime now) {
  if (!t.isOpen || phaseOf(t, now) != TaskPhase.expired) return null;
  return t.copyWith(status: TaskStatus.missed, resolvedAt: t.end);
}
