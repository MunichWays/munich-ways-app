import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:munich_ways/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:munich_ways/screenshots/store_screenshot_config.dart';

/// App Store marketing screenshots (iOS Simulator).
///
/// Run from repo root:
/// ```sh
/// flutter test integration_test/screenshots_test.dart -d <SimulatorId> \
///   --dart-define=STORE_SCREENSHOTS=true
/// ```
///
/// On iOS, PNGs are written under **`Library/Caches/store_screenshots/`** inside the
/// app data container (`getApplicationCacheDirectory()` — same location as
/// `getTemporaryDirectory()` on iOS). The `ios screenshots` lane pulls them into
/// `integration_test/screenshots/`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture three App Store screenshots', (tester) async {
    if (!kStoreScreenshots) {
      fail(
        'Re-run with --dart-define=STORE_SCREENSHOTS=true so semantics and '
        'controls are compiled in.',
      );
    }
    if (!Platform.isIOS) {
      // takeScreenshot is supported on iOS/Android; Fastlane workflow targets iOS.
      fail('Run on an iOS Simulator (flutter devices).');
    }

    app.main();
    await tester.pump();

    await _pumpUntilFound(
      tester,
      find.bySemanticsLabel(StoreScreenshotSemantics.mapIdleReady),
      timeout: const Duration(seconds: 180),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await _writePngScreenshot('01_map_idle');

    await tester.tap(
      find.bySemanticsLabel(StoreScreenshotSemantics.triggerRoute),
    );
    await tester.pump();

    await _pumpUntilFound(
      tester,
      find.bySemanticsLabel(StoreScreenshotSemantics.routeReady),
      timeout: const Duration(seconds: 120),
    );
    await tester.pump(const Duration(seconds: 2));

    await _writePngScreenshot('02_route_active');

    await tester.tap(
      find.bySemanticsLabel(StoreScreenshotSemantics.triggerStreet),
    );
    await tester.pump();
    // Let the bottom sheet route + opening animation run before polling for text.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // `find.bySemanticsLabel` is unreliable inside `showModalBottomSheet` overlays
    // on device integration tests — wait for copy that matches [storeScreenshotStreetDetails].
    final fixture = storeScreenshotStreetDetails();
    final sheetMarker = (fixture.name?.trim().isNotEmpty ?? false)
        ? fixture.name!
        : fixture.munichwaysId;
    if (sheetMarker == null || sheetMarker.isEmpty) {
      fail(
        'storeScreenshotStreetDetails() needs a non-empty `name` or `munichwaysId` '
        'so this test can detect the street details sheet.',
      );
    }
    await _pumpUntilFound(
      tester,
      find.textContaining(sheetMarker),
      timeout: const Duration(seconds: 60),
    );
    await tester.pump(const Duration(milliseconds: 800));

    await _writePngScreenshot('03_street_details');
  });
}

/// Persists PNG bytes from [IntegrationTestWidgetsFlutterBinding.takeScreenshot].
///
/// On iOS the test runs in the app sandbox; relative repo paths are read-only.
/// Use the app cache dir so Fastlane can copy from `Library/Caches/store_screenshots/`.
Future<void> _writePngScreenshot(String name) async {
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  final bytes = await binding.takeScreenshot(name);
  final Directory dir;
  if (Platform.isIOS) {
    final cache = await getApplicationCacheDirectory();
    dir = Directory('${cache.path}/store_screenshots');
  } else {
    dir = Directory('integration_test/screenshots');
  }
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final file = File('${dir.path}/$name.png');
  await file.writeAsBytes(bytes, flush: true);
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  required Duration timeout,
}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  throw TestFailure('Timeout after ${timeout.inSeconds}s waiting for $finder');
}
