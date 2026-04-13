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

/// Max height for sheet body scroll areas so the sheet can stay short when
/// content is small, but never exceed ~92% of the screen.
double mapOverlayMaxScrollBodyHeight(
  BuildContext context, {
  double chromeAboveBody = 96,
}) {
  final h = MediaQuery.sizeOf(context).height;
  return (h * 0.92 - chromeAboveBody).clamp(160, h * 0.88);
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
      child: Container(
        decoration: mapOverlayBottomSheetDecoration(),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: mapOverlayMaxScrollBodyHeight(context),
                ),
                child: ListView(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  children: [body],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
