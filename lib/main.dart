import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:munich_ways/localization/app_locale_controller.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/map/map_screen.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final localeController = AppLocaleController();
  runApp(MunichWaysApp(localeController: localeController));
  localeController.load();
}

class MunichWaysApp extends StatelessWidget {
  MunichWaysApp({super.key, AppLocaleController? localeController})
      : localeController = localeController ?? AppLocaleController();

  final AppLocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: localeController,
      child: Consumer<AppLocaleController>(
        builder: (context, controller, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: themeData,
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
        ),
      ),
    );
  }
}
