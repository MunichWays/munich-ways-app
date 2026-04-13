import 'package:flutter/material.dart';

/// Shared styling for map modal bottom sheets.
BoxDecoration mapOverlayBottomSheetDecoration() {
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
double mapOverlaySheetTopPadding(BuildContext context) {
  final mq = MediaQuery.of(context);
  return mq.padding.top > 0 ? mq.padding.top : mq.viewPadding.top;
}

/// Max height for the **sheet card** (white panel): from below the top inset
/// down to the keyboard (or physical bottom). Does not subtract bottom safe inset.
double mapOverlaySheetMaxHeight(BuildContext context) {
  final mq = MediaQuery.of(context);
  final top = mapOverlaySheetTopPadding(context);
  return mq.size.height - mq.viewInsets.bottom - top;
}

/// White rounded panel used by map modal sheets (layers, settings, info).
class MapBottomSheetFrame extends StatelessWidget {
  const MapBottomSheetFrame({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(top: mapOverlaySheetTopPadding(context)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: mapOverlaySheetMaxHeight(context),
          ),
          child: Container(
            decoration: mapOverlayBottomSheetDecoration(),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Schließen',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
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
