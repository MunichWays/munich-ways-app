import 'package:flutter/material.dart';
import 'package:munich_ways/api/mapillary/mapillary_service.dart';
import 'package:munich_ways/api/mapillary/mapillary_thumb_data_model.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/screenshots/store_screenshot_config.dart';
import 'package:munich_ways/ui/street_details/mapillary_image.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:munich_ways/ui/widgets/list_item.dart';
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
    final imgId = widget.details.mapillaryImgId ?? '';
    if (kStoreScreenshots && imgId.isEmpty) {
      _postThumbData = Future.value(
        MapillaryThumbDataModel(thumbUrl: '', imageId: ''),
      );
    } else {
      _postThumbData = getSinglePostData(imgId);
    }
  }

  List<Widget> _scrollableChildren() {
    final d = widget.details;
    return [
      FutureBuilder<MapillaryThumbDataModel>(
        future: _postThumbData,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final data = snapshot.data!;
            return MapillaryImage(
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
