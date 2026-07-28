import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/place_search/place_search_result.dart';
import 'package:munich_ways/ui/place_search/place_search_sheet.dart';

enum RoutePlannerPointType { start, stop, destination }

class RoutePlannerMapSelection {
  const RoutePlannerMapSelection({
    required this.type,
    required this.stopIndex,
    required this.start,
    required this.stops,
    required this.destination,
  });

  final RoutePlannerPointType type;
  final int? stopIndex;
  final Place? start;
  final List<Place> stops;
  final Place? destination;

  RoutePlannerMapSelection withSelectedPlace(Place place) {
    final updatedStops = List<Place>.of(stops);
    if (type == RoutePlannerPointType.stop) {
      final index = stopIndex ?? updatedStops.length;
      if (index < updatedStops.length) {
        updatedStops[index] = place;
      } else {
        updatedStops.add(place);
      }
    }
    return RoutePlannerMapSelection(
      type: type,
      stopIndex: stopIndex,
      start: type == RoutePlannerPointType.start ? place : start,
      stops: updatedStops,
      destination:
          type == RoutePlannerPointType.destination ? place : destination,
    );
  }
}

Future<RoutePlannerMapSelection?> showRoutePlannerSheet(
  BuildContext context, {
  required MapScreenViewModel model,
  LatLng? searchCenter,
  RoutePlannerMapSelection? initialPlan,
}) {
  return showModalBottomSheet<RoutePlannerMapSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _RoutePlannerSheet(
      model: model,
      searchCenter: searchCenter,
      initialPlan: initialPlan,
    ),
  );
}

class _RoutePlannerSheet extends StatefulWidget {
  const _RoutePlannerSheet({
    required this.model,
    required this.searchCenter,
    required this.initialPlan,
  });

  final MapScreenViewModel model;
  final LatLng? searchCenter;
  final RoutePlannerMapSelection? initialPlan;

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
    final initialPlan = widget.initialPlan;
    _start = initialPlan?.start ??
        (widget.model.navigationStarted ? null : widget.model.routeStart);
    _destination = initialPlan?.destination ?? widget.model.destination;
    _stops = List.of(initialPlan?.stops ?? widget.model.waypoints);
  }

  Future<void> _selectPlace(
    RoutePlannerPointType type, {
    int? stopIndex,
  }) async {
    final result = await showPlaceSearchSheet(
      context,
      searchCenter: widget.searchCenter,
      showRoutePlannerOption: false,
    );
    if (!mounted) return;
    if (result == PlaceSearchSheetResult.selectOnMap) {
      Navigator.pop(
        context,
        RoutePlannerMapSelection(
          type: type,
          stopIndex: stopIndex,
          start: _start,
          stops: List.of(_stops),
          destination: _destination,
        ),
      );
      return;
    }
    if (result is! Place) return;
    setState(() {
      switch (type) {
        case RoutePlannerPointType.start:
          _start = result;
          break;
        case RoutePlannerPointType.stop:
          final index = stopIndex ?? _stops.length;
          if (index < _stops.length) {
            _stops[index] = result;
          } else {
            _stops.add(result);
          }
          break;
        case RoutePlannerPointType.destination:
          _destination = result;
          break;
      }
    });
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
                onTap: () => _selectPlace(RoutePlannerPointType.start),
                onClear:
                    _start == null ? null : () => setState(() => _start = null),
              ),
              for (var index = 0; index < _stops.length; index++)
                _PlaceRow(
                  icon: Icons.circle_outlined,
                  title: '${_english ? 'Stop' : 'Zwischenstopp'} ${index + 1}',
                  value: _name(_stops[index]),
                  onTap: () => _selectPlace(
                    RoutePlannerPointType.stop,
                    stopIndex: index,
                  ),
                  onClear: () => setState(() => _stops.removeAt(index)),
                ),
              TextButton.icon(
                onPressed: () => _selectPlace(
                  RoutePlannerPointType.stop,
                  stopIndex: _stops.length,
                ),
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
                onTap: () => _selectPlace(RoutePlannerPointType.destination),
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
