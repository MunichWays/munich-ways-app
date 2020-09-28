import 'package:flutter/material.dart';

class ListItem extends StatelessWidget {
  final String label;
  final String value;

  const ListItem({
    Key key,
    @required this.label,
    @required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            this.label,
            style: Theme.of(context).textTheme.overline,
          ),
          Text(this.value, style: Theme.of(context).textTheme.subtitle1)
        ],
      ),
    );
  }
}
