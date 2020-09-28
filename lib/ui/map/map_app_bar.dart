import 'package:flutter/material.dart';

class MapAppBar extends StatelessWidget {
  final List<Widget> actions;

  const MapAppBar({
    Key key,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      right: 10,
      left: 10,
      child: AppBar(
        iconTheme: IconThemeData(color: Colors.black54),
        title: Text('Munich Ways', style: TextStyle(color: Colors.black54)),
        backgroundColor: Colors.white,
        shape: RoundedAppBarShape(),
        actions: actions,
      ),
    );
  }
}

class RoundedAppBarShape extends ShapeBorder {
  RoundedAppBarShape();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection textDirection}) => null;

  @override
  Path getOuterPath(Rect rect, {TextDirection textDirection}) {
    print(rect.height);
    return Path()
      ..addRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 10)))
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
