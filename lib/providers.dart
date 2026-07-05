import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart' show FuchsbauFont;

import 'data/db/database.dart';
import 'data/repositories/task_repository.dart';
import 'data/repositories/view_repository.dart';
import 'domain/clock.dart';
import 'domain/task.dart';

/// The injected clock — overridden with a [FixedClock] in tests.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// The on-device database. Overridden with an in-memory database in tests.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(databaseProvider)),
);

/// The reactive task stream — drift re-emits on every write, so this is the
/// single source the UI watches.
final tasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(taskRepositoryProvider).watchTasks(),
);

final vacationsProvider = StreamProvider<List<VacationRow>>(
  (ref) => ref.watch(taskRepositoryProvider).watchVacations(),
);

final viewRepositoryProvider = Provider<ViewRepository>(
  (ref) => ViewRepository(ref.watch(databaseProvider)),
);

final viewsProvider = StreamProvider<List<ViewRow>>(
  (ref) => ref.watch(viewRepositoryProvider).watchViews(),
);

/// The rendered state of a View — its lenses' projected tasks (design §4).
///
/// Every DB emission is projected against a fresh `clock.now()` (inside
/// `watchViewState`), and each emitted state arms **one timer** to its
/// `nextTransition` (window edge / rollover / midnight, PLAN "foreground time
/// advance"). When it fires we reconcile — whose writes re-emit the stream —
/// and invalidate as a fallback for the no-write case. So the surface never
/// goes stale just because time passed. autoDispose: closed views drop their
/// stream subscription and pending timer.
final viewStateProvider = StreamProvider.autoDispose.family<ViewState?, int>((
  ref,
  viewId,
) {
  final clock = ref.watch(clockProvider);
  final taskRepo = ref.watch(taskRepositoryProvider);
  final viewRepo = ref.watch(viewRepositoryProvider);

  Timer? timer;
  ref.onDispose(() => timer?.cancel());

  return viewRepo.watchViewState(viewId, clock).map((vs) {
    timer?.cancel();
    if (vs != null) {
      var delay =
          vs.nextTransition.difference(clock.now()) +
          const Duration(seconds: 1);
      if (delay.isNegative) delay = Duration.zero;
      timer = Timer(delay, () async {
        final now = clock.now();
        await taskRepo.reconcileAll(now);
        await viewRepo.refreshSurfaced(now);
        ref.invalidateSelf();
      });
    }
    return vs;
  });
});

// --- settings (Phase 8) ------------------------------------------------------

/// User settings — theme override + typeface (the Fuchsbau accessibility picker).
class Settings {
  const Settings({
    this.themeMode = ThemeMode.system,
    this.font = FuchsbauFont.figtree,
  });
  final ThemeMode themeMode;
  final FuchsbauFont font;

  Settings copyWith({ThemeMode? themeMode, FuchsbauFont? font}) =>
      Settings(themeMode: themeMode ?? this.themeMode, font: font ?? this.font);
}

/// Loads the singleton settings row once (no drift *watch* → no widget-test
/// timer), holds it, and persists changes.
class SettingsController extends Notifier<Settings> {
  /// Set on the first user change; a still-in-flight [_load] must not clobber
  /// a fresher choice with the stale stored row.
  bool _touched = false;

  @override
  Settings build() {
    _touched = false;
    _load();
    return const Settings();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final row = await db.select(db.appSettings).getSingleOrNull();
    if (row != null && !_touched) {
      state = Settings(
        themeMode: ThemeMode.values[row.themeModeIndex.clamp(0, 2)],
        font: FuchsbauFont
            .values[row.fontIndex.clamp(0, FuchsbauFont.values.length - 1)],
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _touched = true;
    state = state.copyWith(themeMode: mode);
    await _persist();
  }

  Future<void> setFont(FuchsbauFont font) async {
    _touched = true;
    state = state.copyWith(font: font);
    await _persist();
  }

  Future<void> _persist() async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(
            id: const Value(1),
            themeModeIndex: Value(state.themeMode.index),
            fontIndex: Value(state.font.index),
          ),
        );
  }
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);
