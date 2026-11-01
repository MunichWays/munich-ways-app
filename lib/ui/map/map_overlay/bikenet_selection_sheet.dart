import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/map_background.dart';
import 'package:munich_ways/ui/map/aerial_map_style.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';

Future<void> showMapLayersSheet(
    BuildContext context, MapScreenViewModel model) async {
  if (!model.canChangeMapBackground) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BikenetSelectionSheet(model: model),
  );
}

class BikenetSelectionSheet extends StatefulWidget {
  const BikenetSelectionSheet({super.key, required this.model});
  final MapScreenViewModel model;

  @override
  State<BikenetSelectionSheet> createState() => _BikenetSelectionSheetState();
}

class _BikenetSelectionSheetState extends State<BikenetSelectionSheet> {
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_onModelChanged);
  }

  @override
  void dispose() {
    widget.model.removeListener(_onModelChanged);
    super.dispose();
  }

  void _onModelChanged() {
    if (!mounted) return;
    if (!widget.model.canChangeMapBackground && !_closing) {
      _closing = true;
      final route = ModalRoute.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || route == null || !route.isActive) return;
        // Never pop a newer dialog which happens to cover this sheet.
        if (route.isCurrent) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).removeRoute(route);
        }
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final english = context.l10n.isEnglish;
    final model = widget.model;
    return BottomSheetFrame(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BottomSheetTitle(title: english ? 'Maps' : 'Karten'),
          const SizedBox(height: 6),
          // Keep the thumbnail's source visible even when the body scrolls.
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child:
                Text(bavariaAerialAttribution, style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final background in MapBackground.values) ...[
                    if (background != MapBackground.values.first)
                      const SizedBox(width: 12),
                    Expanded(
                        child: _MapBackgroundCard(
                      background: background,
                      selected: model.mapBackground == background,
                      onTap: model.canChangeMapBackground
                          ? () => model.setMapBackground(background)
                          : null,
                    )),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(english
                  ? 'Aerial imagery is available in Bavaria. Choose the map before starting navigation.'
                  : 'Luftbilder sind für Bayern verfügbar. Wähle die Karte vor dem Navigationsstart.'),
            ),
            const Divider(),
            Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile.adaptive(
                    title: Text(context.l10n.tr('Radl-Vorrang-Netz')),
                    value: model.isRadlvorrangnetzVisible,
                    onChanged: (_) => model.toggleRadvorrangnetzVisible(),
                  ),
                  SwitchListTile.adaptive(
                    title: Text(context.l10n.tr('Weitere Strecken')),
                    value: model.isGesamtnetzVisible,
                    onChanged: (_) => model.toggleGesamtnetzVisible(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBackgroundCard extends StatelessWidget {
  const _MapBackgroundCard(
      {required this.background, required this.selected, required this.onTap});
  final MapBackground background;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final aerial = background == MapBackground.aerial;
    final label = aerial
        ? (context.l10n.isEnglish ? 'Aerial Bavaria' : 'Luftbild Bayern')
        : 'Standard';
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: selected ? colors.primary : colors.outline,
              width: selected ? 3 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 104,
                width: double.infinity,
                child: aerial
                    ? Image.asset('images/map_preview_aerial.jpg',
                        fit: BoxFit.cover)
                    : const CustomPaint(painter: _StandardMapPreview()),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                        size: 20,
                        color: selected ? colors.primary : colors.onSurface),
                    const SizedBox(width: 6),
                    Expanded(child: Text(label)),
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

/// Local schematic preview: no extra renderer or map downloads in the menu.
class _StandardMapPreview extends CustomPainter {
  const _StandardMapPreview();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xffefefef));
    canvas.drawRect(
        Rect.fromLTWH(size.width * .6, 0, size.width * .4, size.height * .6),
        Paint()..color = const Color(0xffd8e8c8));
    final river = Path()
      ..moveTo(size.width * .3, 0)
      ..cubicTo(size.width * .7, size.height * .3, size.width * .2,
          size.height * .7, size.width * .4, size.height);
    canvas.drawPath(
        river,
        Paint()
          ..color = const Color(0xff9dc8df)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10);
    for (final y in [.25, .65]) {
      canvas.drawLine(
          Offset(0, size.height * y),
          Offset(size.width, size.height * (y + .1)),
          Paint()
            ..color = const Color(0xffd0b888)
            ..strokeWidth = 9);
      canvas.drawLine(
          Offset(0, size.height * y),
          Offset(size.width, size.height * (y + .1)),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 6);
    }
    canvas.drawLine(
        Offset(size.width * .7, 0),
        Offset(size.width * .5, size.height),
        Paint()
          ..color = const Color(0xff4f98a5)
          ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_StandardMapPreview oldDelegate) => false;
}
