import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:munich_ways/api/mapillary/mapillary_api_v4.dart' as api;
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class MapillaryImage extends StatelessWidget {
  const MapillaryImage({
    required this.mapillaryImgId,
    required this.mapillaryThumbUrl,
  });

  final String? mapillaryImgId;
  final String? mapillaryThumbUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.black87,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: mapillaryImgId != ''
                ? CachedNetworkImage(
                    imageUrl: mapillaryThumbUrl ?? '',
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  )
                : Center(
                    child: Text(
                      context.l10n.tr('Kein Bild hinterlegt'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
          ),
        ),
        const Positioned(
          bottom: 2,
          left: 2,
          child: Text(
            'CC BY-SA 4.0 Mapillary',
            style: TextStyle(fontSize: 10, color: Colors.black87),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 4,
          child: ElevatedButton(
            onPressed: () async {
              final url = mapillaryImgId != null
                  ? Uri.parse(api.mapillaryApp + mapillaryImgId!)
                  : Uri.parse(api.mapillaryApp + api.mapillaryErrorId);
              try {
                await launchUrl(url);
              } on PlatformException catch (e) {
                log.e(e.message);
              } catch (e) {
                log.e('Could not launch $url');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            child: Text(context.l10n.tr('Mapillary öffnen')),
          ),
        ),
      ],
    );
  }
}
