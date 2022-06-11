import 'package:flutter/material.dart';
import 'package:munich_ways/ui/map/munichways_api.dart';
import 'package:munich_ways/ui/side_drawer.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: scaffoldMessengerKey,
      child: Scaffold(
        drawer: SideDrawer(),
        appBar: AppBar(
          title: Text("Einstellungen"),
        ),
        body: ListView(
          children: ListTile.divideTiles(
            context: context,
            tiles: [
              ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                title: Text('Radnetz neu laden'),
                subtitle:
                    Text('Das Radlnetz wird beim Karte öffnen erneut geladen.'),
                trailing: Icon(Icons.delete),
                onTap: () {
                  MunichwaysApi().emptyCache();
                },
              ),
            ],
          ).toList(),
        ),
      ),
    );
  }
}
