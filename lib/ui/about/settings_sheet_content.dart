import 'package:flutter/material.dart';
import 'package:munich_ways/api/munichways/munichways_api.dart';
import 'package:munich_ways/ui/map/flutter_map/map_cache_store.dart';

/// Settings list for the map bottom sheet (no scaffold / drawer).
class SettingsSheetContent extends StatefulWidget {
  const SettingsSheetContent({super.key});

  @override
  State<SettingsSheetContent> createState() => _SettingsSheetContentState();
}

class _SettingsSheetContentState extends State<SettingsSheetContent> {
  late Future<String> _mapCacheStoreStatsFuture = MapCacheStore().getStats();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: ListTile.divideTiles(
        context: context,
        tiles: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            title: const Text('Radnetz neu laden'),
            subtitle: const Text(
              'Die bewerteten Strecken werden beim Karte öffnen erneut geladen.',
            ),
            trailing: const Icon(Icons.delete),
            onTap: () {
              MunichwaysApi().emptyCache();
            },
          ),
          FutureBuilder<String>(
            future: _mapCacheStoreStatsFuture,
            builder: (context, snapshot) {
              final stats = snapshot.hasData ? snapshot.data! : 'Lade …';
              return ListTile(
                title: const Text('Kartenspeicher neu laden'),
                subtitle: Text(stats),
                trailing: const Icon(Icons.delete),
                onTap: () async {
                  await MapCacheStore().emptyCache();
                  setState(() {
                    _mapCacheStoreStatsFuture = MapCacheStore().getStats();
                  });
                },
              );
            },
          ),
        ],
      ).toList(),
    );
  }
}
