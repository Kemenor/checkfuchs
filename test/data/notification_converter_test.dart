import 'package:checkfuchs/data/db/converters.dart';
import 'package:checkfuchs/domain/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const conv = NotificationListConverter();

  test('round-trips an empty list (the column default)', () {
    expect(conv.fromSql(conv.toSql(const [])), isEmpty);
    expect(conv.fromSql('[]'), isEmpty);
  });

  test('round-trips every anchor kind with offsets', () {
    final list = [
      const TaskNotification.atStart(),
      const TaskNotification.atStart(offset: Duration(days: -1)),
      const TaskNotification.atEnd(offset: Duration(hours: -2)),
      TaskNotification.absolute(DateTime(2026, 7, 6, 18, 30)),
    ];
    expect(conv.fromSql(conv.toSql(list)), list);
  });
}
