import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/nav_routes.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SideDrawer extends StatelessWidget {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  SideDrawer({
    Key? key,
  }) : super(key: key);

  void _displayError(String errorMsg, BuildContext context) {
    scaffoldMessengerKey.currentState!.hideCurrentSnackBar();
    scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
      content: Text(errorMsg),
      duration: Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    String? currentRoute = ModalRoute.of(context)!.settings.name;
    log.d(currentRoute);
    return ScaffoldMessenger(
      key: scaffoldMessengerKey,
      child: Scaffold(
        drawer: MyDrawer(),
        body: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              child: Image(image: AssetImage('images/logo.png')),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.munichWaysBlue,
                    width: 1,
                  ),
                ),
              ),
            ),
            NavigationDrawerItem(
              title: "Karte",
              icon: Icons.map,
              route: NavRoutes.map,
              currentRoute: currentRoute,
            ),
            NavigationDrawerItem(
              title: 'Einstellungen',
              icon: Icons.settings,
              route: NavRoutes.settings,
              currentRoute: currentRoute,
            ),
            ListTile(
              title: Text(
                'Spenden',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                'munichways.de/spenden',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              leading: Icon(Icons.touch_app_outlined,
                  color: Theme.of(context).colorScheme.onSurface),
              onTap: () async {
                const url = 'https://munichways.de/spenden';
                if (await canLaunchUrlString(url)) {
                  await launchUrlString(url);
                } else {
                  _displayError(
                      'Keine App zum Öffnen von munichways.de gefunden',
                      context);
                }
              },
            ),
            NavigationDrawerItem(
              title: 'Info',
              icon: Icons.info_outline,
              route: NavRoutes.info,
              currentRoute: currentRoute,
            ),
          ],
        ),
      ),
    );
  }
}

class MyDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SideDrawer();
  }
}

class NavigationDrawerItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final String route;
  final String? currentRoute;

  const NavigationDrawerItem({
    Key? key,
    required this.title,
    required this.icon,
    required this.route,
    required this.currentRoute,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool selected = route == currentRoute;
    return Ink(
      color: selected ? Theme.of(context).primaryColor : null,
      child: ListTile(
        title: Text(title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                )),
        leading: Icon(icon,
            color: selected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface),
        onTap: () {
          Navigator.of(context).pushNamed(route);
        },
      ),
    );
  }
}
