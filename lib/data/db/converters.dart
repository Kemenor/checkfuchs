import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/goal.dart';
import '../../domain/notification.dart';
import '../../domain/recurrence.dart';
import '../../domain/window_rule.dart';

/// Stores a Task's/Template's reminder list as a JSON text column.
class NotificationListConverter
    extends TypeConverter<List<TaskNotification>, String> {
  const NotificationListConverter();

  @override
  List<TaskNotification> fromSql(String fromDb) {
    final list = jsonDecode(fromDb) as List;
    return [
      for (final e in list.cast<Map<String, dynamic>>())
        TaskNotification(
          anchor: NotificationAnchor.values[e['anchor'] as int],
          offset: Duration(microseconds: (e['offset'] as int?) ?? 0),
          at: e['at'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(e['at'] as int),
        ),
    ];
  }

  @override
  String toSql(List<TaskNotification> value) => jsonEncode([
    for (final n in value)
      {
        'anchor': n.anchor.index,
        'offset': n.offset.inMicroseconds,
        'at': n.at?.millisecondsSinceEpoch,
      },
  ]);
}

/// Stores a [Goal] as a JSON text column. Missing keys take the 1-of-1
/// defaults, so the column default `'{}'` is an ordinary habit; `max` is
/// told apart from "no limit" by the key's presence (`"max": null`).
class GoalConverter extends TypeConverter<Goal, String> {
  const GoalConverter();

  @override
  Goal fromSql(String fromDb) {
    final m = jsonDecode(fromDb) as Map<String, dynamic>;
    final min = (m['min'] as int?) ?? 1;
    return Goal(
      min: min,
      max: m.containsKey('max') ? m['max'] as int? : min,
      oncePerDay: (m['oncePerDay'] as bool?) ?? false,
      remindTill: RemindTill.values[(m['remindTill'] as int?) ?? 0],
    );
  }

  @override
  String toSql(Goal value) => value == Goal.single
      ? '{}'
      : jsonEncode({
          'min': value.min,
          'max': value.max,
          'oncePerDay': value.oncePerDay,
          'remindTill': value.remindTill.index,
        });
}

/// Stores a Task's check-ins as a JSON list of epoch milliseconds.
class CheckInListConverter extends TypeConverter<List<DateTime>, String> {
  const CheckInListConverter();

  @override
  List<DateTime> fromSql(String fromDb) => [
    for (final ms in (jsonDecode(fromDb) as List).cast<int>())
      DateTime.fromMillisecondsSinceEpoch(ms),
  ];

  @override
  String toSql(List<DateTime> value) =>
      jsonEncode([for (final d in value) d.millisecondsSinceEpoch]);
}

/// Stores a [Recurrence] as a JSON text column.
class RecurrenceConverter extends TypeConverter<Recurrence, String> {
  const RecurrenceConverter();

  @override
  Recurrence fromSql(String fromDb) {
    final m = jsonDecode(fromDb) as Map<String, dynamic>;
    return Recurrence(
      freq: Freq.values[m['freq'] as int],
      interval: m['interval'] as int,
      anchor: DateTime.fromMillisecondsSinceEpoch(m['anchor'] as int),
      byWeekday: (m['byWeekday'] as List)
          .cast<int>()
          .map((i) => Weekday.values[i])
          .toSet(),
      byMonthDay: m['byMonthDay'] as int?,
      byMonth: m['byMonth'] as int?,
      // `until` arrived with end dates; older rows repeat forever.
      until: m['until'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(m['until'] as int),
    );
  }

  @override
  String toSql(Recurrence value) => jsonEncode({
    'freq': value.freq.index,
    'interval': value.interval,
    'anchor': value.anchor.millisecondsSinceEpoch,
    'byWeekday': value.byWeekday.map((w) => w.index).toList(),
    'byMonthDay': value.byMonthDay,
    'byMonth': value.byMonth,
    if (value.until != null) 'until': value.until!.millisecondsSinceEpoch,
  });
}

/// Stores a [WindowRule] (sealed) as a JSON text column with a `kind` tag.
class WindowRuleConverter extends TypeConverter<WindowRule, String> {
  const WindowRuleConverter();

  @override
  WindowRule fromSql(String fromDb) {
    final m = jsonDecode(fromDb) as Map<String, dynamic>;
    return switch (m['kind'] as String) {
      'slice' => Slice(
        from: Duration(microseconds: m['from'] as int),
        to: Duration(microseconds: m['to'] as int),
      ),
      'duration' => FixedDuration(Duration(microseconds: m['length'] as int)),
      'untilNext' => switch (decodeBands(m['bands'])) {
        null => const UntilNextOccurrence(),
        final bands => UntilNextOccurrence.withBands(bands),
      },
      // `days` arrived with multi-day bands; older rows are one-day.
      'multi' => MultiSlice(
        decodeBands(m['bands'])!,
        days: (m['days'] as int?) ?? 1,
      ),
      // Fail loudly: silently mapping an unknown kind to a default would mask
      // data corruption (or a forgotten migration) as a behaviour change.
      final kind => throw FormatException('Unknown WindowRule kind: $kind'),
    };
  }

  @override
  String toSql(WindowRule value) => switch (value) {
    Slice(:final from, :final to) => jsonEncode({
      'kind': 'slice',
      'from': from.inMicroseconds,
      'to': to.inMicroseconds,
    }),
    FixedDuration(:final length) => jsonEncode({
      'kind': 'duration',
      'length': length.inMicroseconds,
    }),
    UntilNextOccurrence(:final bands) => jsonEncode({
      'kind': 'untilNext',
      if (bands != null) 'bands': encodeBands(bands),
    }),
    MultiSlice(:final bands, :final days) => jsonEncode({
      'kind': 'multi',
      'bands': encodeBands(bands),
      'days': days,
    }),
  };
}

/// Bands as a JSON list of `[fromMicros, toMicros]` pairs (the shape shared
/// by the `multi` window rule and `tasks.window_bands`).
List<List<int>>? encodeBands(List<Band>? bands) => bands == null
    ? null
    : [
        for (final b in bands) [b.from.inMicroseconds, b.to.inMicroseconds],
      ];

List<Band>? decodeBands(Object? json) => json == null
    ? null
    : [
        for (final pair in (json as List).cast<List>())
          Band(
            from: Duration(microseconds: pair[0] as int),
            to: Duration(microseconds: pair[1] as int),
          ),
      ];

/// `tasks.window_bands` text ⇄ [Band] list.
String? bandsToSql(List<Band>? bands) =>
    bands == null ? null : jsonEncode(encodeBands(bands));

List<Band>? bandsFromSql(String? text) =>
    text == null ? null : decodeBands(jsonDecode(text));
