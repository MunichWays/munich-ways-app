import 'package:flutter/material.dart';
import 'package:munich_ways/ui/theme.dart';

class SideDrawer extends StatelessWidget {
  const SideDrawer({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
          ListTile(
            title: Text('Karte'),
            leading: Icon(Icons.map),
            onTap: () {},
          ),
          ListTile(
            title: Text('Über MunichWays'),
            leading: Icon(Icons.bookmark_border),
            onTap: () {},
          ),
          ListTile(
            title: Text('Einstellungen'),
            leading: Icon(Icons.settings),
            onTap: () {},
          ),
          ListTile(
            title: Text('Info'),
            leading: Icon(Icons.info_outline),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}