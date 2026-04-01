import 'dart:math' as math;
import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:munich_ways/model/place.dart';
import 'package:vector_math/vector_math.dart' as vector_math;

/// Same chrome insets as the legacy off-screen destination arrow: clear of app bar
/// and bottom actions.
/// clear of app bar and bottom action stack.
class _MapChromeInsets {
  static const double top = 66;
  static const double bottom = 54;

  static EdgeInsets of(BuildContext context) {
    final mq = MediaQuery.paddingOf(context);
    return EdgeInsets.fromLTRB(
      mq.left,
      mq.top + top,
      mq.right,
      mq.bottom + bottom,
    );
  }
}

/// Edge indicator when [destination] projects outside the map view (MapLibre).
/// Coordinates from [MapLibreMapController.toScreenLocation] match a [Positioned.fill]
/// layer directly above the map.
class MapLibreDestinationOffScreenOverlay extends StatefulWidget {
  const MapLibreDestinationOffScreenOverlay({
    super.key,
    required this.controller,
    required this.destination,
    this.imageAssetPath = 'images/bearing_arrow.png',
  });

  final MapLibreMapController? controller;
  final Place destination;
  final String imageAssetPath;

  @override
  State<MapLibreDestinationOffScreenOverlay> createState() =>
      _MapLibreDestinationOffScreenOverlayState();
}

class _MapLibreDestinationOffScreenOverlayState
    extends State<MapLibreDestinationOffScreenOverlay> {
  ui.Image? _image;
  Offset? _destinationScreen;
  int _requestGen = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
    widget.controller?.addListener(_onControllerUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshScreenPoint());
  }

  @override
  void didUpdateWidget(
      covariant MapLibreDestinationOffScreenOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerUpdate);
      widget.controller?.addListener(_onControllerUpdate);
      _refreshScreenPoint();
    }
    if (oldWidget.destination != widget.destination ||
        oldWidget.imageAssetPath != widget.imageAssetPath) {
      if (oldWidget.imageAssetPath != widget.imageAssetPath) {
        _loadImage();
      }
      _refreshScreenPoint();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerUpdate);
    super.dispose();
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load(widget.imageAssetPath);
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final decoded = await decodeImageFromList(bytes);
    if (mounted) setState(() => _image = decoded);
  }

  void _onControllerUpdate() {
    if (widget.controller?.isDisposed ?? true) return;
    _refreshScreenPoint();
  }

  Future<void> _refreshScreenPoint() async {
    final c = widget.controller;
    if (!mounted || c == null || c.isDisposed) return;

    final gen = ++_requestGen;
    try {
      final p = await c.toScreenLocation(
        LatLng(
          widget.destination.latLng.latitude,
          widget.destination.latLng.longitude,
        ),
      );
      if (!mounted || gen != _requestGen) return;
      setState(() {
        _destinationScreen = Offset(p.x.toDouble(), p.y.toDouble());
      });
    } catch (_) {
      if (!mounted || gen != _requestGen) return;
      setState(() => _destinationScreen = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    final offset = _destinationScreen;
    if (img == null || offset == null) {
      return const SizedBox.expand();
    }
    return CustomPaint(
      painter: _OffscreenDestinationPainter(
        destinationOffset: offset,
        image: img,
        mapInsets: _MapChromeInsets.of(context),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _OffscreenDestinationPainter extends CustomPainter {
  _OffscreenDestinationPainter({
    required this.destinationOffset,
    required this.image,
    required this.mapInsets,
  });

  final Offset destinationOffset;
  final ui.Image image;
  final EdgeInsets mapInsets;

  /// Ray from [center] toward [target]; returns positive [t] hit on the map rect.
  static Offset? _borderHit(Offset center, Offset target, Size size) {
    final dx = target.dx - center.dx;
    final dy = target.dy - center.dy;
    if (dx.abs() < 1e-9 && dy.abs() < 1e-9) return null;

    double? minT;

    void considerT(double t) {
      if (t <= 0 || !t.isFinite) return;
      minT = minT == null ? t : math.min(minT!, t);
    }

    void tryVertical(double edgeX) {
      if (dx.abs() < 1e-12) return;
      final t = (edgeX - center.dx) / dx;
      final y = center.dy + t * dy;
      if (y >= -1e-3 && y <= size.height + 1e-3) considerT(t);
    }

    void tryHorizontal(double edgeY) {
      if (dy.abs() < 1e-12) return;
      final t = (edgeY - center.dy) / dy;
      final x = center.dx + t * dx;
      if (x >= -1e-3 && x <= size.width + 1e-3) considerT(t);
    }

    tryVertical(0);
    tryVertical(size.width);
    tryHorizontal(0);
    tryHorizontal(size.height);

    final t = minT;
    if (t == null) return null;
    return Offset(
      (center.dx + t * dx).clamp(0.0, size.width),
      (center.dy + t * dy).clamp(0.0, size.height),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final offset = destinationOffset;
    final center = Offset(size.width / 2, size.height / 2);

    final isOffScreen = offset.dx < 0 ||
        offset.dx > size.width ||
        offset.dy < 0 ||
        offset.dy > size.height;

    if (!isOffScreen) return;

    final border = _borderHit(center, offset, size);
    if (border == null) return;

    final topPad = mapInsets.top;
    final bottomPad = mapInsets.bottom;
    final y = math.min(
      math.max(topPad, border.dy),
      size.height - bottomPad,
    );
    final pointOnScreenBorder = Offset(border.dx, y);

    final paint = Paint()..filterQuality = FilterQuality.medium;

    canvas.save();
    canvas.translate(pointOnScreenBorder.dx, pointOnScreenBorder.dy);

    var angle = math.atan2(
      pointOnScreenBorder.dy - center.dy,
      pointOnScreenBorder.dx - center.dx,
    );
    if (angle < 0) angle += 2 * math.pi;
    canvas.rotate(angle + vector_math.radians(90));
    canvas.drawImage(
      image,
      Offset(-(image.width / 2).toDouble(), 0),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OffscreenDestinationPainter oldDelegate) {
    return oldDelegate.destinationOffset != destinationOffset ||
        oldDelegate.image != image ||
        oldDelegate.mapInsets != mapInsets;
  }
}
