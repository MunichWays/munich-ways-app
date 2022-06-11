import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/nav_routes.dart';
import 'package:munich_ways/ui/theme.dart';

class SideDrawer extends StatelessWidget {
  const SideDrawer({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String currentRoute = ModalRoute.of(context).settings.name;
    log.d(currentRoute);
    return Drawer(
      child: ListView(
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
                ))),
          ),
          NavigationDrawerItem(
              title: "Karte",
              icon: Icons.map,
              route: NavRoutes.map,
              currentRoute: currentRoute),
          NavigationDrawerItem(
            title: 'Info',
            icon: Icons.info_outline,
            route: NavRoutes.info,
            currentRoute: currentRoute,
          ),
          NavigationDrawerItem(
            title: 'Einstellungen',
            icon: Icons.settings,
            route: NavRoutes.settings,
            currentRoute: currentRoute,
          ),
        ],
      ),
    );
  }
}

class NavigationDrawerItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final String route;
  final String currentRoute;

  const NavigationDrawerItem({
    Key key,
    @required this.title,
    @required this.icon,
    @required this.route,
    @required this.currentRoute,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool selected = route == currentRoute;
    return Ink(
      color: selected ? AppColors.munichWaysBlue : null,
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
              color: selected ? Colors.white : Colors.black, fontSize: 16),
        ),
        leading: Icon(icon, color: selected ? Colors.white : Colors.black),
        onTap: () {
          Navigator.of(context).pushNamed(route);
        },
      ),
    );
  }
}
