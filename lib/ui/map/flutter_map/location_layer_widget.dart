import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/common/logger_setup.dart';

class LocationLayerWidget extends StatefulWidget {
  final bool enabled;
  final bool moveMapAlong;

  LocationLayerWidget({Key key, this.enabled = true, this.moveMapAlong = false})
      : super(key: key);

  @override
  _LocationLayerWidgetState createState() => _LocationLayerWidgetState();
}

class _LocationLayerWidgetState extends State<LocationLayerWidget> {
  StreamSubscription<Position> _positionStreamSubscription;
  Position currentPosition;

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

                if (!snapshot1.data) {
                  log.d("locationService is not enabled");
                  return Container();
                }

                if (!_liveLocationEnabled()) {
                  _startLiveLocation(MapState.maybeOf(context));
                }

                return _buildLiveLocationLayer(context);
              });
        });
  }

  Widget _buildLiveLocationLayer(BuildContext context) {
    if (currentPosition == null) {
      return Container();
    }

    final mapState = MapState.maybeOf(context);

    var markers = <Marker>[
      Marker(
        width: 24.0,
        height: 24.0,
        point: LatLng(currentPosition.latitude, currentPosition.longitude),
        builder: (ctx) => Container(
          decoration: ShapeDecoration(
            color: Colors.blue,
            shape: CircleBorder(
                    side: BorderSide(width: 3, color: Colors.white)) +
                CircleBorder(side: BorderSide(width: 1, color: Colors.blue)),
          ),
        ),
      ),
    ];

    return MarkerLayer(
        MarkerLayerOptions(markers: markers), mapState, mapState.onMoved);
  }

  bool _liveLocationEnabled() {
    return _positionStreamSubscription != null;
  }

  void _startLiveLocation(MapState mapState) {
    if (_positionStreamSubscription == null) {
      final positionStream = Geolocator.getPositionStream();
      _positionStreamSubscription = positionStream.handleError((error) {
        _positionStreamSubscription.cancel();
        _positionStreamSubscription = null;
      }).listen((position) {
        log.d("New Pos: $position");
        setState(() {
          this.currentPosition = position;
          if (widget.moveMapAlong) {
            log.d("Move along");
            mapState.move(
                LatLng(currentPosition.latitude, currentPosition.longitude),
                mapState.zoom,
                source: MapEventSource.custom);
          }
        });
      });
    }
  }

  void _stopLiveLocation() {
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription.cancel();
      _positionStreamSubscription = null;
    }
  }

  @override
  void dispose() {
    _stopLiveLocation();
    super.dispose();
  }
}
