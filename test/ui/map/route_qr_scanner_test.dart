import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:munich_ways/ui/map/route_import_source_dialog.dart';
import 'package:munich_ways/ui/map/route_qr_scanner.dart';

class _Camera extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture>.broadcast();
  int starts = 0, stops = 0, disposals = 0;
  MobileScannerException? failure;
  Completer<MobileScannerViewAttributes>? startup;
  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    if (failure != null) throw failure!;
    if (startup != null) return startup!.future;
    return const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.unavailable,
        size: Size(200, 200),
        numberOfCameras: 1);
  }

  @override
  Widget buildCameraView() => const SizedBox.square(dimension: 200);
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }

  void qr(String text) => captures.add(BarcodeCapture(
      barcodes: [Barcode(format: BarcodeFormat.qrCode, rawValue: text)]));
}

void main() {
  late _Camera camera;
  setUp(() {
    final previous = MobileScannerPlatform.instance;
    camera = _Camera();
    MobileScannerPlatform.instance = camera;
    addTearDown(() async {
      MobileScannerPlatform.instance = previous;
      await camera.captures.close();
    });
  });
  final url = 'https://radlnavi.munichways.de/r/${'a' * 32}';

  Future<void> open(WidgetTester tester, void Function(Uri?) done) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async =>
                        done(await showRouteQrScanner(context)),
                    child: const Text('Scan'))))));
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
  }

  testWidgets('opening import chooser never starts or requests the camera',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RouteImportSourceDialog())));
    await tester.pumpAndSettle();
    expect(camera.starts, 0);
    expect(find.byType(MobileScanner), findsNothing);
  });

  testWidgets(
      'foreign QR stays in scanner; valid duplicate capture completes exactly once and releases camera',
      (tester) async {
    var callbacks = 0;
    Uri? selected;
    await open(tester, (value) {
      callbacks++;
      selected = value;
    });
    camera.qr('https://evil.invalid/r/${'a' * 32}');
    await tester.pumpAndSettle();
    expect(callbacks, 0);
    expect(find.textContaining('kein RadlNavi'), findsOneWidget);
    camera.qr(url);
    camera.qr(url);
    await tester.pumpAndSettle();
    expect(callbacks, 1);
    expect(selected, Uri.parse(url));
    await tester.pump();
    expect(camera.stops, 1);
    expect(camera.disposals, 1);
  });

  testWidgets(
      'retry after camera error can scan without reopening the importer',
      (tester) async {
    camera.failure = const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied);
    Uri? selected;
    await open(tester, (value) => selected = value);
    camera.failure = null;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    camera.qr(url);
    await tester.pumpAndSettle();
    expect(selected, Uri.parse(url));
    expect(camera.stops, 1);
    expect(camera.disposals, 1);
  });

  testWidgets(
      'closing during camera startup stops a late successful camera before returning',
      (tester) async {
    camera.startup = Completer<MobileScannerViewAttributes>();
    var callbacks = 0;
    await open(tester, (value) {
      expect(value, isNull);
      callbacks++;
    });
    await tester.tap(find.text('Stattdessen Link einfügen'));
    await tester.pump();
    expect(callbacks, 0);
    camera.startup!.complete(const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.unavailable,
        size: Size(200, 200),
        numberOfCameras: 1));
    await tester.pumpAndSettle();
    expect(callbacks, 1);
    expect(camera.stops, 1);
    expect(camera.disposals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'denied camera offers link fallback; reopening can recover and pause/resume',
      (tester) async {
    camera.failure = const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied);
    Uri? selected;
    await open(tester, (value) => selected = value);
    expect(find.textContaining('Geräteeinstellungen'), findsOneWidget);
    await tester.tap(find.text('Stattdessen Link einfügen'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    camera.failure = null;
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    final starts = camera.starts;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    await tester.pump();
    expect(camera.stops, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(camera.starts, starts + 1);
    camera.qr(url);
    await tester.pumpAndSettle();
    expect(selected, Uri.parse(url));
    await tester.pump();
    expect(camera.stops, 2);
    expect(tester.takeException(), isNull);
  });
}
