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

  // Channel strings are user-visible in Android's Settings › Notifications;
  // [localize] swaps in the app locale's words (and re-creates the channel,
  // since Android caches its metadata).
  static const _channelId = 'reminders';
  String _channelName = 'Reminders';
  String _channelDescription = 'Task reminders';

  NotificationDetails get _details => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  /// Localize the channel's name/description (call on launch and on a
  /// language change).
  Future<void> localize({
    required String name,
    required String description,
  }) async {
    _channelName = name;
    _channelDescription = description;
    if (!await _ensureReady()) return;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          name,
          description: description,
          importance: Importance.high,
        ),
      );
    } catch (e) {
      debugPrint('localize channel failed: $e');
    }
  }

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
          // No permission prompt at init on iOS either — asked in context
          // via [requestPermission] the first time a reminder is chosen.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      // No permission prompt here: the OS dialog is asked for in context —
      // the first time a reminder is chosen (see [requestPermission]) — never
      // at launch.
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

  /// What the OS currently has scheduled — for the debug menu.
  Future<List<PendingNotificationRequest>> pending() async {
    if (!await _ensureReady()) return const [];
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return const [];
    }
  }

  /// Whether the OS lets us schedule exact alarms (Android 14+ requires the
  /// "Alarms & reminders" special access; without it pings drift ≤ 1 h).
  Future<bool> canScheduleExact() async {
    if (!await _ensureReady()) return true; // nothing to grant elsewhere
    return _exact;
  }

  /// Whether the OS lets us post notifications at all. Null when unknown
  /// (no runtime here, or a platform without the concept).
  Future<bool?> notificationsEnabled() async {
    if (!await _ensureReady()) return null;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) return await android.areNotificationsEnabled();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) return (await ios.checkPermissions())?.isEnabled;
      return null;
    } catch (e) {
      debugPrint('notificationsEnabled failed: $e');
      return null;
    }
  }

  /// Show the OS notification-permission dialog (Android 13+; a no-op once
  /// the user has declined twice). Returns the resulting state. Called the
  /// first time a task is saved with a reminder, and from Settings.
  Future<bool> requestPermission() async {
    if (!await _ensureReady()) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final iosGranted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? iosGranted ?? false;
    } catch (e) {
      debugPrint('requestPermission failed: $e');
      return false;
    }
  }

  /// Open the system "Alarms & reminders" grant, then re-read the state so
  /// the next sync schedules exactly. Returns the new state.
  Future<bool> requestExactAlarms() async {
    if (!await _ensureReady()) return true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestExactAlarmsPermission();
      _exact = await android?.canScheduleExactNotifications() ?? _exact;
    } catch (e) {
      debugPrint('requestExactAlarms failed: $e');
    }
    return _exact;
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
        final fireAt = t.notifications[i].fireTime(
          start: t.start,
          end: t.end,
          day: t.occurrence,
        );
        if (fireAt == null) continue;
        final id = t.id! * _slots + i;
        titles[id] = t.name;
        all.add(ScheduledNotification(taskId: id, fireAt: fireAt));
      }
    }
    final selected = selectScheduled(all, now);

    try {
      // Re-read the exact-alarm grant each sync: it can change mid-session
      // (the Settings tile, or the user toggling special access directly)
      // and a stale cache would silently keep pings inexact.
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      _exact = await android?.canScheduleExactNotifications() ?? _exact;

      // Cancel only what is still *pending*: cancelAll() would also wipe
      // reminders already sitting in the tray that the user hasn't acted on.
      for (final pending in await _plugin.pendingNotificationRequests()) {
        await _plugin.cancel(id: pending.id);
      }
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
