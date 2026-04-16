import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MapAttribution extends StatefulWidget {
  const MapAttribution({
    Key? key,
  }) : super(key: key);

  @override
  State<MapAttribution> createState() => _MapAttributionState();
}

class _MapAttributionState extends State<MapAttribution> {
  late final TapGestureRecognizer _openFreeMapTap;
  late final TapGestureRecognizer _openMapTilesTap;
  late final TapGestureRecognizer _openStreetMapTap;

  @override
  void initState() {
    super.initState();
    _openFreeMapTap = TapGestureRecognizer()
      ..onTap = () => _launch('https://openfreemap.org/');
    _openMapTilesTap = TapGestureRecognizer()
      ..onTap = () => _launch('https://www.openmaptiles.org/');
    _openStreetMapTap = TapGestureRecognizer()
      ..onTap = () => _launch('https://www.openstreetmap.org/copyright');
  }

  @override
  void dispose() {
    _openFreeMapTap.dispose();
    _openMapTilesTap.dispose();
    _openStreetMapTap.dispose();
    super.dispose();
  }

  Future<void> _launch(String url) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      log.e("No browser found");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(2.0),
        color: Colors.white70,
        child: Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 12),
            children: <TextSpan>[
              const TextSpan(text: '© '),
              TextSpan(
                text: 'OpenMapTiles',
                style: const TextStyle(decoration: TextDecoration.underline),
                recognizer: _openMapTilesTap,
              ),
              const TextSpan(text: ' · OpenStreetMap'),
              TextSpan(
                text: ' contributors',
                style: const TextStyle(decoration: TextDecoration.underline),
                recognizer: _openStreetMapTap,
              ),
              const TextSpan(text: ' · '),
              TextSpan(
                text: 'OpenFreeMap',
                style: const TextStyle(decoration: TextDecoration.underline),
                recognizer: _openFreeMapTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
