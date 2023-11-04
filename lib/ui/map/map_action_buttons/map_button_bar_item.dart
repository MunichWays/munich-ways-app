import 'package:flutter/material.dart';

class MapButtonBarItem extends StatelessWidget {
  final Function onPressed;
  final Widget child;
  final String? label;

  const MapButtonBarItem({
    Key? key,
    required this.onPressed,
    required this.child,
    this.label = null,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        child: Tooltip(
          message: label,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: child,
          ),
        ),
        onTap: () {
          onPressed();
        },
      ),
    );
  }
}
