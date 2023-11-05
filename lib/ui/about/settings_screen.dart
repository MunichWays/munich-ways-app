import 'package:flutter/material.dart';
import 'package:munich_ways/api/munichways/munichways_api.dart';
import 'package:munich_ways/ui/map/flutter_map/map_cache_store.dart';
import 'package:munich_ways/ui/side_drawer.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  Future<String> mapCacheStoreStatsFuture = MapCacheStore().getStats();

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
                subtitle: Text(
                    'Die bewerteten Strecken werden beim Karte öffnen erneut geladen.'),
                trailing: Icon(Icons.delete),
                onTap: () {
                  MunichwaysApi().emptyCache();
                },
              ),
              FutureBuilder<String>(
                  future: mapCacheStoreStatsFuture,
                  builder: (context, snapshot) {
                    String stats;
                    if (snapshot.hasData) {
                      stats = snapshot.data!;
                    } else {
                      stats = "Lade ...";
                    }
                    ;
                    return ListTile(
                      title: Text('Kartenspeicher neu laden'),
                      subtitle: Text(stats),
                      trailing: Icon(Icons.delete),
                      onTap: () async {
                        await MapCacheStore().emptyCache();
                        setState(() {
                          mapCacheStoreStatsFuture = MapCacheStore().getStats();
                        });
                      },
                    );
                  }),
            ],
          ).toList(),
        ),
      ),
    );
  }
}
