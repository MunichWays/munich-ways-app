import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';

/// Shared styling for modal bottom sheet cards (rounded white panel).
BoxDecoration bottomSheetDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(15),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withValues(alpha: 0.5),
        spreadRadius: 1,
        blurRadius: 4,
        offset: const Offset(0, 0),
      ),
    ],
  );
}

/// Inset below status bar / notch for sheet layout math.
///
/// For [showModalBottomSheet], default `useSafeArea: false` applies
/// [MediaQuery.removePadding] for the top edge, which zeros **both**
/// [MediaQueryData.padding] and [MediaQueryData.viewPadding] there — so callers
/// must pass `useSafeArea: true` and rely on that for the physical top inset; this
/// helper then typically returns `0` inside the sheet builder and is only non-zero
/// in contexts that still expose real padding (e.g. tests, nested routes).
double bottomSheetTopPadding(BuildContext context) {
  final mq = MediaQuery.of(context);
  return mq.padding.top > 0 ? mq.padding.top : mq.viewPadding.top;
}

/// Bottom inset for **scrollable** sheet content (home indicator, gesture bar).
///
/// Use as padding at the end of the scroll extent so the last row clears the
/// system inset, while the sheet itself can still extend to the physical bottom
/// (modal [useSafeArea]: false + this padding on the scroll view).
///
/// Mirrors [bottomSheetTopPadding]: when a parent strips [MediaQuery.padding]
/// (e.g. some modal routes), [MediaQuery.viewPadding] still carries the real inset.
double bottomSheetBottomScrollPadding(BuildContext context) {
  final mq = MediaQuery.of(context);
  return mq.padding.bottom > 0 ? mq.padding.bottom : mq.viewPadding.bottom;
}

/// Max height for the **sheet card** (white panel): from below the top inset
/// down to the keyboard (or physical bottom). Does not subtract bottom safe inset.
double bottomSheetMaxHeight(BuildContext context) {
  final mq = MediaQuery.of(context);
  final top = bottomSheetTopPadding(context);
  return mq.size.height - mq.viewInsets.bottom - top;
}

/// White rounded panel: pinned title row + divider; [body] scrolls on its own
/// when taller than remaining space. Sheet height is intrinsic (content-sized)
/// up to [bottomSheetMaxHeight].
class BottomSheetFrame extends StatefulWidget {
  const BottomSheetFrame({
    super.key,
    this.startingElement,
    required this.title,
    required this.body,
  });

  /// Optional control before [title] (e.g. back); [title] stays in [Expanded].
  final Widget? startingElement;

  final Widget title;

  final Widget body;

  @override
  State<BottomSheetFrame> createState() => _BottomSheetFrameState();
}

class _BottomSheetFrameState extends State<BottomSheetFrame> {
  final GlobalKey _headerColumnKey = GlobalKey();

  /// Height of title row + divider; measured after layout.
  double _measuredHeaderPx = 0;

  bool _measureFrameScheduled = false;

  /// Until the first layout measure, assume at least this much space for the
  /// header block so `bodyMax` stays ≤ `maxSheet - header` (avoids overflow if
  /// the real header is taller than this, increase sparingly).
  static const double _kHeaderFallbackPx = 140;

  @override
  void initState() {
    super.initState();
    _ensureHeaderMeasureScheduled();
  }

  @override
  void didUpdateWidget(covariant BottomSheetFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.startingElement != widget.startingElement) {
      // Old height can be too small (e.g. back button added) → bodyMax too
      // large → Column overflows until we remeasure.
      _measuredHeaderPx = 0;
      _ensureHeaderMeasureScheduled();
    }
  }

  void _ensureHeaderMeasureScheduled() {
    if (_measureFrameScheduled) return;
    _measureFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureFrameScheduled = false;
      if (!mounted) return;
      final box =
          _headerColumnKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final h = box.size.height;
      if ((h - _measuredHeaderPx).abs() > 0.5) {
        setState(() => _measuredHeaderPx = h);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensureHeaderMeasureScheduled();

    final computedMaxSheet = bottomSheetMaxHeight(context);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(top: bottomSheetTopPadding(context)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final parentMax = constraints.maxHeight;
            final maxSheet = parentMax.isFinite
                ? math.min(computedMaxSheet, parentMax)
                : computedMaxSheet;
            final headerBudget =
                _measuredHeaderPx > 0 ? _measuredHeaderPx : _kHeaderFallbackPx;
            final bodyMax = math.max(0.0, maxSheet - headerBudget);

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheet),
              child: Container(
                decoration: bottomSheetDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KeyedSubtree(
                      key: _headerColumnKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Row(
                              children: [
                                if (widget.startingElement != null)
                                  widget.startingElement!,
                                Expanded(
                                  child: widget.title,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: context.l10n.close,
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: bodyMax),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.only(
                          bottom: bottomSheetBottomScrollPadding(context),
                        ),
                        child: widget.body,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class BottomSheetTitle extends StatelessWidget {
  const BottomSheetTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w600));
  }
}
