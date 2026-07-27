import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/place_search/place_search_sheet.dart';

Future<void> showRoutePlannerSheet(
  BuildContext context, {
  required MapScreenViewModel model,
  LatLng? searchCenter,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _RoutePlannerSheet(
      model: model,
      searchCenter: searchCenter,
    ),
  );
}

class _RoutePlannerSheet extends StatefulWidget {
  const _RoutePlannerSheet({
    required this.model,
    required this.searchCenter,
  });

  final MapScreenViewModel model;
  final LatLng? searchCenter;

  @override
  State<_RoutePlannerSheet> createState() => _RoutePlannerSheetState();
}

class _RoutePlannerSheetState extends State<_RoutePlannerSheet> {
  Place? _start;
  Place? _destination;
  late List<Place> _stops;

  bool get _english => context.l10n.isEnglish;

  @override
  void initState() {
    super.initState();
    _start = widget.model.routeStart;
    _destination = widget.model.destination;
    _stops = List.of(widget.model.waypoints);
  }

  Future<Place?> _searchPlace() async {
    final result = await showPlaceSearchSheet(
      context,
      searchCenter: widget.searchCenter,
      showRoutePlannerOption: false,
    );
    return result is Place ? result : null;
  }

  String _name(Place place) {
    final name = place.displayName?.trim();
    return name == null || name.isEmpty
        ? (_english ? 'Selected place' : 'Gewählter Ort')
        : name;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _english ? 'Plan route' : 'Route planen',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                _english
                    ? 'Optionally select a different start or intermediate stop. '
                        'The default is your current position to the selected destination.'
                    : 'Optional anderen Startpunkt oder Zwischenhalt wählen. '
                        'Standard ist: Aktueller Standort zum gewählten Ziel.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              _PlaceRow(
                icon: Icons.trip_origin,
                title: _english ? 'Start' : 'Startpunkt',
                value: _start == null
                    ? (_english ? 'Current position' : 'Aktueller Standort')
                    : _name(_start!),
                onTap: () async {
                  final place = await _searchPlace();
                  if (place != null && mounted) setState(() => _start = place);
                },
                onClear:
                    _start == null ? null : () => setState(() => _start = null),
              ),
              for (var index = 0; index < _stops.length; index++)
                _PlaceRow(
                  icon: Icons.circle_outlined,
                  title: '${_english ? 'Stop' : 'Zwischenstopp'} ${index + 1}',
                  value: _name(_stops[index]),
                  onTap: () async {
                    final place = await _searchPlace();
                    if (place != null && mounted) {
                      setState(() => _stops[index] = place);
                    }
                  },
                  onClear: () => setState(() => _stops.removeAt(index)),
                ),
              TextButton.icon(
                onPressed: () async {
                  final place = await _searchPlace();
                  if (place != null && mounted) {
                    setState(() => _stops.add(place));
                  }
                },
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(
                  _english
                      ? 'Add intermediate stop'
                      : 'Zwischenstation hinzufügen',
                ),
              ),
              _PlaceRow(
                icon: Icons.location_on,
                title: _english ? 'Destination' : 'Ziel',
                value: _destination == null
                    ? (_english ? 'Select destination' : 'Ziel auswählen')
                    : _name(_destination!),
                onTap: () async {
                  final place = await _searchPlace();
                  if (place != null && mounted) {
                    setState(() => _destination = place);
                  }
                },
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _destination == null
                    ? null
                    : () {
                        widget.model.setRoutePlan(
                          start: _start,
                          stops: _stops,
                          destination: _destination!,
                        );
                        Navigator.pop(context);
                      },
                icon: const Icon(Icons.route),
                label: Text(_english ? 'Calculate route' : 'Route berechnen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: onTap,
      trailing: onClear == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              tooltip: context.l10n.isEnglish ? 'Remove' : 'Entfernen',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
    );
  }
}
