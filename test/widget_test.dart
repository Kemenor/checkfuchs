import 'package:checkfuchs/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to the empty home state', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CheckfuchsApp()));
    await tester.pumpAndSettle();

    // App bar title + the empty-state copy (en, the default test locale).
    expect(find.text('Checkfuchs'), findsWidgets);
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });
}
