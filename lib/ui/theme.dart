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
  static const pavedWay = Color(0xFF4F98A5);
  static const pavedWayDark = Color(0xFF5FABB5);
  static const minorStreet = Color(0xFFB8D3C7);
  static const minorStreetDark = Color(0xFF46675C);

  static const mapButtonBackground = Color(0xFF4D4D4D);
  static const mapButtonForeground = Colors.white;
  static const mapButtonForegroundActive = Color(0xFF65B8FF);

  static const mapAccentColor = Color(0xFF2196F3);
  static const mapRouteColor = Color(0xFF0057D9);
  static const mapRouteColorDark = Color(0xFF1677FF);
  static const favoriteHighlight = Color(0xFFDCEEFF);
  static const favoriteHighlightDark = Color(0xFF243B4A);

  static Color pavedWayFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? pavedWayDark : pavedWay;

  static Color minorStreetFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? minorStreetDark
          : minorStreet;

  static Color favoriteHighlightFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? favoriteHighlightDark
          : favoriteHighlight;

  static Color getPolylineColor(_color, {bool dark = false}) {
    switch (_color) {
      case "schwarz":
        return dark ? const Color(0xFFC7CDD1) : mapBlack;
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

  static ButtonStyle primary(BuildContext context) => FilledButton.styleFrom(
        backgroundColor: AppColors.uiPrimary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : AppColors.disabledBackground,
        disabledForegroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
            : AppColors.disabledForeground,
      );

  static ButtonStyle secondary(BuildContext context) => FilledButton.styleFrom(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.secondaryContainer
            : AppColors.secondaryButtonBackground,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.onSecondaryContainer
            : AppColors.uiPrimary,
        disabledBackgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : AppColors.disabledBackground,
        disabledForegroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
            : AppColors.disabledForeground,
      );

  static ButtonStyle quiet(BuildContext context) => FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.primary
            : AppColors.uiPrimary,
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

final _darkColorScheme = ColorScheme.fromSeed(
  seedColor: AppColors.munichWaysBlue,
  brightness: Brightness.dark,
).copyWith(
  primary: const Color(0xFF8CC8FF),
  secondary: const Color(0xFF9CCBFA),
  error: const Color(0xFFFFB4AB),
);

var darkThemeData = ThemeData(
  visualDensity: VisualDensity.adaptivePlatformDensity,
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: _darkColorScheme,
  scaffoldBackgroundColor: const Color(0xFF101418),
  canvasColor: const Color(0xFF151A1F),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Color(0xFF151A1F),
    surfaceTintColor: Colors.transparent,
  ),
);
