import 'package:flutter/material.dart';

class MapButtonBar extends StatelessWidget {
  final children;

  MapButtonBar({super.key, this.children = const <Widget>[]});

  @override
  Widget build(BuildContext context) {
    return Material(
        elevation: 8,
        color: Colors.transparent,
        child: Container(
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(100)),
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: IntrinsicHeight(child: Row(children: this.children))));
  }
}
