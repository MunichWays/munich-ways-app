import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';

class AppColors {
  // MunichWays corporate identity colors.
  static const munichWaysBlue = Color(0xFF6699CC);
  static const munichWaysGrey = Color(0xFF9C9D9F);
  static const munichWaysYellow = Color(0xFFFBBA00);
  static const munichWaysOrange = Color(0xFFFF6600);
  static const munichWaysGreen = Color(0xFF298A63);

  // Fixed UI role colors.
  static const heroForeground = Color(0xFF202124);
  static const uiPrimary = Color(0xFF336699);
  static const secondaryButtonBackground = Color(0xFFEAF2F8);
  static const disabledBackground = Color(0xFFECEDEE);
  static const disabledForeground = Color(0xFF5F6368);
  static const danger = Color(0xFFC62828);

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

/// Shared visual hierarchy for app actions.
///
/// Orange is reserved for rare hero actions. Regular actions use the blue
/// primary and secondary roles; quiet actions stay white or transparent.
class AppButtonStyles {
  static ButtonStyle hero(BuildContext _) => FilledButton.styleFrom(
        backgroundColor: AppColors.munichWaysOrange,
        foregroundColor: AppColors.heroForeground,
        disabledBackgroundColor: AppColors.disabledBackground,
        disabledForegroundColor: AppColors.disabledForeground,
      );

  static ButtonStyle primary(BuildContext _) => FilledButton.styleFrom(
        backgroundColor: AppColors.uiPrimary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.disabledBackground,
        disabledForegroundColor: AppColors.disabledForeground,
      );

  static ButtonStyle secondary(BuildContext _) => FilledButton.styleFrom(
        backgroundColor: AppColors.secondaryButtonBackground,
        foregroundColor: AppColors.uiPrimary,
        disabledBackgroundColor: AppColors.disabledBackground,
        disabledForegroundColor: AppColors.disabledForeground,
      );

  static ButtonStyle quiet(BuildContext _) => FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.uiPrimary,
        disabledBackgroundColor: AppColors.disabledBackground,
        disabledForegroundColor: AppColors.disabledForeground,
      );
}

final _appColorScheme = ColorScheme.fromSeed(
  seedColor: AppColors.munichWaysBlue,
).copyWith(
  primary: AppColors.uiPrimary,
  onPrimary: Colors.white,
  secondary: AppColors.munichWaysBlue,
  error: AppColors.danger,
  onError: Colors.white,
);

var themeData = ThemeData(
  visualDensity: VisualDensity.adaptivePlatformDensity,
  useMaterial3: true,
  colorScheme: _appColorScheme,
);
