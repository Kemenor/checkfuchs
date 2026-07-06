import 'package:checkfuchs/l10n/app_localizations.dart';
import 'package:checkfuchs/ui/when_label.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  final l10n = lookupAppLocalizations(const Locale('en'));
  final now = DateTime(2026, 7, 6, 15); // Monday afternoon
  String at(DateTime t, {bool isEnd = false}) =>
      whenLabel(l10n, 'en', now, t, isEnd: isEnd);

  test('today with a time → clock time', () {
    expect(at(DateTime(2026, 7, 6, 18)), '18:00');
    expect(at(DateTime(2026, 7, 6, 17), isEnd: true), '17:00');
  });

  test('an end at midnight belongs to the evening before', () {
    // Evening habit window ends 07-07 00:00 → due "Today", never "00:00".
    expect(at(DateTime(2026, 7, 7), isEnd: true), 'Today');
  });

  test('a start at midnight tomorrow → Tomorrow', () {
    expect(at(DateTime(2026, 7, 7)), 'Tomorrow');
  });

  test('tomorrow with a time still reads as Tomorrow', () {
    expect(at(DateTime(2026, 7, 7, 18), isEnd: true), 'Tomorrow');
  });

  test('within the week → short weekday; beyond → short date', () {
    expect(at(DateTime(2026, 7, 11)), 'Sat');
    expect(at(DateTime(2026, 7, 20)), 'Jul 20');
  });

  test('already past today → still the clock time', () {
    expect(at(DateTime(2026, 7, 6, 12), isEnd: true), '12:00');
  });
}
