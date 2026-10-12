import 'package:drift/drift.dart';

import '../../domain/task.dart' as domain;
import 'converters.dart';
import 'database.dart';

/// Row ⇄ domain Task — the one mapping every repository shares, so a new
/// column can't reach one screen and silently miss another.
domain.Task taskFromRow(TaskRow r) => domain.Task(
  id: r.id,
  templateId: r.templateId,
  occurrence: r.occurrence,
  name: r.name,
  note: r.note,
  status: r.status,
  start: r.windowStart,
  end: r.windowEnd,
  createdAt: r.createdAt,
  resolvedAt: r.resolvedAt,
  notifications: r.notifications,
  bands: bandsFromSql(r.windowBands),
  goal: r.goal,
  checkIns: r.checkIns,
);

TasksCompanion taskToCompanion(domain.Task t) => TasksCompanion(
  id: t.id == null ? const Value.absent() : Value(t.id!),
  templateId: Value(t.templateId),
  occurrence: Value(t.occurrence),
  name: Value(t.name),
  note: Value(t.note),
  status: Value(t.status),
  windowStart: Value(t.start),
  windowEnd: Value(t.end),
  createdAt: Value(t.createdAt),
  resolvedAt: Value(t.resolvedAt),
  notifications: Value(t.notifications),
  windowBands: Value(bandsToSql(t.bands)),
  goal: Value(t.goal),
  checkIns: Value(t.checkIns),
);
