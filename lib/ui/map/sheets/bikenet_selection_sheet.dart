import 'package:flutter/material.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';

class BikenetSelectionSheet extends StatefulWidget {
  final MapScreenViewModel model;

  const BikenetSelectionSheet({
    Key key,
    this.model,
  }) : super(key: key);

  @override
  _BikenetSelectionSheetState createState() => _BikenetSelectionSheetState();
}

class _BikenetSelectionSheetState extends State<BikenetSelectionSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Fahrradnetz auswählen",
                  style: Theme.of(context).textTheme.headline6,
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          CheckboxListTile(
            title: Text("Radvorrangnetz"),
            value: widget.model.isRadlvorrangnetzVisible,
            onChanged: (bool value) {
              widget.model.toggleRadvorrangnetzVisible();
              setState(() {});
            },
          ),
          CheckboxListTile(
            title: Text("Gesamtnetz"),
            value: widget.model.isGesamtnetzVisible,
            onChanged: (bool value) {
              widget.model.toggleGesamtnetzVisible();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}
