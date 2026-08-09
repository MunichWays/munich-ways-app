import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/map/route_planner_sheet.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';

class MapRouteSelectionPanel extends StatelessWidget {
  const MapRouteSelectionPanel({
    super.key,
    required this.type,
    required this.onCancel,
  });

  final RoutePlannerPointType type;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final point = switch (type) {
      RoutePlannerPointType.start =>
        context.l10n.isEnglish ? 'start' : 'Startpunkt',
      RoutePlannerPointType.stop =>
        context.l10n.isEnglish ? 'intermediate stop' : 'Zwischenziel',
      RoutePlannerPointType.destination =>
        context.l10n.isEnglish ? 'destination' : 'Ziel',
    };
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BottomSheetDragHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 8, 12),
                child: Row(
                  children: [
                    const Icon(Icons.route),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.isEnglish
                                ? 'Plan route'
                                : 'Route planen',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            context.l10n.isEnglish
                                ? 'Touch and hold the $point on the map.'
                                : '$point auf der Karte lange antippen.',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.tr('Abbrechen'),
                      onPressed: onCancel,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
