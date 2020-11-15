import 'package:flutter/material.dart';
import 'package:munich_ways/nav_routes.dart';
import 'package:munich_ways/ui/about/imprint_screen.dart';
import 'package:munich_ways/ui/about/info_screen.dart';
import 'package:munich_ways/ui/map/map_screen.dart';
import 'package:munich_ways/ui/theme.dart';

void main() => runApp(MunichWaysApp());

class MunichWaysApp extends StatefulWidget {
  @override
  _MunichWaysAppState createState() => _MunichWaysAppState();
}

class _MunichWaysAppState extends State<MunichWaysApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeData,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case NavRoutes.root:
          case NavRoutes.map:
            return MaterialPageRoute(
                settings: RouteSettings(name: settings.name),
                builder: (context) => MapScreen());
          case NavRoutes.info:
            return MaterialPageRoute(
                settings: RouteSettings(name: settings.name),
                builder: (context) => InfoScreen());
          case NavRoutes.imprint:
            return MaterialPageRoute(builder: (context) => ImprintScreen());
          default:
            throw Exception("unknown route ${settings.name}");
        }
      },
    );
  }
}
