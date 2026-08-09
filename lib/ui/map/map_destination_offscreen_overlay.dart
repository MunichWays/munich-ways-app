import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_layout_constants.dart';
import 'package:vector_math/vector_math.dart' as vector_math;

/// Edge indicator when [destination] projects outside the map view.
///
/// [mapLayerKey] must wrap the [MapLibreMap] so [toScreenLocation] coordinates can
/// be converted into this overlay's layout (e.g. when the arrow is drawn only below
/// the navigation header without hard-coding header height).
class MapDestinationOffScreenOverlay extends StatefulWidget {
  const MapDestinationOffScreenOverlay({
    super.key,
    required this.mapLayerKey,
    required this.controller,
    required this.destination,
    this.bottomActionRowPadding = kMapBottomActionRowCollapsedPadding,
    this.imageAssetPath = 'images/bearing_arrow.png',
  });

  final GlobalKey mapLayerKey;
  final MapLibreMapController? controller;
  final Place destination;
  final double bottomActionRowPadding;
  final String imageAssetPath;

  @override
  State<MapDestinationOffScreenOverlay> createState() =>
      _MapDestinationOffScreenOverlayState();
}

class _MapDestinationOffScreenOverlayState
    extends State<MapDestinationOffScreenOverlay> {
  ui.Image? _image;
  Offset? _destinationMapLocal;
  Offset? _destinationOverlay;
  Rect? _mapRectInOverlay;

  /// True while a [toScreenLocation] platform-channel call is outstanding.
  bool _refreshInFlight = false;

  /// Set to true when the camera moved while a call was in flight, so we
  /// immediately start another refresh once the current one completes.
  bool _refreshQueued = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
    widget.controller?.addListener(_onControllerUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScreenPoint();
    });
  }

  @override
  void didUpdateWidget(covariant MapDestinationOffScreenOverlay oldWidget) {
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
    if (oldWidget.mapLayerKey != widget.mapLayerKey) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _recomputeOverlayCoords());
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
    if (_refreshInFlight) {
      // A toScreenLocation call is already running. Mark that we need another
      // refresh after it completes so we always end up with the latest position.
      _refreshQueued = true;
    } else {
      _refreshScreenPoint();
    }
  }

  Future<void> _refreshScreenPoint() async {
    final c = widget.controller;
    if (!mounted || c == null || c.isDisposed) return;

    _refreshInFlight = true;
    _refreshQueued = false;
    try {
      final p = await c.toScreenLocation(
        LatLng(
          widget.destination.latLng.latitude,
          widget.destination.latLng.longitude,
        ),
      );
      if (!mounted) return;
      // toScreenLocation() returns physical pixels on Android but logical
      // pixels on iOS. Flutter layout (RenderBox) works in logical pixels, so
      // divide by the device pixel ratio on Android only.
      final double scale =
          Platform.isAndroid ? MediaQuery.devicePixelRatioOf(context) : 1.0;
      setState(() {
        _destinationMapLocal = Offset(
          p.x.toDouble() / scale,
          p.y.toDouble() / scale,
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recomputeOverlayCoords();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _destinationMapLocal = null;
        _destinationOverlay = null;
        _mapRectInOverlay = null;
      });
    } finally {
      _refreshInFlight = false;
      // If the camera moved while the call was in flight, immediately fetch
      // the latest position so the arrow stays in sync.
      if (_refreshQueued && mounted) {
        _refreshScreenPoint();
      }
    }
  }

  void _recomputeOverlayCoords() {
    final mapLocal = _destinationMapLocal;
    final mapCtx = widget.mapLayerKey.currentContext;
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (mapLocal == null ||
        mapCtx == null ||
        overlayBox == null ||
        !overlayBox.hasSize) {
      return;
    }
    final mapBox = mapCtx.findRenderObject() as RenderBox?;
    if (mapBox == null ||
        !mapBox.hasSize ||
        !mapBox.attached ||
        !overlayBox.attached) {
      return;
    }

    final destGlobal = mapBox.localToGlobal(mapLocal);
    final destOverlay = overlayBox.globalToLocal(destGlobal);
    final mapTopLeft =
        overlayBox.globalToLocal(mapBox.localToGlobal(Offset.zero));
    final mapRect = Rect.fromLTWH(
      mapTopLeft.dx,
      mapTopLeft.dy,
      mapBox.size.width,
      mapBox.size.height,
    );

    if (_nearlyEqualOffset(_destinationOverlay, destOverlay) &&
        _nearlyEqualRect(_mapRectInOverlay, mapRect)) {
      return;
    }

    setState(() {
      _destinationOverlay = destOverlay;
      _mapRectInOverlay = mapRect;
    });
  }

  static bool _nearlyEqualOffset(Offset? a, Offset b) {
    if (a == null) return false;
    return (a.dx - b.dx).abs() < 0.5 && (a.dy - b.dy).abs() < 0.5;
  }

  static bool _nearlyEqualRect(Rect? a, Rect b) {
    if (a == null) return false;
    return (a.left - b.left).abs() < 0.5 &&
        (a.top - b.top).abs() < 0.5 &&
        (a.width - b.width).abs() < 0.5 &&
        (a.height - b.height).abs() < 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    final destOverlay = _destinationOverlay;
    final mapRect = _mapRectInOverlay;
    if (img == null || destOverlay == null || mapRect == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recomputeOverlayCoords();
      });
      return const SizedBox.expand();
    }

    final mq = MediaQuery.paddingOf(context);
    final bottomChromePx =
        mq.bottom + widget.bottomActionRowPadding + kMapOverlayControlSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        // No postFrameCallback here: _onControllerUpdate already calls
        // _recomputeOverlayCoords via _refreshScreenPoint on every camera
        // update, so adding one on each build would cause redundant setState
        // calls at rebuild frequency.
        return Semantics(
          label:
              'Ziel liegt außerhalb des Kartenausschnitts – Pfeil zeigt in dessen Richtung',
          container: true,
          child: CustomPaint(
            painter: _OffscreenDestinationPainter(
              destinationOverlay: destOverlay,
              mapRectInOverlay: mapRect,
              bottomChromePx: bottomChromePx,
              image: img,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _OffscreenDestinationPainter extends CustomPainter {
  _OffscreenDestinationPainter({
    required this.destinationOverlay,
    required this.mapRectInOverlay,
    required this.bottomChromePx,
    required this.image,
  });

  final Offset destinationOverlay;
  final Rect mapRectInOverlay;
  final double bottomChromePx;
  final ui.Image image;

  /// Ray from [center] toward [target]; returns hit on the rectangle [0,0]–[size].
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

  static Offset? _borderHitRect(Offset center, Offset target, Rect rect) {
    final origin = rect.topLeft;
    final c = center - origin;
    final t = target - origin;
    final hit = _borderHit(c, t, rect.size);
    return hit == null ? null : hit + origin;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 1 || size.height < 1) return;

    final overlayRect = Offset.zero & size;
    final visibleMap = mapRectInOverlay.intersect(overlayRect);
    if (visibleMap.width < 1 || visibleMap.height < 1) return;

    final dest = destinationOverlay;
    if (visibleMap.inflate(2).contains(dest)) return;

    final center = visibleMap.center;
    final border = _borderHitRect(center, dest, visibleMap);
    if (border == null) return;

    final bottomLimit =
        math.min(visibleMap.bottom, size.height - bottomChromePx);
    final y = border.dy
        .clamp(visibleMap.top, math.max(visibleMap.top, bottomLimit))
        .toDouble();
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
    return oldDelegate.destinationOverlay != destinationOverlay ||
        oldDelegate.mapRectInOverlay != mapRectInOverlay ||
        oldDelegate.bottomChromePx != bottomChromePx ||
        oldDelegate.image != image;
  }
}
