import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';

Future<void> showDirectRouteInfoDialog(BuildContext context) {
  final english = context.l10n.isEnglish;
  return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
            scrollable: true,
            title: Text(english ? 'Direct route' : 'Direkte Route'),
            content: Text(
              english
                  ? 'The direct route prioritizes the shortest rideable distance and may be more stressful. RadlNavi provides voice instructions and a comfort assessment. If unavailable, BRouter is used without voice instructions. This choice applies only to this trip.'
                  : 'Die direkte Route bevorzugt die kürzeste befahrbare Strecke und kann stressiger sein. RadlNavi liefert Abbiegeansagen und eine Komfortbewertung. Falls nicht verfügbar, wird BRouter ohne Ansagen verwendet. Die Auswahl gilt nur für diese Fahrt.',
            ),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.close))
            ],
          ));
}
