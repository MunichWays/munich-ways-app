import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:munich_ways/ui/widgets/list_item.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
  @override
  Widget build(BuildContext context) {
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
                _Header(farbe: widget.details.farbe, name: widget.details.name),
                // see #57 - hide till we switch to mapillary api v4 _MapillaryImage(mapillaryImgId: widget.details.mapillaryImgId),
                ListItem(
                  label: "Strecke",
                  value: widget.details.strecke,
                ),
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
                            launchWebsite(widget.details.kategorie!.url);
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
            _Header(farbe: widget.details.farbe, name: widget.details.name),
          ],
        ),
      ),
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

// class _MapillaryImage extends StatelessWidget {
//   const _MapillaryImage({
//     Key key,
//     @required this.mapillaryImgId,
//   }) : super(key: key);
//
//   final String mapillaryImgId;
//
//   @override
//   Widget build(BuildContext context) {
//     return Stack(children: [
//       Container(
//         color: Colors.black87,
//         child: AspectRatio(
//           aspectRatio: 16 / 9,
//           child: mapillaryImgId != null
//               ? CachedNetworkImage(
//                   imageUrl:
//                       'https://images.mapillary.com/$mapillaryImgId/thumb-640.jpg',
//                   placeholder: (context, url) =>
//                       Center(child: CircularProgressIndicator()),
//                   errorWidget: (context, url, error) => Icon(Icons.error),
//                 )
//               : Container(
//                   child: Center(
//                       child: Text(
//                     'Kein Bild hinterlegt',
//                     style: TextStyle(color: Colors.white),
//                   )),
//                 ),
//         ),
//       ),
//       Positioned(
//           bottom: 2,
//           left: 2,
//           child: Text(
//             "CC BY-SA 4.0 Mapillary",
//             style: TextStyle(fontSize: 10, color: Colors.black87),
//           )),
//       Positioned(
//         bottom: 0,
//         right: 4,
//         child: ElevatedButton(
//           onPressed: () async {
//             var url = mapillaryImgId != null
//                 ? 'https://www.mapillary.com/map/im/$mapillaryImgId'
//                 : 'https://www.mapillary.com/map/im/vLk5t0YshakfGnl6q5fjUg';
//             if (await canLaunch(url)) {
//               await launch(url);
//             } else {
//               log.e("Could not launch $url");
//             }
//           },
//           child: const Text('Mapillary öffnen'),
//           style: ElevatedButton.styleFrom(
//             primary: Colors.white70, // background
//             onPrimary: Colors.black87, // foreground
//           ),
//         ),
//       ),
//     ]);
//   }
// }

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
                style: Theme.of(context).textTheme.headline6,
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
