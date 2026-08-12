import 'dart:async';

import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/ui/theme.dart';

enum MapLongPressAction {
  startRoute,
  addWaypoint,
  moveStart,
  moveDestination,
  showDetails,
}

Future<MapLongPressAction?> showMapLongPressActionOverlay(
  BuildContext context, {
  required Offset anchor,
  required Size overlaySize,
  StreetDetails? streetDetails,
  bool canAddWaypoint = false,
  bool canMoveStart = false,
  bool canMoveDestination = false,
}) {
  final result = Completer<MapLongPressAction?>();
  late final OverlayEntry entry;

  void close([MapLongPressAction? action]) {
    if (result.isCompleted) return;
    entry.remove();
    result.complete(action);
  }

  entry = OverlayEntry(
    builder: (overlayContext) {
      final l10n = overlayContext.l10n;
      final startRouteLabel =
          l10n.isEnglish ? 'Start route here' : 'Route hierhin';
      final addWaypointLabel =
          l10n.isEnglish ? 'Add intermediate stop' : 'Zwischenziel setzen';
      final moveStartLabel =
          l10n.isEnglish ? 'Move starting point' : 'Startpunkt verschieben';
      final moveDestinationLabel =
          l10n.isEnglish ? 'Move destination' : 'Ziel verschieben';
      final showDetailsLabel =
          l10n.isEnglish ? 'Show details' : 'Details anzeigen';
      final visibleLabels = [
        startRouteLabel,
        if (canAddWaypoint) addWaypointLabel,
        if (canMoveStart) moveStartLabel,
        if (canMoveDestination) moveDestinationLabel,
        if (streetDetails != null) showDetailsLabel,
      ];
      final textStyle = Theme.of(overlayContext).textTheme.bodyLarge;
      var widestLabel = 0.0;
      for (final label in visibleLabels) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: textStyle),
          maxLines: 1,
          textDirection: Directionality.of(overlayContext),
          textScaler: MediaQuery.textScalerOf(overlayContext),
        )..layout();
        if (painter.width > widestLabel) widestLabel = painter.width;
      }
      final maximumWidth = (overlaySize.width - 24).clamp(0.0, 320.0);
      final minimumWidth = maximumWidth.clamp(0.0, 180.0);
      final cardWidth = (widestLabel + 72).clamp(minimumWidth, maximumWidth);
      final actionCount = 1 +
          (canAddWaypoint ? 1 : 0) +
          (canMoveStart ? 1 : 0) +
          (canMoveDestination ? 1 : 0) +
          (streetDetails != null ? 1 : 0);
      final cardHeight = actionCount * 56.0 + (actionCount - 1);
      final cardLeft = (anchor.dx - cardWidth / 2)
          .clamp(12.0, overlaySize.width - cardWidth - 12);
      final fitsBelow = anchor.dy + 18 + cardHeight <= overlaySize.height - 12;
      final cardTop = fitsBelow
          ? anchor.dy + 18
          : (anchor.dy - 50 - cardHeight)
              .clamp(12.0, overlaySize.height - cardHeight - 12);

      Widget actionRow({
        required IconData icon,
        required String label,
        required MapLongPressAction action,
      }) {
        return InkWell(
          onTap: () => close(action),
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.mapRouteColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: close,
            ),
          ),
          Positioned(
            left: anchor.dx - 22,
            top: anchor.dy - 44,
            child: const IgnorePointer(
              child: Icon(
                Icons.location_pin,
                size: 44,
                color: AppColors.mapAccentColor,
                shadows: [
                  Shadow(color: Colors.white, blurRadius: 3),
                  Shadow(color: Colors.black54, blurRadius: 5),
                ],
              ),
            ),
          ),
          Positioned(
            left: cardLeft,
            top: cardTop,
            width: cardWidth,
            child: Material(
              key: const ValueKey('map-long-press-action-card'),
              elevation: 10,
              color: Theme.of(overlayContext).colorScheme.surface,
              shadowColor: Colors.black45,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(
                  color: AppColors.mapAccentColor,
                  width: 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  actionRow(
                    icon: Icons.navigation_outlined,
                    label: startRouteLabel,
                    action: MapLongPressAction.startRoute,
                  ),
                  if (canAddWaypoint) ...[
                    const Divider(height: 1),
                    actionRow(
                      icon: Icons.add_location_alt_outlined,
                      label: addWaypointLabel,
                      action: MapLongPressAction.addWaypoint,
                    ),
                  ],
                  if (canMoveStart) ...[
                    const Divider(height: 1),
                    actionRow(
                      icon: Icons.trip_origin,
                      label: moveStartLabel,
                      action: MapLongPressAction.moveStart,
                    ),
                  ],
                  if (canMoveDestination) ...[
                    const Divider(height: 1),
                    actionRow(
                      icon: Icons.outlined_flag,
                      label: moveDestinationLabel,
                      action: MapLongPressAction.moveDestination,
                    ),
                  ],
                  if (streetDetails != null) ...[
                    const Divider(height: 1),
                    actionRow(
                      icon: Icons.info_outline,
                      label: showDetailsLabel,
                      action: MapLongPressAction.showDetails,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  Overlay.of(context, rootOverlay: true).insert(entry);
  return result.future;
}
