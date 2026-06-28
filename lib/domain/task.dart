/// The Task — the only object with a completion status (design-concept §2) — and
/// its pure state machine. No I/O: every function is `(task, now) → task/bool`,
/// so the whole lifecycle is unit-testable against a [FixedClock].
library;

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
    required this.createdAt,
    this.resolvedAt,
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

  final DateTime createdAt;

  /// When it went terminal; null while open. Required for analytics (§2.1).
  final DateTime? resolvedAt;

  bool get isOpen => status == TaskStatus.open;
  bool get isTerminal => !isOpen;

  Task copyWith({
    int? id,
    int? templateId,
    String? name,
    String? note,
    TaskStatus? status,
    DateTime? start,
    DateTime? end,
    DateTime? createdAt,
    DateTime? resolvedAt,
  }) {
    return Task(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      note: note ?? this.note,
      status: status ?? this.status,
      start: start ?? this.start,
      end: end ?? this.end,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
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
      other.createdAt == createdAt &&
      other.resolvedAt == resolvedAt;

  @override
  int get hashCode => Object.hash(
        id,
        templateId,
        name,
        note,
        status,
        start,
        end,
        createdAt,
        resolvedAt,
      );

  @override
  String toString() => 'Task(#$id "$name" $status start:$start end:$end)';
}

// ---------------------------------------------------------------------------
// State machine — pure transitions over (task, now)
// ---------------------------------------------------------------------------

/// Where `now` sits in the task's window. Independent of [TaskStatus]; it only
/// describes time. (`start` null ⇒ never pending; `end` null ⇒ never expired.)
TaskPhase phaseOf(Task t, DateTime now) {
  if (t.start != null && now.isBefore(t.start!)) return TaskPhase.pending;
  if (t.end != null && now.isAfter(t.end!)) return TaskPhase.expired;
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
