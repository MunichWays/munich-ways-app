import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/saved_routes_store.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/place_search/place_search_result.dart';
import 'package:munich_ways/ui/place_search/place_search_sheet.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';

enum RoutePlannerPointType { start, stop, destination }

class _RoutePoint {
  _RoutePoint(this.place) : key = UniqueKey();

  final Key key;
  Place? place;
}

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
  final sheetController = DraggableScrollableController();
  final initialStopCount = (initialPlan?.stops ?? model.waypoints).length;
  final initialChildSize = initialStopCount >= 2 ? 1.0 : 0.55;
  return showModalBottomSheet<RoutePlannerMapSelection>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      controller: sheetController,
      expand: false,
      initialChildSize: initialChildSize,
      minChildSize: 0.55,
      maxChildSize: 1,
      shouldCloseOnMinExtent: false,
      snap: true,
      snapSizes: const [0.55, 1],
      builder: (context, scrollController) => SizedBox.expand(
        child: _RoutePlannerSheet(
          model: model,
          searchCenter: searchCenter,
          initialPlan: initialPlan,
          scrollController: scrollController,
          sheetController: sheetController,
        ),
      ),
    ),
  ).whenComplete(sheetController.dispose);
}

class _RoutePlannerSheet extends StatefulWidget {
  const _RoutePlannerSheet({
    required this.model,
    required this.searchCenter,
    required this.initialPlan,
    required this.scrollController,
    required this.sheetController,
  });

  final MapScreenViewModel model;
  final LatLng? searchCenter;
  final RoutePlannerMapSelection? initialPlan;
  final ScrollController scrollController;
  final DraggableScrollableController sheetController;

  @override
  State<_RoutePlannerSheet> createState() => _RoutePlannerSheetState();
}

class _RoutePlannerSheetState extends State<_RoutePlannerSheet> {
  late List<_RoutePoint> _points;

  Place? get _start => _points.first.place;
  Place? get _destination => _points.last.place;
  List<Place> get _stops => [
        for (final point in _points.skip(1).take(_points.length - 2))
          if (point.place case final place?) place,
      ];

  bool get _english => context.l10n.isEnglish;

  @override
  void initState() {
    super.initState();
    final initialPlan = widget.initialPlan;
    final start = initialPlan?.start ??
        (widget.model.navigationStarted ? null : widget.model.routeStart);
    final destination = initialPlan?.destination ?? widget.model.destination;
    final stops = initialPlan?.stops ?? widget.model.waypoints;
    _points = [
      _RoutePoint(start),
      for (final stop in stops) _RoutePoint(stop),
      _RoutePoint(destination),
    ];
  }

  RoutePlannerPointType _typeForIndex(int index) {
    if (index == 0) return RoutePlannerPointType.start;
    if (index == _points.length - 1) {
      return RoutePlannerPointType.destination;
    }
    return RoutePlannerPointType.stop;
  }

  Future<void> _selectPlace(int index) async {
    final type = _typeForIndex(index);
    final stopIndex = type == RoutePlannerPointType.stop ? index - 1 : null;
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
    setState(() => _points[index].place = result);
  }

  Future<void> _addStop() async {
    final index = _points.length - 1;
    setState(() => _points.insert(index, _RoutePoint(null)));
    if (_points.length - 2 >= 2 && widget.sheetController.isAttached) {
      await widget.sheetController.animateTo(
        1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;
    }
    await _selectPlace(index);
  }

  void _deletePoint(int index) {
    setState(() {
      if (index == 0 || index == _points.length - 1) {
        _points[index].place = null;
      } else {
        _points.removeAt(index);
      }
    });
  }

  void _reorderPoint(int oldIndex, int newIndex) {
    setState(() {
      final point = _points.removeAt(oldIndex);
      _points.insert(newIndex, point);
    });
  }

  String _name(Place place) {
    final name = place.displayName?.trim();
    return name == null || name.isEmpty
        ? (_english ? 'Selected place' : 'Gewählter Ort')
        : name;
  }

  String _pointValue(int index) {
    final place = _points[index].place;
    if (place != null) return _name(place);
    if (index == 0) {
      return _english ? 'Current position' : 'Aktueller Standort';
    }
    if (index == _points.length - 1) {
      return _english ? 'Select destination' : 'Ziel auswählen';
    }
    return _english ? 'Select intermediate stop' : 'Zwischenziel auswählen';
  }

  Widget _pointLeading(int index) {
    if (index == 0) {
      final theme = Theme.of(context);
      final dark = theme.brightness == Brightness.dark;
      return CircleAvatar(
        radius: 18,
        backgroundColor:
            dark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
        child: const Icon(
          Icons.navigation,
          color: AppColors.mapAccentColor,
          size: 27,
        ),
      );
    }
    if (index == _points.length - 1) {
      return const Icon(
        Icons.sports_score,
        color: AppColors.mapRed,
        size: 30,
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: AppColors.munichWaysOrange,
      foregroundColor: Colors.white,
      child: Text(
        '$index',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _saveRoute() async {
    final destination = _destination;
    if (destination == null) return;
    var name = destination.displayName?.trim() ?? '';
    final selectedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_english ? 'Save route' : 'Route speichern'),
          content: TextFormField(
            initialValue: name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: _english ? 'Route name' : 'Routenname',
            ),
            onChanged: (value) => setDialogState(() => name = value),
            onFieldSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.pop(dialogContext, value);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.tr('Abbrechen')),
            ),
            FilledButton(
              onPressed: name.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, name),
              child: Text(_english ? 'Save' : 'Speichern'),
            ),
          ],
        ),
      ),
    );
    final trimmedName = selectedName?.trim();
    if (!mounted || trimmedName == null || trimmedName.isEmpty) return;
    try {
      await savedRoutesStore.add(
        SavedRoute(
          name: trimmedName,
          start: _start,
          stops: _stops,
          destination: destination,
        ),
      );
    } catch (error, stackTrace) {
      log.e('Saving route failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _english
                ? 'Saving the route failed.'
                : 'Route konnte nicht gespeichert werden.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_english ? 'Route saved.' : 'Route gespeichert.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 24),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DraggableBottomSheetRegion(
              controller: widget.sheetController,
              snapSizes: const [0.55, 1],
              onDismiss: () => Navigator.of(context).pop(),
              child: const BottomSheetDragHandle(),
            ),
            DraggableBottomSheetRegion(
              controller: widget.sheetController,
              snapSizes: const [0.55, 1],
              onDismiss: () => Navigator.of(context).pop(),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _english ? 'Plan route' : 'Route planen',
                      maxLines: 2,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton.filled(
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    style: AppButtonStyles.secondary(context),
                    tooltip: _english ? 'Save route' : 'Route speichern',
                    onPressed: _destination == null ? null : _saveRoute,
                    icon: const Icon(Icons.save_outlined),
                  ),
                  IconButton(
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 48,
                    ),
                    padding: const EdgeInsets.all(8),
                    tooltip: _english ? 'Close' : 'Schließen',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _points.length,
              onReorderItem: _reorderPoint,
              itemBuilder: (context, index) {
                final point = _points[index];
                return ReorderableDelayedDragStartListener(
                  key: point.key,
                  index: index,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (index == _points.length - 1)
                        TextButton.icon(
                          onPressed: _addStop,
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: Text(
                            _english
                                ? 'Add intermediate stop'
                                : 'Zwischenziel hinzufügen',
                          ),
                        ),
                      _PlaceRow(
                        leading: _pointLeading(index),
                        value: _pointValue(index),
                        backgroundColor: index == _points.length - 1
                            ? point.place == null
                                ? AppColors.uiPrimary
                                : Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer
                                    : AppColors.secondaryButtonBackground
                            : null,
                        foregroundColor: index == _points.length - 1
                            ? point.place == null
                                ? Colors.white
                                : Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer
                                    : AppColors.uiPrimary
                            : null,
                        onTap: () => _selectPlace(index),
                        onEdit: () => _selectPlace(index),
                        onClear: index == 0 && point.place != null
                            ? () => _deletePoint(index)
                            : null,
                        onDelete: point.place == null &&
                                (index == 0 || index == _points.length - 1)
                            ? null
                            : () => _deletePoint(index),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: AppButtonStyles.primary(context),
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
    );
  }
}

enum _PlaceRowAction { edit, delete }

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.leading,
    required this.value,
    required this.onTap,
    required this.onEdit,
    this.backgroundColor,
    this.foregroundColor,
    this.onClear,
    this.onDelete,
  });

  final Widget leading;
  final String value;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback? onClear;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: backgroundColor == null
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 8),
      tileColor: backgroundColor,
      textColor: foregroundColor,
      iconColor: foregroundColor,
      shape: backgroundColor == null
          ? null
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: SizedBox.square(
        dimension: 40,
        child: Center(child: leading),
      ),
      title: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onClear != null)
            IconButton(
              tooltip: context.l10n.isEnglish
                  ? 'Use current position'
                  : 'Aktuellen Standort verwenden',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
          PopupMenuButton<_PlaceRowAction>(
            tooltip: context.l10n.isEnglish ? 'More options' : 'Mehr Optionen',
            onSelected: (action) {
              switch (action) {
                case _PlaceRowAction.edit:
                  onEdit();
                  break;
                case _PlaceRowAction.delete:
                  onDelete?.call();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _PlaceRowAction.edit,
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined),
                    const SizedBox(width: 12),
                    Text(context.l10n.isEnglish ? 'Change' : 'Ändern'),
                  ],
                ),
              ),
              if (onDelete != null)
                PopupMenuItem(
                  value: _PlaceRowAction.delete,
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Text(context.l10n.isEnglish ? 'Delete' : 'Löschen'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
