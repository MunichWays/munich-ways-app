import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/info/app_tip.dart';
import 'package:munich_ways/ui/info/info_sheet_tips_content.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';

/// Shared, full-height presentation for first-run and permanent tips.
/// The caller owns the selection; scrolling and swiping only change presentation.
class TipViewer extends StatefulWidget {
  const TipViewer(
      {super.key,
      required this.tips,
      required this.index,
      required this.onChanged,
      required this.onBack,
      required this.onClose,
      this.footer});

  final List<AppTip> tips;
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final Widget? footer;

  @override
  State<TipViewer> createState() => _TipViewerState();
}

class _TipViewerState extends State<TipViewer> {
  double _distance = 0;

  void _step(int delta) {
    final index = widget.index + delta;
    if (index >= 0 && index < widget.tips.length) widget.onChanged(index);
  }

  void _finishSwipe(DragEndDetails details) {
    final distance = _distance;
    _distance = 0;
    if (distance.abs() >= 48 ||
        (distance.abs() >= 16 && (details.primaryVelocity ?? 0).abs() >= 300)) {
      _step(distance < 0 ? 1 : -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final english = context.l10n.isEnglish;
    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
        key: const ValueKey('tip-viewer-frame'),
        height: constraints.hasBoundedHeight
            ? constraints.maxHeight
            : bottomSheetMaxHeight(context),
        width: double.infinity,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const BottomSheetDragHandle(),
            Row(children: [
              IconButton(
                  tooltip: context.l10n.tr('Zurück'),
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back)),
              IconButton(
                  key: const ValueKey('previous-tip'),
                  tooltip: english ? 'Previous tip' : 'Vorheriger Tipp',
                  onPressed: widget.index > 0 ? () => _step(-1) : null,
                  icon: const Icon(Icons.chevron_left)),
              Expanded(
                  child: Semantics(
                      header: true,
                      liveRegion: true,
                      label: english
                          ? 'Tip ${widget.index + 1} of ${widget.tips.length}'
                          : 'Tipp ${widget.index + 1} von ${widget.tips.length}',
                      excludeSemantics: true,
                      child: Text('${widget.index + 1} / ${widget.tips.length}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium))),
              IconButton(
                  key: const ValueKey('next-tip'),
                  tooltip: english ? 'Next tip' : 'Nächster Tipp',
                  onPressed: widget.index < widget.tips.length - 1
                      ? () => _step(1)
                      : null,
                  icon: const Icon(Icons.chevron_right)),
              IconButton(
                  tooltip: context.l10n.close,
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close)),
            ]),
            const Divider(height: 1),
            Expanded(
                child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => _distance = 0,
              onHorizontalDragUpdate: (details) =>
                  _distance += details.delta.dx,
              onHorizontalDragEnd: _finishSwipe,
              onHorizontalDragCancel: () => _distance = 0,
              child: SingleChildScrollView(
                key: ValueKey(widget.tips[widget.index]),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: InfoSheetTipContent(tip: widget.tips[widget.index]),
              ),
            )),
            if (widget.footer != null) widget.footer!,
            SizedBox(height: bottomSheetBottomScrollPadding(context)),
          ]),
        ),
      );
    });
  }
}
