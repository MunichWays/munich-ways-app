import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';

class AppColors {
  static const munichWaysBlue = Color(0xff61A1D8);

  static Color getPolylineColor(_color) {
    switch (_color) {
      case "schwarz":
        return Colors.black;
        break;
      case "grün":
        return Colors.green;
        break;
      case "gelb":
        return Colors.orange;
        break;
      case "rot":
        return Colors.red;
        break;
      case "grau":
        return Colors.grey;
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
  buttonColor: AppColors.munichWaysBlue,
);
