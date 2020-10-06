import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:munich_ways/ui/widgets/list_item.dart';
import 'package:url_launcher/url_launcher.dart';

class StreetDetailsSheet extends StatefulWidget {
  final StreetDetails details;

  final double statusBarHeight;

  const StreetDetailsSheet({
    Key key,
    @required this.details,
    @required this.statusBarHeight,
  })  : assert(details != null),
        assert(statusBarHeight != null),
        super(key: key);

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
                ListItem(
                  label: "Strecke",
                  value: widget.details.strecke,
                ),
                ListItem(
                  label: "Ist-Zustand",
                  value: widget.details.ist,
                ),
                ListItem(
                  label: "Soll-Maßnahmen",
                  value: widget.details.soll,
                ),
                ListItem(
                  label: "Beschreibung",
                  value: widget.details.description,
                ),
                ListItem(
                    label: "Kategorie",
                    value: widget.details.kategorie.title,
                    onTap: widget.details.kategorie.url != null
                        ? () async {
                            var url = widget.details.kategorie.url;
                            if (await canLaunch(url)) {
                              await launch(url);
                            } else {
                              log.e("Could not launch $url");
                            }
                          }
                        : null),
                for (var link in widget.details.links)
                  ListItem(
                    label: "Link",
                    value: link.title,
                    onTap: () async {
                      if (await canLaunch(link.url)) {
                        await launch(link.url);
                      } else {
                        log.e("Could not launch ${link.url}");
                      }
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
}

class _Header extends StatelessWidget {
  final String farbe;
  final String name;

  const _Header({
    Key key,
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
  final String url;

  const DetailItem({
    Key key,
    @required this.label,
    @required this.value,
    this.url,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (value == null || value.isEmpty) {
      return SizedBox.shrink();
    } else {
      return ListItem(
        label: label,
        value: value,
      );
    }
  }
}
