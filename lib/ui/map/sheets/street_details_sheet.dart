import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/ui/map/street_details.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:munich_ways/ui/widgets/list_item.dart';
import 'package:url_launcher/url_launcher.dart';

class StreetDetailsSheet extends StatelessWidget {
  final StreetDetails details;

  const StreetDetailsSheet({
    Key key,
    @required this.details,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: double.infinity),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 8,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 8),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: ShapeDecoration(
                        color: AppColors.getPolylineColor(details.farbe),
                        shape: CircleBorder(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      details.name ?? "Unbekannte Straße",
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
              SizedBox(
                height: 8,
              ),
              ListItem(
                label: "Strecke",
                value: details.strecke,
              ),
              ListItem(
                label: "Ist-Zustand",
                value: details.ist,
              ),
              ListItem(
                label: "Soll-Maßnahmen",
                value: details.soll,
              ),
              ListItem(
                label: "Beschreibung",
                value: details.description,
              ),
              ListItem(
                  label: "Kategorie",
                  value: details.kategorie.title,
                  onTap: details.kategorie.url != null
                      ? () async {
                          var url = details.kategorie.url;
                          if (await canLaunch(url)) {
                            await launch(url);
                          } else {
                            log.e("Could not launch $url");
                          }
                        }
                      : null),
            ],
          ),
        ));
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
