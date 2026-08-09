import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MapAttribution extends StatefulWidget {
  const MapAttribution({
    super.key,
    required this.expanded,
    this.inline = false,
  });

  final bool expanded;
  final bool inline;

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
    if (!widget.expanded) return const SizedBox.shrink();
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black87,
            ) ??
        const TextStyle(color: Colors.black87);
    final content = Container(
      width: double.infinity,
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: Colors.white.withValues(alpha: 0.42),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text.rich(
          TextSpan(
            style: baseStyle,
            children: <TextSpan>[
              const TextSpan(text: '© '),
              TextSpan(
                text: 'OpenMapTiles',
                style: const TextStyle(
                  decoration: TextDecoration.underline,
                ),
                recognizer: _openMapTilesTap,
              ),
              const TextSpan(text: ' · © '),
              TextSpan(
                text: 'OpenStreetMap contributors',
                style: const TextStyle(
                  decoration: TextDecoration.underline,
                ),
                recognizer: _openStreetMapTap,
              ),
              const TextSpan(text: ' · '),
              TextSpan(
                text: 'OpenFreeMap',
                style: const TextStyle(
                  decoration: TextDecoration.underline,
                ),
                recognizer: _openFreeMapTap,
              ),
            ],
          ),
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
    if (widget.inline) return content;
    return Align(alignment: Alignment.bottomCenter, child: content);
  }
}
