import 'package:flutter/material.dart';

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

/// White rounded panel with title row, divider, and scrollable [body].
class BottomSheetFrame extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(top: bottomSheetTopPadding(context)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: bottomSheetMaxHeight(context),
          ),
          child: Container(
            decoration: bottomSheetDecoration(),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(
                bottom: bottomSheetBottomScrollPadding(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        if (startingElement != null) startingElement!,
                        Expanded(
                          child: title,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Schließen',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  body,
                ],
              ),
            ),
          ),
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
