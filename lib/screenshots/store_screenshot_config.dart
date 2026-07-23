import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/bezirk.dart';
import 'package:munich_ways/model/kategorie.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/street_details.dart';

/// Compile-time flag. Only pass `STORE_SCREENSHOTS=true` for integration_test /
/// CI screenshot builds — never for App Store release archives.
const bool kStoreScreenshots =
    bool.fromEnvironment('STORE_SCREENSHOTS', defaultValue: false);

/// Semantics labels for [integration_test/screenshots_test.dart] and in-app
/// controls (only present when [kStoreScreenshots] is true).
abstract class StoreScreenshotSemantics {
  static const mapIdleReady = 'screenshot_map_idle_ready';
  static const routeReady = 'screenshot_route_ready';
  static const streetSheetReady = 'screenshot_street_sheet_ready';
  static const triggerRoute = 'store_screenshot_trigger_route';
  static const triggerStreet = 'store_screenshot_trigger_street';
}

/// Fixed destination for a short inner-city route (simulator location ≈ Stachus).
Place storeScreenshotRouteDestination() {
  return Place(
    'Ziel',
    const LatLng(48.137154, 11.575493),
  );
}

/// Stable street section for the third App Store screenshot (no live map tap).
///
/// [integration_test/screenshots_test.dart] waits until the sheet shows
/// [StreetDetails.name] (preferred) or [StreetDetails.munichwaysId] as plain text.
StreetDetails storeScreenshotStreetDetails() {
  return StreetDetails(
    name: 'Wörnbrunner-Volkmar-Gabert-Weg (Unterführung A995)',
    description: 'Geheimtipp',
    ist: 'Herrlicher Weg kreuzungsfrei unter der A995 und der Münchner Straße',
    soll: '–',
    happyBikeLevel: 'gemütlich',
    farbe: 'grün',
    munichwaysId: 'LK-M.Perlacher Forst.1144',
    statusUmsetzung: 'bereits OK',
    kategorie: Kategorie.fromString(
      '<a href="https://www.munichways.de/">alle Infrastruktur-Elemente</a>',
    ),
    bezirk: Bezirk.fromProps(
      name: 'Sendling',
      nummer: '6',
      region: 'Mitte',
      link:
          '<a href="https://www.munichways.de/bezirksausschuesse/">Bezirk</a>',
    ),
    links: const [],
    // Same image as https://www.mapillary.com/app/?pKey=292005316001625
    mapillaryImgId: '292005316001625',
    isMunichWaysRadlVorrangNetz: true,
  );
}
