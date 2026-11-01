import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/map_background.dart';
import 'package:munich_ways/ui/map/aerial_map_style.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MapAttribution extends StatelessWidget {
  const MapAttribution({
    super.key,
    required this.expanded,
    this.inline = false,
    this.background = MapBackground.standard,
  });

  final bool expanded;
  final bool inline;
  final MapBackground background;

  Future<void> _launch(String url) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      log.e("No browser found");
    }
  }

  Widget _link(BuildContext context, String label, String url) {
    return Semantics(
      link: true,
      label: label,
      excludeSemantics: true,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Colors.black87,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                decoration: TextDecoration.underline,
              ),
        ),
        onPressed: () => _launch(url),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!expanded) return const SizedBox.shrink();
    final aerial = background == MapBackground.aerial;
    final content = Container(
      width: double.infinity,
      color: Colors.white.withValues(alpha: 0.92),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (aerial)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 2),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(bavariaAerialAttribution,
                    style: TextStyle(fontSize: 11, color: Colors.black87)),
              ),
            ),
          IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Expanded(
                    child: _link(context, 'OpenMapTiles',
                        'https://www.openmaptiles.org/')),
                Expanded(
                    child: _link(context, '© OpenStreetMap contributors',
                        'https://www.openstreetmap.org/copyright')),
              ])),
          IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Expanded(
                    child: _link(
                        context, 'OpenFreeMap', 'https://openfreemap.org/')),
                if (aerial)
                  Expanded(
                      child: _link(context, 'Bayern-WMTS',
                          'https://geodatenonline.bayern.de/geodatenonline/seiten/wmts_ba'))
                else
                  const Expanded(child: SizedBox.shrink()),
              ])),
        ],
      ),
    );
    if (inline) return content;
    return Align(alignment: Alignment.bottomCenter, child: content);
  }
}
