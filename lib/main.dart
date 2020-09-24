import 'package:flutter/material.dart';
import 'package:munich_ways/Routes.dart';
import 'package:munich_ways/ui/map/map_screen.dart';

import 'control/geojsonroutes.dart';

void main() => runApp(MunichWaysApp());

class MunichWaysApp extends StatefulWidget {
  @override
  _MunichWaysAppState createState() => _MunichWaysAppState();
}

class _MunichWaysAppState extends State<MunichWaysApp> {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case NavRoutes.root:
          case NavRoutes.map:
            return MaterialPageRoute(builder: (context) => MapScreen());
          default:
            throw Exception("unknown route ${settings.name}");
        }
      },
    );
  }
}