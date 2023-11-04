import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:munich_ways/model/place.dart';

const String pinPath = "images/pin_blue.png";

class DestinationMarkerLayerWidget extends StatelessWidget {
  final Place? destination;

  const DestinationMarkerLayerWidget({Key? key, this.destination})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return destination != null
        ? MarkerLayer(markers: [
            Marker(
                width: 44.0,
                height: 57.0,
                point: destination!.latLng,
                child: Container(
                  child: Image(image: AssetImage(pinPath)),
                ),
                alignment: Alignment.topCenter,
                rotate: true),
          ])
        : Container();
  }
}
