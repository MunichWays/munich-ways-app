import 'package:flutter/material.dart';
import 'package:munich_ways/screenshots/store_screenshot_config.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';

/// Invisible tap targets for [integration_test/screenshots_test.dart].
///
/// No visible chrome — screenshots match normal app UI. Semantics labels are
/// kept so `find.bySemanticsLabel` + `tap` still work.
///
/// Only compiled into builds that pass `--dart-define=STORE_SCREENSHOTS=true`.
class StoreScreenshotControls extends StatelessWidget {
  const StoreScreenshotControls({super.key, required this.model});

  final MapScreenViewModel model;

  static const double _hitHeight = 44;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 8,
      right: 8,
      bottom: 100,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: StoreScreenshotSemantics.triggerRoute,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  model.setDestination(storeScreenshotRouteDestination());
                },
                child: const SizedBox(height: _hitHeight),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              label: StoreScreenshotSemantics.triggerStreet,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  model.clearDestination();
                  model.onTap(storeScreenshotStreetDetails());
                },
                child: const SizedBox(height: _hitHeight),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
