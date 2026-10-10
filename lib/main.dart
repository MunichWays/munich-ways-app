import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/localization/app_locale_controller.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/speech/speech_input_controller.dart';
import 'package:munich_ways/ui/map/map_screen.dart';
import 'package:munich_ways/ui/first_run/first_run_safety_gate.dart';
import 'package:munich_ways/ui/app_theme_controller.dart';
import 'package:munich_ways/ui/energy_saving_controller.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Decide before settings/camera writes can make a fresh install look like an
  // update. Only small local files are touched; network POIs stay independent.
  var showSafetyNotice = false;
  var showTutorial = false;
  try {
    await initialPlacesStore.ensureInitialized();
    showSafetyNotice = await initialPlacesStore.shouldShowSafetyNotice();
    showTutorial = await initialPlacesStore.shouldShowTutorial();
  } catch (error, stackTrace) {
    log.w('Initializing first-run data failed',
        error: error, stackTrace: stackTrace);
  }
  final localeController = AppLocaleController();
  final themeController = AppThemeController();
  final energySavingController = EnergySavingController();
  await themeController.load();
  await energySavingController.start();
  themeController.setEnergySavingEnabled(
    energySavingController.effectiveEnabled,
  );
  energySavingController.addListener(() {
    themeController.setEnergySavingEnabled(
      energySavingController.effectiveEnabled,
    );
  });
  themeController.startAutomaticUpdates();
  runApp(MunichWaysApp(
    showSafetyNotice: showSafetyNotice,
    showTutorial: showTutorial,
    localeController: localeController,
    themeController: themeController,
    energySavingController: energySavingController,
  ));
  localeController.load();
}

class MunichWaysApp extends StatelessWidget {
  MunichWaysApp({
    super.key,
    this.showSafetyNotice = false,
    this.showTutorial = false,
    AppLocaleController? localeController,
    AppThemeController? themeController,
    EnergySavingController? energySavingController,
  })  : localeController = localeController ?? AppLocaleController(),
        themeController = themeController ?? AppThemeController(),
        energySavingController =
            energySavingController ?? EnergySavingController();

  final AppLocaleController localeController;
  final bool showSafetyNotice;
  final bool showTutorial;
  final AppThemeController themeController;
  final EnergySavingController energySavingController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SpeechInputController()),
        ChangeNotifierProvider.value(value: localeController),
        ChangeNotifierProvider.value(value: themeController),
        ChangeNotifierProvider.value(value: energySavingController),
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
              builder: (context) => FirstRunSafetyGate(
                showNotice: showSafetyNotice,
                onDismiss: initialPlacesStore.dismissSafetyNotice,
                showTutorial: showTutorial,
                onDismissTutorial: initialPlacesStore.dismissTutorial,
                builder: (_, interactionsEnabled) => MapScreen(
                  startupInteractionsEnabled: interactionsEnabled,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
