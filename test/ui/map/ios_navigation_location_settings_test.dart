import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:munich_ways/ui/map/ios_navigation_location_settings.dart';

void main() {
  test('background tracking follows navigation start, stop and restart', () {
    for (final active in [false, true, false, true]) {
      final settings = iosNavigationLocationSettings(navigationActive: active);
      expect(settings.allowBackgroundLocationUpdates, active);
      expect(settings.showBackgroundLocationIndicator, active);
      expect(settings.pauseLocationUpdatesAutomatically, isFalse);
      expect(settings.activityType, ActivityType.otherNavigation);
      expect(settings.accuracy, LocationAccuracy.bestForNavigation);
      expect(settings.distanceFilter, 0);
    }
  });
}
