import 'package:munich_ways/api/route_transfer_io.dart';
import 'package:munich_ways/model/route_transfer.dart';
import 'package:munich_ways/ui/map/route_import_dialog.dart';
import 'package:munich_ways/ui/map/route_import_source_dialog.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/saved_routes_store.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/ui/map/map_overlay/map_route_comfort_summary.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_overlay/route_variant_comparison.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/route_point_badge.dart';
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
  SavedRoutesStore? routesStore,
}) async {
  final sheetController = DraggableScrollableController();
  ModalRoute<RoutePlannerMapSelection>? sheetRoute;
  try {
    final result = await showModalBottomSheet<RoutePlannerMapSelection>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useSafeArea: true,
      builder: (sheetContext) {
        sheetRoute = ModalRoute.of<RoutePlannerMapSelection>(sheetContext);
        return DraggableScrollableSheet(
          controller: sheetController,
          expand: false,
          initialChildSize: 1.0,
          minChildSize: 0.7,
          maxChildSize: 1,
          shouldCloseOnMinExtent: false,
          snap: true,
          snapSizes: const [0.7, 1],
          builder: (context, scrollController) => SizedBox.expand(
            child: _RoutePlannerSheet(
              model: model,
              searchCenter: searchCenter,
              initialPlan: initialPlan,
              scrollController: scrollController,
              sheetController: sheetController,
              routesStore: routesStore ?? savedRoutesStore,
            ),
          ),
        );
      },
    );
    // The map-selection UI must not appear while this sheet is still animating.
    await sheetRoute?.completed;
    return result;
  } finally {
    sheetController.dispose();
  }
}

class _RoutePlannerSheet extends StatefulWidget {
  const _RoutePlannerSheet({
    required this.model,
    required this.searchCenter,
    required this.initialPlan,
    required this.scrollController,
    required this.sheetController,
    required this.routesStore,
  });

  final MapScreenViewModel model;
  final LatLng? searchCenter;
  final RoutePlannerMapSelection? initialPlan;
  final ScrollController scrollController;
  final DraggableScrollableController sheetController;
  final SavedRoutesStore routesStore;

  @override
  State<_RoutePlannerSheet> createState() => _RoutePlannerSheetState();
}

class _RoutePlannerSheetState extends State<_RoutePlannerSheet> {
  late List<_RoutePoint> _points;
  bool _routePlanEdited = false;
  bool _importing = false;

  Place? get _start => _points.first.place;
  Place? get _destination => _points.last.place;
  List<Place> get _stops => [
        for (final point in _points.skip(1).take(_points.length - 2))
          if (point.place case final place?) place,
      ];

  bool get _english => context.l10n.isEnglish;

  bool get _showsRouteComfort =>
      !widget.model.hasRouteComparison &&
      !_routePlanEdited &&
      widget.initialPlan == null &&
      widget.model.route.state == MapRouteState.SHOWN &&
      widget.model.route.comfortState != RouteComfortState.unavailable;

  String? _destinationAccessLabel() {
    final mapRoute = widget.model.route;
    final points = mapRoute.route?.destinationConnector;
    if (_routePlanEdited ||
        widget.initialPlan != null ||
        mapRoute.state != MapRouteState.SHOWN ||
        points == null ||
        points.length < 2) return null;
    var meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      meters += const Distance().as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return '${_english ? 'Access to destination' : 'Zielzugang'}: ${meters.round()} m';
  }

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
    _scrollToEndAfterLayout();
  }

  void _scrollToEndAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) return;
      // Selecting on the map closes this sheet. Do not start a competing
      // scroll animation while its exit animation is running.
      if (ModalRoute.of(context)?.animation?.status ==
          AnimationStatus.reverse) {
        return;
      }
      final end = widget.scrollController.position.maxScrollExtent;
      if (end <= 0) return;
      widget.scrollController.animateTo(end,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic);
    });
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
      enableSpeechInput: !widget.model.navigationStarted,
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
      _points[index].place = result;
      _routePlanEdited = true;
    });
  }

  Future<void> _addStop() async {
    final index = _points.length - 1;
    setState(() {
      _points.insert(index, _RoutePoint(null));
      _routePlanEdited = true;
    });
    if (_points.length - 2 >= 1 && widget.sheetController.isAttached) {
      await widget.sheetController.animateTo(
        1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;
    }
    await _selectPlace(index);
    if (mounted) _scrollToEndAfterLayout();
  }

  void _deletePoint(int index) {
    setState(() {
      _routePlanEdited = true;
      if (index == 0 || index == _points.length - 1) {
        _points[index].place = null;
      } else {
        _points.removeAt(index);
      }
    });
  }

  void _reorderPoint(int oldIndex, int newIndex) {
    setState(() {
      _routePlanEdited = true;
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

  String _pointLabel(int index) {
    if (index == 0) {
      return 'Start';
    }
    if (index == _points.length - 1) {
      return _english ? 'Destination' : 'Ziel';
    }
    return _english ? 'Intermediate stop $index' : 'Zwischenziel $index';
  }

  Future<void> _importRoute() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final transfer = await showRouteImportSourceDialog(context);
      if (transfer == null || !mounted) return;
      final accepted = await showRouteImportDialog(
          context, transfer, widget.model,
          store: widget.routesStore);
      if (accepted && mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_english
                ? 'The route could not be used or saved. Please try again.'
                : 'Die Route konnte nicht übernommen oder gespeichert werden. Bitte erneut versuchen.')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _exportRoute() async {
    try {
      final current = widget.model.route.route;
      if (current == null || _routePlanEdited || _destination == null) return;
      final transfer = (widget.model.isOriginalRoute
              ? widget.model.selectedSavedRoute?.snapshot
              : null) ??
          RouteTransfer.fromRoute(
              current,
              [
                _start ?? Place('Start', current.points.first),
                ..._stops,
                _destination!
              ],
              widget.model.selectedSavedRoute?.name ?? 'MunichWays-Route',
              widget.model.temporaryShortestRouteEnabled
                  ? 'direct'
                  : 'standard');
      final box = context.findRenderObject() as RenderBox?;
      await RouteTransferIo.export(transfer,
          origin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_english
                ? 'Export failed. Please retry.'
                : 'Export fehlgeschlagen. Bitte erneut versuchen.')));
    }
  }

  Future<void> _saveRoute() async {
    final destination = _destination;
    if (destination == null) return;
    if (widget.model.isOriginalRoute && _routePlanEdited) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_english
              ? 'Plan the changed route before saving.'
              : 'Geänderte Route vor dem Speichern neu planen.')));
      return;
    }
    final originalRoute = widget.model.selectedSavedRoute;
    var name = originalRoute?.name ?? destination.displayName?.trim() ?? '';
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
      var savedRoute = SavedRoute(
        name: trimmedName,
        snapshotId:
            widget.model.isOriginalRoute ? originalRoute?.snapshotId : null,
        snapshot: widget.model.isOriginalRoute ? originalRoute?.snapshot : null,
        start: _start,
        stops: _stops,
        destination: destination,
        isFavorite: trimmedName == originalRoute?.name
            ? originalRoute!.isFavorite
            : false,
        favoriteOrder: trimmedName == originalRoute?.name
            ? originalRoute!.favoriteOrder
            : null,
      );
      if (savedRoute.snapshot != null && savedRoute.snapshotId == null) {
        savedRoute = await widget.routesStore.addImported(savedRoute);
      } else {
        await widget.routesStore.add(savedRoute);
      }
      widget.model.markRouteSaved(savedRoute);
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

  Widget _headerAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) =>
      IconButton.filled(
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        style: AppButtonStyles.secondary(context),
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 4),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DraggableBottomSheetRegion(
            controller: widget.sheetController,
            snapSizes: const [0.7, 1],
            onDismiss: () => Navigator.of(context).pop(),
            child: const BottomSheetDragHandle(),
          ),
          DraggableBottomSheetRegion(
            controller: widget.sheetController,
            snapSizes: const [0.7, 1],
            onDismiss: () => Navigator.of(context).pop(),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Route',
                    maxLines: 2,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _headerAction(
                  tooltip: _english ? 'Import route' : 'Route importieren',
                  icon: Icons.file_upload_outlined,
                  onPressed: _importing ? null : _importRoute,
                ),
                const SizedBox(width: 4),
                ListenableBuilder(
                  listenable: widget.model,
                  builder: (context, _) => _headerAction(
                    tooltip: _english ? 'Export GPX' : 'GPX exportieren',
                    icon: Icons.file_download_outlined,
                    onPressed:
                        widget.model.route.route == null || _routePlanEdited
                            ? null
                            : _exportRoute,
                  ),
                ),
                const SizedBox(width: 4),
                _headerAction(
                  tooltip: _english ? 'Save route' : 'Route speichern',
                  onPressed: _destination == null ? null : _saveRoute,
                  icon: Icons.save_outlined,
                ),
              ],
            ),
          ),
          Expanded(
              child: SingleChildScrollView(
            controller: widget.scrollController,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.model.isOriginalRoute)
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(_english
                            ? 'Original route: unchanged use keeps the imported track. Editing places and planning creates a new route.'
                            : 'Originalstrecke: unveränderte Übernahme behält den Track. Orte ändern und planen erzeugt eine neue Route.')),
                  const SizedBox(height: 4),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _points.length,
                    onReorderItem: _reorderPoint,
                    itemBuilder: (context, index) {
                      final point = _points[index];
                      return Column(
                        key: point.key,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (index == _points.length - 1)
                            TextButton.icon(
                              onPressed: _stops.length >= RouteTransfer.maxStops
                                  ? null
                                  : _addStop,
                              icon: const Icon(Icons.add_location_alt_outlined),
                              label: Text(
                                _english
                                    ? 'Add intermediate stop'
                                    : 'Zwischenziel hinzufügen',
                              ),
                            ),
                          ReorderableDelayedDragStartListener(
                            index: index,
                            child: _PlaceRow(
                              leading: RoutePointBadge(
                                  index: index, count: _points.length),
                              label: index == _points.length - 1
                                  ? ListenableBuilder(
                                      listenable: widget.model,
                                      builder: (context, _) {
                                        final access =
                                            _destinationAccessLabel();
                                        return Text(
                                          access ?? _pointLabel(index),
                                          semanticsLabel: access == null
                                              ? null
                                              : '${_pointLabel(index)}. $access',
                                          key: access == null
                                              ? null
                                              : const ValueKey(
                                                  'planner-destination-access'),
                                        );
                                      },
                                    )
                                  : Text(_pointLabel(index)),
                              value: _pointValue(index),
                              backgroundColor: index == _points.length - 1
                                  ? point.place == null
                                      ? AppColors.munichWaysOrange
                                      : Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer
                                          : AppColors.secondaryButtonBackground
                                  : null,
                              foregroundColor: index == _points.length - 1
                                  ? point.place == null
                                      ? AppColors.heroForeground
                                      : Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer
                                          : AppColors.uiPrimary
                                  : null,
                              onTap: () => _selectPlace(index),
                              onEdit: () => _selectPlace(index),
                              onMoveToStart: index != 0 && point.place != null
                                  ? () => _reorderPoint(index, 0)
                                  : null,
                              onMoveToDestination: index !=
                                          _points.length - 1 &&
                                      point.place != null
                                  ? () =>
                                      _reorderPoint(index, _points.length - 1)
                                  : null,
                              onClear: index == 0 && point.place != null
                                  ? () => _deletePoint(index)
                                  : null,
                              onDelete: point.place == null &&
                                      (index == 0 ||
                                          index == _points.length - 1)
                                  ? null
                                  : () => _deletePoint(index),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  ListenableBuilder(
                    listenable: widget.model,
                    builder: (context, _) => !_showsRouteComfort
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: RouteComfortContent(
                              route: widget.model.route,
                              onRetry: () => widget.model.retryRouteComfort(),
                              compact: true,
                            ),
                          ),
                  ),
                  ListenableBuilder(
                    listenable: widget.model,
                    builder: (context, _) =>
                        _routePlanEdited || widget.initialPlan != null
                            ? const SizedBox.shrink()
                            : RouteVariantComparison(model: widget.model),
                  ),
                  const SizedBox(height: 8),
                ]),
          )),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                constraints:
                    const BoxConstraints.tightFor(width: 48, height: 48),
                tooltip: _english ? 'Close' : 'Schließen',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: AppButtonStyles.primary(context),
                  onPressed: _destination == null
                      ? null
                      : () {
                          if (widget.model.isOriginalRoute &&
                              !_routePlanEdited &&
                              widget.initialPlan == null) {
                            Navigator.pop(context);
                            return;
                          }
                          if (widget.model.navigationStarted &&
                              !_routePlanEdited &&
                              widget.initialPlan == null) {
                            // Use current progress, not the planner's opening snapshot.
                            if (!widget.model.isOriginalRoute)
                              widget.model.refreshRoute();
                          } else {
                            widget.model.setRoutePlan(
                              start: widget.model.navigationStarted
                                  ? null
                                  : _start,
                              stops: _stops,
                              destination: _destination!,
                            );
                          }
                          Navigator.pop(context);
                        },
                  icon: const Icon(Icons.route),
                  label: Text(_english ? 'Calculate route' : 'Route berechnen'),
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

enum _PlaceRowAction { edit, delete, moveToStart, moveToDestination }

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.leading,
    required this.value,
    required this.label,
    required this.onTap,
    required this.onEdit,
    this.backgroundColor,
    this.foregroundColor,
    this.onClear,
    this.onDelete,
    this.onMoveToStart,
    this.onMoveToDestination,
  });

  final Widget leading;
  final String value;
  final Widget label;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback? onClear;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveToStart;
  final VoidCallback? onMoveToDestination;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      minTileHeight: 48,
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
      title: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: label,
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
                case _PlaceRowAction.moveToStart:
                  onMoveToStart?.call();
                  break;
                case _PlaceRowAction.moveToDestination:
                  onMoveToDestination?.call();
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
              if (onMoveToStart != null)
                PopupMenuItem(
                  value: _PlaceRowAction.moveToStart,
                  child: Text(
                      context.l10n.isEnglish ? 'Use as start' : 'Als Start'),
                ),
              if (onMoveToDestination != null)
                PopupMenuItem(
                  value: _PlaceRowAction.moveToDestination,
                  child: Text(context.l10n.isEnglish
                      ? 'Use as destination'
                      : 'Als Ziel'),
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
