import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/recurrence.dart';
import '../../domain/window_rule.dart';

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
      'untilNext' => const UntilNextOccurrence(),
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
    UntilNextOccurrence() => jsonEncode({'kind': 'untilNext'}),
  };
}
