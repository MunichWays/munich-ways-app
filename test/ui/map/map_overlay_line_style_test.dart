import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/ui/map/map_overlay_line_style.dart';

void main() {
  test('uses a wider route line only on iOS', () {
    expect(
      MapOverlayLineStyle.routeLineWidthForPlatform(TargetPlatform.iOS),
      MapOverlayLineStyle.iosRouteLineWidthByZoom,
    );
    for (final platform in const [
      TargetPlatform.android,
      TargetPlatform.fuchsia,
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      expect(
        MapOverlayLineStyle.routeLineWidthForPlatform(platform),
        MapOverlayLineStyle.routeLineWidthByZoom,
      );
    }
  });

  test('adds two logical pixels to every iOS route-width zoom stop', () {
    final standard = MapOverlayLineStyle.routeLineWidthByZoom;
    final ios = MapOverlayLineStyle.iosRouteLineWidthByZoom;

    expect(ios.length, standard.length);
    expect(ios.take(3), standard.take(3));
    for (var index = 3; index < standard.length; index += 2) {
      expect(ios[index], standard[index]);
      expect(
        ios[index + 1] as double,
        (standard[index + 1] as double) + 2,
      );
    }
  });
}
