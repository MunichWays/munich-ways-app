import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:munich_ways/common/logger_setup.dart';

import '../../theme.dart';

class LocationLayerWidget extends StatefulWidget {
  final bool enabled;
  final bool moveMapAlong;
  final bool rotateMapInUserDirecation;

  LocationLayerWidget(
      {Key? key,
      this.enabled = true,
      this.moveMapAlong = false,
      this.rotateMapInUserDirecation = false})
      : super(key: key);

  @override
  _LocationLayerWidgetState createState() => _LocationLayerWidgetState();
}

class _LocationLayerWidgetState extends State<LocationLayerWidget> {
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? currentPosition;
  StreamSubscription<CompassEvent>? _compassEventsStreamSubscription;
  double? headingInDegree;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocationPermission>(
        future: Geolocator.checkPermission(),
        builder: (context, snapshot) {
          if (!widget.enabled) {
            log.d("disabled");
            return Container();
          }

          if (!snapshot.hasData) {
            log.d("loading permission check");
            return Container();
          }

          if (snapshot.data == LocationPermission.denied ||
              snapshot.data == LocationPermission.deniedForever) {
            log.d("no permission for displaying current location");
            return Container();
          }

          return FutureBuilder<bool>(
              future: Geolocator.isLocationServiceEnabled(),
              builder: (context, snapshot1) {
                if (!snapshot1.hasData) {
                  log.d("loading isLocationServiceEnabled check");
                  return Container();
                }

                if (!snapshot1.data!) {
                  log.d("locationService is not enabled");
                  return Container();
                }

                if (!_liveLocationEnabled()) {
                  _startLiveLocation();
                }

                return _buildLiveLocationLayer(context);
              });
        });
  }

  Widget _buildLiveLocationLayer(BuildContext context) {
    if (currentPosition == null) {
      return Container();
    }

    var markers = <Marker>[
      Marker(
        width: 48.0,
        height: 48.0,
        point: latlong2.LatLng(
            currentPosition!.latitude, currentPosition!.longitude),
        child: Stack(
          children: [
            if (headingInDegree != null)
              DirectionIndicator(heading: headingInDegree!),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                decoration: ShapeDecoration(
                  color: AppColors.mapAccentColor,
                  shape: CircleBorder(
                          side: BorderSide(width: 3, color: Colors.white)) +
                      CircleBorder(
                          side: BorderSide(
                              width: 1, color: AppColors.mapAccentColor)),
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    return MarkerLayer(markers: markers);
  }

  bool _liveLocationEnabled() {
    return _positionStreamSubscription != null;
  }

  void _startLiveLocation() {
    var mapController = MapController.of(context);
    if (_positionStreamSubscription == null) {
      final positionStream = Geolocator.getPositionStream();
      _positionStreamSubscription = positionStream.handleError((error) {
        _positionStreamSubscription!.cancel();
        _positionStreamSubscription = null;
      }).listen((position) {
        setState(() {
          this.currentPosition = position;
          if (widget.moveMapAlong) {
            mapController.move(
                latlong2.LatLng(
                    currentPosition!.latitude, currentPosition!.longitude),
                mapController.camera.zoom,
                id: "MoveAlongLiveLocation");
          }
        });
      });
    }

    if (_compassEventsStreamSubscription == null) {
      _compassEventsStreamSubscription = FlutterCompass.events?.listen((event) {
        setState(() {
          if (event.heading == null) {
            headingInDegree = null;
          } else {
            headingInDegree =
                event.heading! < 0 ? (event.heading! + 360) : event.heading!;
          }

          if (widget.rotateMapInUserDirecation && headingInDegree != null) {
            var mapController = MapController.of(context);
            mapController.rotate(360 - headingInDegree!);
          }
        });
      });
    }
  }

  void _stopLiveLocation() {
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
    }

    if (_compassEventsStreamSubscription != null) {
      _compassEventsStreamSubscription?.cancel();
      _compassEventsStreamSubscription = null;
    }
  }

  @override
  void dispose() {
    _stopLiveLocation();
    super.dispose();
  }
}

class DirectionIndicator extends StatelessWidget {
  final double _heading;

  DirectionIndicator({super.key, required double heading}) : _heading = heading;

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: AlwaysStoppedAnimation(_heading / 360),
      child: CustomPaint(
        foregroundPainter: DirecationIndicatorPainter(),
        child: Container(),
      ),
    );
  }
}

class DirecationIndicatorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = AppColors.mapAccentColor
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    var center = size.center(Offset(0, 0));

    var triangle = Path();
    triangle.addPolygon([
      Offset(0 + 12, size.height / 2),
      Offset(center.dx, 0),
      Offset(center.dx + 12, size.height / 2),
    ], true);

    canvas.drawPath(triangle, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
