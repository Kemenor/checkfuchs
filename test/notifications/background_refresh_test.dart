import 'package:checkfuchs/notifications/background_refresh.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// The real background pass needs the Android WorkManager runtime — there is
// nothing platform-free to execute here. What *is* testable is the startup
// contract: registerBackgroundRefresh() must never throw, on any platform,
// with or without a plugin runtime (main() calls it fire-and-forget; a leaked
// error there would surface as an unhandled zone error in production).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('registration is a silent no-op on non-Android platforms', () async {
    for (final platform in TargetPlatform.values) {
      if (platform == TargetPlatform.android) continue;
      debugDefaultTargetPlatformOverride = platform;
      await expectLater(registerBackgroundRefresh(), completes);
    }
  });

  test(
    'registration swallows a missing WorkManager runtime on Android',
    () async {
      // In the test environment there is no platform implementation behind the
      // plugin; the internal catch must absorb that instead of breaking startup.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await expectLater(registerBackgroundRefresh(), completes);
    },
  );
}
