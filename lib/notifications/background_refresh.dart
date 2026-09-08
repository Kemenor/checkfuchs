import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../data/db/database.dart';
import '../data/repositories/task_repository.dart';
import 'notification_scheduler.dart';

/// The ~12h background refresh pass (PLAN Phase 5, §Notifications).
///
/// The OS fires the discrete pings on its own — but the schedule only covers
/// the next horizon (≤ 64 pending). If the app isn't opened for days, the
/// schedule would run dry. This periodic WorkManager pass re-fills it:
/// reconcile (roll over recurring tasks), then re-sync the OS schedule from
/// the current open tasks. The worker only refreshes the schedule; it never
/// shows anything itself.

/// WorkManager unique name — one periodic refresh exists at a time.
const String backgroundRefreshUniqueName = 'checkfuchs-refresh';

/// Task name handed back to the dispatcher by WorkManager.
const String backgroundRefreshTaskName = 'refresh';

/// Entry point WorkManager invokes in a fresh background isolate. Must be
/// top-level and kept alive for AOT ([pragma]).
///
/// No Riverpod, no BuildContext here — plain constructors on a fresh
/// [AppDatabase] (the foreground isolate, if any, has its own connection;
/// SQLite serializes the writers). [NotificationScheduler._ensureReady]
/// handles plugin init in this isolate; if there is no platform runtime it
/// degrades to a no-op, which is fine.
@pragma('vm:entry-point')
void backgroundRefreshDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final db = AppDatabase.open();
    try {
      final now = DateTime.now();
      final repo = TaskRepository(db);
      await repo.reconcileAll(now);
      final tasks = await repo.allTasks();
      await NotificationScheduler().sync(tasks, now);
      debugPrint(
        'backgroundRefreshDispatcher: refreshed ${tasks.length} tasks '
        '($taskName)',
      );
      return true;
    } catch (e) {
      debugPrint('backgroundRefreshDispatcher failed: $e');
      return false; // let WorkManager retry with backoff
    } finally {
      await db.close();
    }
  });
}

/// Registers the periodic refresh with WorkManager. Android-only; everywhere
/// else (web, desktop, tests) this is a silent no-op — reminders themselves
/// are already off there, so there is no schedule to keep fresh.
///
/// Called from `main()` after `runApp`, unawaited: registration must never
/// block or break startup, hence the broad catch.
Future<void> registerBackgroundRefresh() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Workmanager().initialize(backgroundRefreshDispatcher);
    await Workmanager().registerPeriodicTask(
      backgroundRefreshUniqueName,
      backgroundRefreshTaskName,
      frequency: const Duration(hours: 12),
      // Keep the existing cadence; re-registering on every launch must not
      // reset the 12h clock.
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } catch (e) {
    // No WorkManager runtime (unit tests, misconfigured device) — the
    // foreground sync still re-fills the schedule on every app open.
    debugPrint('registerBackgroundRefresh failed: $e');
  }
}

/// Fire the same refresh once, promptly — the debug menu's test hook.
/// WorkManager refuses to force-run a *periodic* worker before its first
/// window, so a one-off through the same dispatcher is the only way to
/// exercise the background path on demand.
Future<void> runBackgroundRefreshOnce() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Workmanager().registerOneOffTask(
      '$backgroundRefreshUniqueName-once',
      backgroundRefreshTaskName,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  } catch (e) {
    debugPrint('runBackgroundRefreshOnce failed: $e');
  }
}
