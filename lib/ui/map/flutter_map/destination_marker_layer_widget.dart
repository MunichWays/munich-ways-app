import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:munich_ways/model/place.dart';

class DestinationMarkerLayerWidget extends StatelessWidget {
  final Place? destination;

  const DestinationMarkerLayerWidget({Key? key, this.destination})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return destination != null
        ? MarkerLayerWidget(
            options: MarkerLayerOptions(
            markers: [
              Marker(
                  width: 35.0,
                  height: 48.0,
                  point: destination!.latLng,
                  builder: (ctx) => Container(
                        child: Image(image: AssetImage('images/pin.png')),
                      ),
                  rotate: true),
            ],
          ))
        : Container();
  }
}
