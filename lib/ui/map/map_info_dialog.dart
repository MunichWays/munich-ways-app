import 'package:flutter/material.dart';
import 'package:munich_ways/ui/theme.dart';

class MapInfoDialog extends StatelessWidget {
  const MapInfoDialog({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Legende"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorListItem(
              text:
                  "Grün: Gemütlich und komfortabel, Radweg ist breit, sicher, eben",
              color: AppColors.mapGreen,
            ),
            ColorListItem(
              text: "Gelb: Durchschnittlich, Radweg ist verbesserungswürdig",
              color: AppColors.mapYellow,
            ),
            ColorListItem(
              text: "Rot: Stressig, Radweg ist sehr schmal, nicht komfortabel",
              color: AppColors.mapRed,
            ),
            ColorListItem(
              text: "Schwarz: Lücke im Radnetz, kein Radweg",
              color: AppColors.mapBlack,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(children: [
                Icon(Icons.touch_app),
                SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    "Klicke auf eine Strecke um mehr Informationen anzuzeigen",
                    style: Theme.of(context).textTheme.subtitle1,
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text("OK"),
          onPressed: () {
            Navigator.of(context).pop();
          },
        )
      ],
    );
  }
}

class ColorListItem extends StatelessWidget {
  final String text;
  final Color color;

  const ColorListItem({
    Key key,
    @required this.text,
    @required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(children: [
        Container(
          width: 24,
          height: 24,
          decoration: ShapeDecoration(
            color: color,
            shape: CircleBorder(),
          ),
        ),
        SizedBox(
          width: 8,
        ),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.subtitle1,
          ),
        ),
      ]),
    );
  }
}
