import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/api/mapillary/mapillary_thumb_data_model.dart';
import 'package:munich_ways/api/mapillary/mapillary_service.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:munich_ways/ui/widgets/list_item.dart';
import 'package:munich_ways/api/mapillary/mapillary_api_v4.dart' as api;

class StreetDetailsSheet extends StatefulWidget {
  final StreetDetails details;

  final double statusBarHeight;

  const StreetDetailsSheet({
    Key? key,
    required this.details,
    required this.statusBarHeight,
  }) : super(key: key);

  @override
  _StreetDetailsSheetState createState() => _StreetDetailsSheetState();
}

class _StreetDetailsSheetState extends State<StreetDetailsSheet> {
  late Future<MapillaryThumbDataModel> _postThumbData;

  @override
  void initState() {
    super.initState();

    _postThumbData = getSinglePostData(widget.details.mapillaryImgId ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _postThumbData,
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${snapshot.error} occurred',
                style: TextStyle(fontSize: 18),
              ),
            );
          } else if (snapshot.hasData) {
            MapillaryThumbDataModel data = snapshot.data;
            return Padding(
              padding: EdgeInsets.only(top: widget.statusBarHeight),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: new BorderRadius.only(
                    topLeft: const Radius.circular(15.0),
                    topRight: const Radius.circular(15.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: Offset(0, 0), // changes position of shadow
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ListView(
                      shrinkWrap: true,
                      children: [
                        _Header(
                            farbe: widget.details.farbe,
                            name: widget.details.name),
                        _MapillaryImage(
                            mapillaryImgId: widget.details.mapillaryImgId,
                            mapillaryThumbUrl: data.thumbUrl),
                        if (widget.details.streckenLink != null)
                          ListItem(
                              label: "Strecke",
                              value: widget.details.streckenLink!.title,
                              onTap: widget.details.streckenLink!.url != null
                                  ? () async {
                                      launchWebsite(
                                          widget.details.streckenLink!.url);
                                    }
                                  : null),
                        ListItem(
                          label: "Ist-Situation",
                          value: widget.details.ist,
                        ),
                        ListItem(
                          label: "Happy Bike Level",
                          value: widget.details.happyBikeLevel,
                        ),
                        ListItem(
                          label: "Soll-Maßnahmen",
                          value: widget.details.soll,
                        ),
                        ListItem(
                            label: "Maßnahmen-Kategorie",
                            value: widget.details.kategorie!.title,
                            onTap: widget.details.kategorie!.url != null
                                ? () async {
                                    launchWebsite(
                                        widget.details.kategorie!.url);
                                  }
                                : null),
                        ListItem(
                          label: "Beschreibung",
                          value: widget.details.description,
                        ),
                        ListItem(
                          label: "Munichways-Id",
                          value: widget.details.munichwaysId,
                        ),
                        ListItem(
                          label: "Status-Umsetzung",
                          value: widget.details.statusUmsetzung,
                        ),
                        ListItem(
                          label: "Bezirk",
                          value: widget.details.bezirk!.name,
                          onTap: () async {
                            launchWebsite(widget.details.bezirk!.link.url);
                          },
                        ),
                        for (var link in widget.details.links!)
                          ListItem(
                            label: "Link",
                            value: link.title,
                            onTap: () async {
                              launchWebsite(link.url);
                            },
                          ),
                      ],
                    ),
                    // overlays the first item in the ListView - the height of header is dynamic therefore could not use a fixed height
                    // workaround to have a header which is draggable, I assume there
                    // should be a nicer solution with DraggableScrollableSheet and
                    // Slivers but I couldn't get it to work with dynamic list height.
                    _Header(
                        farbe: widget.details.farbe, name: widget.details.name),
                  ],
                ),
              ),
            );
          }
        }
        return CircularProgressIndicator();
      },
    );
  }

  Future<void> launchWebsite(String? url) async {
    if (url == null) {
      log.e("url is null");
      return;
    }
    var encodedUrl = Uri.encodeFull(url);
    if (await canLaunchUrlString(encodedUrl)) {
      await launchUrlString(encodedUrl);
    } else {
      log.e("Could not launch ${encodedUrl}");
    }
  }
}

class _MapillaryImage extends StatelessWidget {
  const _MapillaryImage(
      {Key? key,
      @required this.mapillaryImgId,
      @required this.mapillaryThumbUrl})
      : super(key: key);

  final String? mapillaryImgId;
  final String? mapillaryThumbUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        color: Colors.black87,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: mapillaryImgId != ""
              ? CachedNetworkImage(
                  imageUrl: mapillaryThumbUrl ?? '',
                  placeholder: (context, url) =>
                      Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => Icon(Icons.error),
                )
              : Container(
                  child: Center(
                      child: Text(
                    'Kein Bild hinterlegt',
                    style: TextStyle(color: Colors.white),
                  )),
                ),
        ),
      ),
      Positioned(
          bottom: 2,
          left: 2,
          child: Text(
            "CC BY-SA 4.0 Mapillary",
            style: TextStyle(fontSize: 10, color: Colors.black87),
          )),
      Positioned(
        bottom: 0,
        right: 4,
        child: ElevatedButton(
          onPressed: () async {
            Uri url = mapillaryImgId != null
                ? Uri.parse(api.mapillaryApp + mapillaryImgId!)
                : Uri.parse(api.mapillaryApp + api.mapillaryErrorId);
            try {
              await launchUrl(url);
            } on PlatformException catch (e) {
              log.e(e.message);
            } catch (e) {
              log.e("Could not launch $url");
            }
          },
          child: const Text('Mapillary öffnen'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white70, // background
            foregroundColor: Colors.black87, // foreground
          ),
        ),
      ),
    ]);
  }
}

class _Header extends StatelessWidget {
  final String? farbe;
  final String? name;

  const _Header({
    Key? key,
    this.farbe,
    this.name,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: new BorderRadius.only(
            topLeft: const Radius.circular(15.0),
            topRight: const Radius.circular(15.0),
          )),
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 8),
              child: Container(
                width: 12,
                height: 12,
                decoration: ShapeDecoration(
                  color: AppColors.getPolylineColor(farbe),
                  shape: CircleBorder(),
                ),
              ),
            ),
            Expanded(
              child: Text(
                name ?? "Unbekannte Straße",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final String? url;

  const DetailItem({
    Key? key,
    required this.label,
    required this.value,
    this.url,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) {
      return SizedBox.shrink();
    } else {
      return ListItem(
        label: label,
        value: value,
      );
    }
  }
}
