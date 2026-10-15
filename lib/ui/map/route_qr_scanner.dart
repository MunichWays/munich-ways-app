import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:munich_ways/api/route_transfer_io.dart';
import 'package:munich_ways/localization/app_localizations.dart';

Future<Uri?> showRouteQrScanner(BuildContext context) async {
  final route = MaterialPageRoute<Uri>(
      fullscreenDialog: true, builder: (_) => const RouteQrScanner());
  final result = await Navigator.of(context).push(route);
  // Dismiss the camera surface before loading the snapshot and its preview.
  await route.completed;
  return result;
}

class RouteQrScanner extends StatefulWidget {
  const RouteQrScanner({super.key});
  @override
  State<RouteQrScanner> createState() => _RouteQrScannerState();
}

class _RouteQrScannerState extends State<RouteQrScanner>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
      autoStart: false, formats: const [BarcodeFormat.qrCode]);
  Future<void> _cameraWork = Future.value();
  bool _closing = false;
  bool _wantCamera = true;
  String? _error;
  bool get _english => context.l10n.isEnglish;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_closing) unawaited(_updateCamera());
    });
  }

  // Serialize permission/start/stop operations, including rapid lifecycle
  // changes and closing while the initial permission request is still pending.
  Future<void> _updateCamera() => _cameraWork = _cameraWork.then((_) async {
        if (_closing || !_wantCamera) {
          await _controller.stop();
        } else {
          await _controller.start();
        }
      }).catchError((Object error) {
        if (mounted && !_closing)
          setState(() => _error = _english
              ? 'The camera could not be opened. Go back and paste the route link.'
              : 'Die Kamera konnte nicht geöffnet werden. Gehe zurück und füge den Routenlink ein.');
      });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_closing) return;
    if (state == AppLifecycleState.resumed) {
      _wantCamera = true;
      // Permission dialogs can resume before the initial request finishes.
      if (_controller.value.hasCameraPermission) unawaited(_updateCamera());
    } else if (state != AppLifecycleState.inactive ||
        _controller.value.hasCameraPermission) {
      _wantCamera = false;
      unawaited(_updateCamera());
    }
  }

  Future<void> _finish([Uri? uri]) async {
    if (_closing) return;
    setState(() => _closing = true);
    _wantCamera = false;
    await _updateCamera();
    try {
      await _controller.dispose();
    } catch (_) {
      debugPrint('QR scanner cleanup failed');
    }
    if (mounted) Navigator.pop(context, uri);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closing = true;
    _wantCamera = false;
    unawaited(_cameraWork.then((_) async {
      await _controller.stop();
      await _controller.dispose();
    }).catchError((Object error) {
      debugPrint('QR scanner cleanup failed');
    }));
    super.dispose();
  }

  void _detected(BarcodeCapture capture) {
    if (_closing || !mounted || ModalRoute.of(context)?.isCurrent != true)
      return;
    for (final barcode in capture.barcodes) {
      if (barcode.format != BarcodeFormat.qrCode || barcode.rawValue == null)
        continue;
      final uri = RouteTransferIo.parseLink(barcode.rawValue!);
      if (uri != null) {
        unawaited(_finish(uri));
        return;
      }
    }
    final message = _english
        ? 'This is not a RadlNavi route QR code. Scan the code shown under “Open in app / share”.'
        : 'Das ist kein RadlNavi-Routen-QR-Code. Scanne den Code aus „In App öffnen / teilen“.';
    if (_error != message) setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) => PopScope<Uri>(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_finish());
      },
      child: Scaffold(
        appBar: AppBar(
            title: Text(
                _english ? 'Scan route QR code' : 'Routen-QR-Code scannen')),
        body: SafeArea(
            child: Column(children: [
          Expanded(
              flex: 3,
              child: _closing
                  ? const Center(child: CircularProgressIndicator())
                  : MobileScanner(
                      controller: _controller,
                      useAppLifecycleState: false,
                      // This screen owns camera lifecycle and releases it before returning.
                      onDetect: _detected,
                      errorBuilder: (context, error) => ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                          child: Center(
                              child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                            Icons.no_photography_outlined,
                                            size: 48),
                                        const SizedBox(height: 16),
                                        Text(error.errorCode ==
                                                MobileScannerErrorCode
                                                    .permissionDenied
                                            ? (_english
                                                ? 'Allow camera access in your device settings to scan QR codes. You can also paste the route link.'
                                                : 'Erlaube den Kamerazugriff in den Geräteeinstellungen, um QR-Codes zu scannen. Alternativ kannst du den Routenlink einfügen.')
                                            : (_english
                                                ? 'The camera could not be opened. Try again or paste the route link.'
                                                : 'Die Kamera konnte nicht geöffnet werden. Versuche es erneut oder füge den Routenlink ein.')),
                                        const SizedBox(height: 12),
                                        OutlinedButton(
                                            onPressed: _closing
                                                ? null
                                                : () {
                                                    setState(
                                                        () => _error = null);
                                                    _wantCamera = true;
                                                    unawaited(_updateCamera());
                                                  },
                                            child: Text(_english
                                                ? 'Try again'
                                                : 'Erneut versuchen')),
                                      ])))),
                    )),
          Flexible(
              child: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(_english
                                ? 'Point the camera at the route QR code on your computer.'
                                : 'Richte die Kamera auf den Routen-QR-Code am PC.'),
                            if (_error != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Semantics(
                                      liveRegion: true,
                                      child: Text(_error!,
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error)))),
                            TextButton(
                                onPressed: _closing ? null : () => _finish(),
                                child: Text(_english
                                    ? 'Paste link instead'
                                    : 'Stattdessen Link einfügen')),
                          ])))),
        ])),
      ));
}
