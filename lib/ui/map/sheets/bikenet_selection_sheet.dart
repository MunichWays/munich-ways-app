import 'package:flutter/material.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';

class BikenetSelectionSheet extends StatefulWidget {
  final MapScreenViewModel model;

  BikenetSelectionSheet({Key key, this.model}) : super(key: key);

  @override
  _BikenetSelectionSheetState createState() => _BikenetSelectionSheetState();
}

class _BikenetSelectionSheetState extends State<BikenetSelectionSheet> {
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8, 16, 8),
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
          Divider(
            height: 0,
          ),
          CheckboxListTile(
            title: Text("RadlVorrang-Netz"),
            subtitle: Row(
              children: [
                Container(
                  width: 24,
                  height: 4,
                  color: Colors.black54,
                ),
                SizedBox(
                  width: 4,
                ),
                Text('durchgezogen')
              ],
            ),
            value: widget.model.isRadlvorrangnetzVisible,
            onChanged: (bool value) {
              widget.model.toggleRadvorrangnetzVisible();
              setState(() {});
            },
          ),
          Divider(
            height: 0,
          ),
          CheckboxListTile(
            title: Text("Gesamtnetz"),
            subtitle: Row(
              children: [
                Container(
                  width: 10,
                  height: 4,
                  color: Colors.black54,
                ),
                SizedBox(
                  width: 2,
                ),
                Container(
                  width: 10,
                  height: 4,
                  color: Colors.black54,
                ),
                SizedBox(
                  width: 4,
                ),
                Text('gestrichelt')
              ],
            ),
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
