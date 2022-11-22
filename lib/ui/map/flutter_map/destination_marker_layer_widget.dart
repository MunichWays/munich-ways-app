import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
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
                builder: (ctx) => Container(
                      child: Image(image: AssetImage(pinPath)),
                    ),
                rotate: true),
          ])
        : Container();
  }
}
