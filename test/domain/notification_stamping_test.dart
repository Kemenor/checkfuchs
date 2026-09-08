import 'package:checkfuchs/domain/notification.dart';
import 'package:checkfuchs/domain/recurrence.dart';
import 'package:checkfuchs/domain/task.dart';
import 'package:checkfuchs/domain/template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('materialize stamps the template defaults onto the instance', () {
    const reminders = [
      TaskNotification.atStart(),
      TaskNotification.atEnd(offset: Duration(hours: -2)),
    ];
    final t = Template(
      id: 1,
      name: 'Brush teeth',
      recurrence: Recurrence.daily(DateTime(2026, 7, 6)),
      createdAt: DateTime(2026, 7, 6),
      notifications: reminders,
    );
    final task = t.materialize(
      DateTime(2026, 7, 6),
      DateTime(2026, 7, 7),
      now: DateTime(2026, 7, 6, 8),
    );
    expect(task.notifications, reminders);
    // …and they resolve against the instance's own window.
    expect(
      task.notifications.first.fireTime(start: task.start, end: task.end),
      task.start,
    );
  });

  test('copyWith replaces the reminder list; omitting keeps it', () {
    final task = Task(
      name: 'Call dentist',
      createdAt: DateTime(2026, 7, 6),
      notifications: const [TaskNotification.atStart()],
    );
    expect(task.copyWith(name: 'X').notifications, task.notifications);
    expect(task.copyWith(notifications: const []).notifications, isEmpty);
  });
}
