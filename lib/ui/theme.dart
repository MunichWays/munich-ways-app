import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';

class AppColors {
  // MunichWays corporate identity colors.
  static const munichWaysBlue = Color(0xFF6699CC);
  static const munichWaysGrey = Color(0xFF9C9D9F);
  static const munichWaysYellow = Color(0xFFFBBA00);
  static const munichWaysOrange = Color(0xFFFF6600);
  static const munichWaysGreen = Color(0xFF298A63);

  static const mapBlack = Colors.black;
  static const mapGreen = Color(0xff27f5a5);
  static const mapYellow = Color(0xffffd000);
  static const mapRed = Color(0xfff44336);
  static const mapGrey = Color(0xff9c9d9f);

  static const mapButtonBackground = Color(0xFF4D4D4D);
  static const mapButtonForeground = Colors.white;
  static const mapButtonForegroundActive = Color(0xFF65B8FF);

  static const mapAccentColor = Color(0xFF2196F3);
  static const mapRouteColor = Color(0xFF0D47A1);
  static const favoriteHighlight = Color(0xFFDCEEFF);

  static Color getPolylineColor(_color) {
    switch (_color) {
      case "schwarz":
        return mapBlack;
      case "grün":
        return mapGreen;
      case "gelb":
        return mapYellow;
      case "rot":
        return mapRed;
      case "grau":
        return mapGrey;
      default:
        log.d("unknown color $_color");
        return Colors.blueGrey;
    }
  }
}

var themeData = ThemeData(
  visualDensity: VisualDensity.adaptivePlatformDensity,
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.munichWaysBlue),
);
