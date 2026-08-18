import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:munich_ways/localization/app_locale_controller.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/map/map_screen.dart';
import 'package:munich_ways/ui/app_theme_controller.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final localeController = AppLocaleController();
  final themeController = AppThemeController();
  await themeController.load();
  themeController.startAutomaticUpdates();
  runApp(MunichWaysApp(
    localeController: localeController,
    themeController: themeController,
  ));
  localeController.load();
}

class MunichWaysApp extends StatelessWidget {
  MunichWaysApp({
    super.key,
    AppLocaleController? localeController,
    AppThemeController? themeController,
  })  : localeController = localeController ?? AppLocaleController(),
        themeController = themeController ?? AppThemeController();

  final AppLocaleController localeController;
  final AppThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeController),
        ChangeNotifierProvider.value(value: themeController),
      ],
      child: Consumer2<AppLocaleController, AppThemeController>(
        builder: (context, controller, appTheme, _) {
          final iconBrightness =
              appTheme.isDark ? Brightness.light : Brightness.dark;
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor:
                appTheme.isDark ? const Color(0xFF0B1218) : Colors.white,
            statusBarIconBrightness: iconBrightness,
            statusBarBrightness:
                appTheme.isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor:
                appTheme.isDark ? const Color(0xFF0B1218) : Colors.white,
            systemNavigationBarDividerColor:
                appTheme.isDark ? const Color(0xFF0B1218) : Colors.white,
            systemNavigationBarIconBrightness: iconBrightness,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarContrastEnforced: false,
          ));
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: themeData,
            darkTheme: darkThemeData,
            themeMode: appTheme.themeMode,
            locale: controller.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localeResolutionCallback: (locale, supportedLocales) {
              if (locale?.languageCode == 'de') return const Locale('de');
              return const Locale('en');
            },
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            onGenerateRoute: (settings) => MaterialPageRoute(
              settings: RouteSettings(name: settings.name),
              builder: (context) => MapScreen(),
            ),
          );
        },
      ),
    );
  }
}
