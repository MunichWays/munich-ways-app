import 'package:flutter/material.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';

class BikenetSelectionSheet extends StatefulWidget {
  final MapScreenViewModel? model;

  BikenetSelectionSheet({Key? key, this.model}) : super(key: key);

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
            title: Row(
              children: [
                Text('RadlVorrang MunichWays'),
                SizedBox(
                  width: 8,
                ),
                Container(
                  width: 24,
                  height: 4,
                  color: Colors.black54,
                ),
              ],
            ),
            contentPadding: EdgeInsets.all(16),
            isThreeLine: true,
            subtitle: Text(
                "Ausgesuchte RadlVorrang-Strecken von MunichWays. Mit dem Rad stressfrei durch München auf Wegen weitestgehend abseits vielbefahrener Straßen."),
            value: widget.model!.isRadlvorrangnetzVisible,
            onChanged: (bool? value) {
              widget.model!.toggleRadvorrangnetzVisible();
              setState(() {});
            },
          ),
          Divider(
            height: 0,
          ),
          CheckboxListTile(
            isThreeLine: true,
            contentPadding: EdgeInsets.all(16),
            title: Row(
              children: [
                Text("Alle Strecken"),
                SizedBox(
                  width: 8,
                ),
                Dot(),
                SizedBox(
                  width: 2,
                ),
                Dot(),
                SizedBox(
                  width: 2,
                ),
                Dot(),
                SizedBox(
                  width: 2,
                ),
                Dot(),
              ],
            ),
            subtitle: Text(
                'Alle Straßen und Wege, auf denen man mit dem Rad fahren kann.'),
            value: widget.model!.isGesamtnetzVisible,
            onChanged: (bool? value) {
              widget.model!.toggleGesamtnetzVisible();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

class Dot extends StatelessWidget {
  const Dot({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: ShapeDecoration(color: Colors.black54, shape: CircleBorder()),
    );
  }
}
