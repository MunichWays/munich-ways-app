import 'package:geolocator/geolocator.dart';

AppleSettings iosNavigationLocationSettings({required bool navigationActive}) =>
    AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      activityType: ActivityType.otherNavigation,
      pauseLocationUpdatesAutomatically: false,
      allowBackgroundLocationUpdates: navigationActive,
      showBackgroundLocationIndicator: navigationActive,
    );
