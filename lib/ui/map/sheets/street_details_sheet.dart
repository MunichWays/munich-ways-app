import 'package:flutter/material.dart';
import 'package:munich_ways/ui/map/street_details.dart';
import 'package:munich_ways/ui/widgets/list_item.dart';

class StreetDetailsSheet extends StatelessWidget {
  final StreetDetails details;

  const StreetDetailsSheet({
    Key key,
    @required this.details,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: double.infinity),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        details.name ?? "Unbekannte Straße",
                        style: Theme.of(context).textTheme.headline6,
                      ),
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
              ListItem(
                label: "Beschreibung",
                value: details.description ?? "-",
              ),
              ListItem(
                label: "Ist",
                value: details.ist ?? "-",
              ),
              ListItem(
                label: "Soll",
                value: details.soll ?? "-",
              ),
              ListItem(
                label: "Kategorie",
                value: details.kategorie ?? "-",
              ),
            ],
          ),
        ));
  }
}
