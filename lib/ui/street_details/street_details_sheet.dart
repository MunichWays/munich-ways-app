import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:munich_ways/api/mapillary/mapillary_api_v4.dart' as api;
import 'package:munich_ways/api/mapillary/mapillary_service.dart';
import 'package:munich_ways/api/mapillary/mapillary_thumb_data_model.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:munich_ways/ui/widgets/list_item.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class StreetDetailsSheet extends StatefulWidget {
  const StreetDetailsSheet({
    super.key,
    required this.details,
  });

  final StreetDetails details;

  @override
  State<StreetDetailsSheet> createState() => _StreetDetailsSheetState();
}

class _StreetDetailsSheetState extends State<StreetDetailsSheet> {
  late Future<MapillaryThumbDataModel> _postThumbData;

  @override
  void initState() {
    super.initState();
    _postThumbData = getSinglePostData(widget.details.mapillaryImgId ?? '');
  }

  List<Widget> _scrollableChildren() {
    final d = widget.details;
    return [
      FutureBuilder<MapillaryThumbDataModel>(
        future: _postThumbData,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final data = snapshot.data!;
            return _MapillaryImage(
              mapillaryImgId: data.imageId,
              mapillaryThumbUrl: data.thumbUrl,
            );
          }
          if (snapshot.hasError) {
            log.e('${snapshot.error}');
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Fehler beim Laden.'),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        },
      ),
      if (d.streckenLink != null)
        ListItem(
          label: 'Strecke',
          value: d.streckenLink!.title,
          onTap: d.streckenLink!.url != null
              ? () async {
                  launchWebsite(d.streckenLink!.url);
                }
              : null,
        ),
      ListItem(
        label: 'Ist-Situation',
        value: d.ist,
      ),
      ListItem(
        label: 'Happy Bike Level',
        value: d.happyBikeLevel,
      ),
      ListItem(
        label: 'Soll-Maßnahmen',
        value: d.soll,
      ),
      ListItem(
        label: 'Maßnahmen-Kategorie',
        value: d.kategorie!.title,
        onTap: d.kategorie!.url != null
            ? () async {
                launchWebsite(d.kategorie!.url);
              }
            : null,
      ),
      ListItem(
        label: 'Beschreibung',
        value: d.description,
      ),
      ListItem(
        label: 'Munichways-Id',
        value: d.munichwaysId,
      ),
      ListItem(
        label: 'Status-Umsetzung',
        value: d.statusUmsetzung,
      ),
      ListItem(
        label: 'Bezirk',
        value: d.bezirk!.name,
        onTap: () async {
          launchWebsite(d.bezirk!.link.url);
        },
      ),
      for (final link in d.links!)
        ListItem(
          label: 'Link',
          value: link.title,
          onTap: () async {
            launchWebsite(link.url);
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(top: bottomSheetTopPadding(context)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: bottomSheetMaxHeight(context),
          ),
          child: Container(
            decoration: bottomSheetDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  farbe: widget.details.farbe,
                  name: widget.details.name,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Expanded(
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: bottomSheetBottomScrollPadding(context),
                    ),
                    children: _scrollableChildren(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> launchWebsite(String? url) async {
    if (url == null) {
      log.e('url is null');
      return;
    }
    final encodedUrl = Uri.encodeFull(url);
    if (await canLaunchUrlString(encodedUrl)) {
      await launchUrlString(encodedUrl);
    } else {
      log.e('Could not launch $encodedUrl');
    }
  }
}

class _MapillaryImage extends StatelessWidget {
  const _MapillaryImage({
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
                : const Center(
                    child: Text(
                      'Kein Bild hinterlegt',
                      style: TextStyle(color: Colors.white),
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
              backgroundColor: Colors.white70,
              foregroundColor: Colors.black87,
            ),
            child: const Text('Mapillary öffnen'),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    this.farbe,
    this.name,
  });

  final String? farbe;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Container(
              width: 12,
              height: 12,
              decoration: ShapeDecoration(
                color: AppColors.getPolylineColor(farbe),
                shape: const CircleBorder(),
              ),
            ),
          ),
          Expanded(
            child: Text(
              name ?? 'Unbekannte Straße',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Schließen',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailItem extends StatelessWidget {
  const DetailItem({
    super.key,
    required this.label,
    required this.value,
    this.url,
  });

  final String label;
  final String value;
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListItem(
      label: label,
      value: value,
    );
  }
}
