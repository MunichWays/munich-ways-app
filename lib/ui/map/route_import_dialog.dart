import 'dart:math';
import 'package:flutter/material.dart';
import 'package:munich_ways/api/saved_routes_store.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/route_transfer.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/theme.dart';

Future<bool> showRouteImportDialog(
    BuildContext context, RouteTransfer transfer, MapScreenViewModel model,
    {SavedRoutesStore? store}) async {
  final english = context.l10n.isEnglish;
  final name = TextEditingController(text: transfer.name);
  try {
    final save = await showDialog<bool>(
        context: context,
        builder: (context) => ValueListenableBuilder<TextEditingValue>(
            valueListenable: name,
            builder: (context, value, _) {
              final media = MediaQuery.of(context);
              final stops = transfer.plan.length - 2;
              final validName = value.text.trim().isNotEmpty;
              final compact =
                  media.size.height - media.viewInsets.vertical < 480 ||
                      media.textScaler.scale(14) > 21;
              final actions = Padding(
                  padding: EdgeInsets.fromLTRB(
                      compact ? 0 : 20, 8, compact ? 0 : 20, 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                            style: AppButtonStyles.secondary(context),
                            onPressed: validName
                                ? () => Navigator.pop(context, false)
                                : null,
                            child: Text(
                                english
                                    ? 'Use without saving'
                                    : 'Ohne Speichern übernehmen',
                                textAlign: TextAlign.center)),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                            onPressed: validName
                                ? () => Navigator.pop(context, true)
                                : null,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                                english
                                    ? 'Save and use'
                                    : 'Speichern & übernehmen',
                                textAlign: TextAlign.center)),
                      ]));
              return Dialog(
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: 720,
                      maxHeight: max(0,
                          media.size.height - media.viewInsets.vertical - 48)),
                  child: SizedBox(
                      width: double.infinity,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 12, 8, 4),
                                child: Row(children: [
                                  Expanded(
                                      child: Text(
                                          english
                                              ? 'Import route'
                                              : 'Route importieren',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge)),
                                  IconButton(
                                      tooltip: english ? 'Cancel' : 'Abbrechen',
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.close)),
                                ])),
                            Flexible(
                                child: SingleChildScrollView(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: ColoredBox(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerLow,
                                                  child: SizedBox(
                                                      height: 210,
                                                      child: RouteImportPreview(
                                                          transfer:
                                                              transfer)))),
                                          const SizedBox(height: 16),
                                          TextField(
                                              controller: name,
                                              maxLength: 200,
                                              decoration: InputDecoration(
                                                  border:
                                                      const OutlineInputBorder(),
                                                  counterText: '',
                                                  labelText: english
                                                      ? 'Route name'
                                                      : 'Routenname')),
                                          const SizedBox(height: 12),
                                          Wrap(
                                              spacing: 12,
                                              runSpacing: 8,
                                              children: [
                                                Text(
                                                    '${(transfer.route.distance / 1000).toStringAsFixed(1)} km',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium),
                                                Text(
                                                    '$stops ${english ? (stops == 1 ? 'intermediate stop' : 'intermediate stops') : (stops == 1 ? 'Zwischenziel' : 'Zwischenziele')}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium),
                                              ]),
                                          const SizedBox(height: 8),
                                          Text(transfer.hasNavigation
                                              ? (english
                                                  ? 'Original route with turn instructions.'
                                                  : 'Originalstrecke mit Abbiegehinweisen.')
                                              : (english
                                                  ? 'Track only: no turn instructions or travel time.'
                                                  : 'Track: ohne Abbiegehinweise und Fahrzeit.')),
                                          const SizedBox(height: 16),
                                          for (var i = 0;
                                              i < transfer.plan.length;
                                              i++)
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 14),
                                                child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      RouteImportPointIcon(
                                                          index: i,
                                                          count: transfer
                                                              .plan.length),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                          child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                            Text(
                                                                i == 0
                                                                    ? 'Start'
                                                                    : i ==
                                                                            transfer.plan.length -
                                                                                1
                                                                        ? (english
                                                                            ? 'Destination'
                                                                            : 'Ziel')
                                                                        : (english
                                                                            ? 'Intermediate stop $i'
                                                                            : 'Zwischenziel $i'),
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .labelLarge),
                                                            Text(transfer
                                                                        .plan[i]
                                                                        .displayName
                                                                        ?.trim()
                                                                        .isNotEmpty ==
                                                                    true
                                                                ? transfer
                                                                    .plan[i]
                                                                    .displayName!
                                                                : '${transfer.plan[i].latLng.latitude.toStringAsFixed(5)}, ${transfer.plan[i].latLng.longitude.toStringAsFixed(5)}'),
                                                          ])),
                                                    ])),
                                          const Divider(),
                                          const SizedBox(height: 8),
                                          Text(english
                                              ? 'Using this route replaces the current route and ends active navigation. The imported route stays unchanged until you edit the plan or press Refresh.'
                                              : 'Die Übernahme ersetzt die aktuelle Route und beendet eine laufende Navigation. Die importierte Strecke bleibt erhalten, bis du neu planst oder auf Aktualisieren drückst.'),
                                          if (compact) actions,
                                        ]))),
                            if (!compact) actions,
                          ])),
                ),
              );
            }));
    if (save == null || !context.mounted) return false;
    final chosenName = name.text.trim();
    if (chosenName.isEmpty)
      throw const FormatException('Route name must not be empty');
    final selected = transfer.renamed(chosenName);
    var route = SavedRoute(
        name: chosenName,
        start: selected.plan.first,
        stops: selected.plan.sublist(1, selected.plan.length - 1),
        destination: selected.plan.last,
        snapshot: selected);
    if (save) route = await (store ?? savedRoutesStore).addImported(route);
    if (!context.mounted) return false;
    model.setSavedRoutePlan(route);
    return true;
  } finally {
    name.dispose();
  }
}

class RouteImportPointIcon extends StatelessWidget {
  const RouteImportPointIcon(
      {super.key, required this.index, required this.count});
  final int index;
  final int count;
  @override
  Widget build(BuildContext context) {
    final destination = index == count - 1;
    return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: destination
                ? Colors.white
                : index == 0
                    ? const Color(0xFF0057D9)
                    : AppColors.munichWaysOrange,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 3)
            ]),
        alignment: Alignment.center,
        child: destination
            ? const Icon(Icons.sports_score, color: Colors.black, size: 22)
            : index == 0
                ? null
                : Text('$index',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)));
  }
}

class RouteImportPreview extends StatelessWidget {
  const RouteImportPreview({super.key, required this.transfer});
  final RouteTransfer transfer;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final projection = _Projection(transfer, constraints.biggest);
        return Stack(children: [
          Positioned.fill(
              child: CustomPaint(painter: _Preview(transfer, projection))),
          for (var i = 0; i < transfer.plan.length; i++)
            Positioned(
                left: projection.plan[i].dx - 14,
                top: projection.plan[i].dy - 14,
                child: RouteImportPointIcon(
                    index: i, count: transfer.plan.length)),
        ]);
      });
}

class _Projection {
  _Projection(RouteTransfer transfer, Size size) {
    final points = [
      ...transfer.route.points,
      ...transfer.plan.map((p) => p.latLng)
    ];
    final scale = cos(points.first.latitude * pi / 180);
    final xs = points.map((p) => p.longitude * scale).toList();
    final ys = points.map((p) => -p.latitude).toList();
    final minX = xs.reduce(min), minY = ys.reduce(min);
    final width = max(xs.reduce(max) - minX, 0.00001);
    final height = max(ys.reduce(max) - minY, 0.00001);
    final zoom =
        min(max(0, size.width - 56) / width, max(0, size.height - 56) / height);
    final offsets = [
      for (var i = 0; i < points.length; i++)
        Offset((size.width - width * zoom) / 2 + (xs[i] - minX) * zoom,
            (size.height - height * zoom) / 2 + (ys[i] - minY) * zoom)
    ];
    track = offsets.sublist(0, transfer.route.points.length);
    plan = offsets.sublist(transfer.route.points.length);
  }
  late final List<Offset> track;
  late final List<Offset> plan;
}

class _Preview extends CustomPainter {
  _Preview(this.transfer, this.projection);
  final RouteTransfer transfer;
  final _Projection projection;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addPolygon(projection.track, false);
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF0057D9)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_Preview old) => true;
}
