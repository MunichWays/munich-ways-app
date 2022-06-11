import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';

class AppColors {
  static const munichWaysBlue = Color(0xff61A1D8);
  static const mapBlack = Colors.black;
  static const mapGreen = Color(0xff27f5a5);
  static const mapYellow = Color(0xfffbba00);
  static const mapRed = Color(0xfff44336);
  static const mapGrey = Color(0xff9c9d9f);

  static const mapAccentColor = Color(0xFF2196F3);

  static Color getPolylineColor(_color) {
    switch (_color) {
      case "schwarz":
        return mapBlack;
        break;
      case "grün":
        return mapGreen;
        break;
      case "gelb":
        return mapYellow;
        break;
      case "rot":
        return mapRed;
        break;
      case "grau":
        return mapGrey;
        break;
      default:
        log.d("unknown color $_color");
        return Colors.blueGrey;
    }
  }
}

var themeData = ThemeData(
  primaryColor: AppColors.munichWaysBlue,
  visualDensity: VisualDensity.adaptivePlatformDensity,
);
