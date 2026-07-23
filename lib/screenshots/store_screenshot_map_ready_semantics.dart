import 'package:flutter/material.dart';
import 'package:munich_ways/screenshots/store_screenshot_config.dart';

/// [Semantics] markers for store-screenshot integration tests.
class StoreScreenshotMapReadySemantics extends StatelessWidget {
  const StoreScreenshotMapReadySemantics({
    super.key,
    required this.storeIdleReady,
    required this.storeRouteReady,
  });

  final bool storeIdleReady;
  final bool storeRouteReady;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.05,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (storeIdleReady)
                Semantics(
                  container: true,
                  label: StoreScreenshotSemantics.mapIdleReady,
                  child: const SizedBox(
                    width: 2,
                    height: 2,
                  ),
                ),
              if (storeRouteReady)
                Semantics(
                  container: true,
                  label: StoreScreenshotSemantics.routeReady,
                  child: const SizedBox(
                    width: 2,
                    height: 2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
