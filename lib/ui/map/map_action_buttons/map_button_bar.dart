import 'package:flutter/material.dart';

class MapButtonBar extends StatelessWidget {
  final children;

  MapButtonBar({super.key, this.children = const <Widget>[]});

  @override
  Widget build(BuildContext context) {
    return Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(100),
        elevation: 8,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: IntrinsicHeight(
            child:
                Row(mainAxisSize: MainAxisSize.min, children: this.children)));
  }
}
