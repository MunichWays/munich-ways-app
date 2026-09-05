import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MapAttribution extends StatelessWidget {
  const MapAttribution({
    super.key,
    required this.expanded,
    this.inline = false,
  });

  final bool expanded;
  final bool inline;

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
        child: Text(label, maxLines: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!expanded) return const SizedBox.shrink();
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black87,
            ) ??
        const TextStyle(color: Colors.black87);
    final content = Container(
      width: double.infinity,
      height: 48,
      color: Colors.white.withValues(alpha: 0.92),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 4),
            Text('©', style: baseStyle),
            _link(
              context,
              'OpenMapTiles',
              'https://www.openmaptiles.org/',
            ),
            Text('· ©', style: baseStyle),
            _link(
              context,
              'OpenStreetMap contributors',
              'https://www.openstreetmap.org/copyright',
            ),
            Text('·', style: baseStyle),
            _link(context, 'OpenFreeMap', 'https://openfreemap.org/'),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
    if (inline) return content;
    return Align(alignment: Alignment.bottomCenter, child: content);
  }
}
