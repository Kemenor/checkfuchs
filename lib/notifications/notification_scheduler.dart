import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/notification.dart';
import '../domain/task.dart' as domain;

/// The platform half of reminders (PLAN Phase 5, concept §9). The *what/when*
/// is pure domain ([TaskNotification.fireTime], [selectScheduled]); this class
/// only hands the OS the concrete instants.
///
/// All reminders are **discrete** — one OS notification per instance — and the
/// whole schedule is re-filled from the current open tasks on every sync, so
/// completing/skipping/editing instantly cancels the affected pings (a done
/// task is simply no longer in the input). Idempotent: cancelAll + reschedule.
class NotificationScheduler {
  NotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;
  bool _unavailable = false; // no platform runtime (tests, desktop)
  bool _exact = false;

  /// A task carries at most this many reminders; the composite OS id is
  /// `taskId * _slots + index`, unique as long as this holds.
  static const int _slots = 8;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Task reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<bool> _ensureReady() async {
    if (_ready) return true;
    if (_unavailable) return false;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      _exact = await android?.canScheduleExactNotifications() ?? true;

      _ready = true;
      return true;
    } catch (e) {
      // No notification runtime here (unit/widget tests, unsupported
      // platforms) — reminders are simply off, everything else works.
      debugPrint('NotificationScheduler unavailable: $e');
      _unavailable = true;
      return false;
    }
  }

  /// Re-fill the OS schedule from [tasks]: open instances' reminders resolved
  /// to instants, future-only, soonest-first, capped at 64 (the iOS limit,
  /// PLAN "≤ 64 pending" — Android follows the same budget).
  Future<void> sync(List<domain.Task> tasks, DateTime now) async {
    if (!await _ensureReady()) return;

    final titles = <int, String>{};
    final all = <ScheduledNotification>[];
    for (final t in tasks) {
      if (!t.isOpen || t.id == null) continue;
      final count = t.notifications.length.clamp(0, _slots);
      for (var i = 0; i < count; i++) {
        final fireAt = t.notifications[i].fireTime(start: t.start, end: t.end);
        if (fireAt == null) continue;
        final id = t.id! * _slots + i;
        titles[id] = t.name;
        all.add(ScheduledNotification(taskId: id, fireAt: fireAt));
      }
    }
    final selected = selectScheduled(all, now);

    try {
      await _plugin.cancelAll();
      for (final s in selected) {
        await _plugin.zonedSchedule(
          id: s.taskId,
          title: titles[s.taskId],
          scheduledDate: tz.TZDateTime.from(s.fireAt, tz.local),
          notificationDetails: _details,
          androidScheduleMode: _exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('NotificationScheduler sync failed: $e');
    }
  }
}
