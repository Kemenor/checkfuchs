import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/db/database.dart';
import 'data/repositories/task_repository.dart';
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
