import 'package:flutter/material.dart';
import 'package:munich_ways/ui/map/map_screen.dart';
import 'package:munich_ways/ui/theme.dart';

void main() => runApp(MunichWaysApp());

class MunichWaysApp extends StatelessWidget {
  const MunichWaysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeData,
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: RouteSettings(name: settings.name),
        builder: (context) => MapScreen(),
      ),
    );
  }
}
