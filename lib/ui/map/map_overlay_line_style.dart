import 'package:maplibre_gl/maplibre_gl.dart';

/// MapLibre zoom expressions for route / Radl-Netz GeoJSON line paint.
abstract final class MapOverlayLineStyle {
  static const List<Object?> routeLineWidthByZoom = [
    Expressions.interpolate,
    ['linear'],
    [Expressions.zoom],
    11,
    6.0,
    14,
    8.5,
    17,
    10.0,
  ];

  static const List<Object?> radlLineWidthByZoom = [
    Expressions.interpolate,
    ['linear'],
    [Expressions.zoom],
    11,
    1.2,
    14,
    2.5,
    17,
    3.5,
  ];

  /// Light separation from the detailed basemap so every rating color remains
  /// readable over roads, land use and buildings.
  static const List<Object?> networkCasingLineWidthByZoom = [
    Expressions.interpolate,
    ['linear'],
    [Expressions.zoom],
    11,
    3.2,
    14,
    4.5,
    17,
    5.5,
  ];

  static const List<Object?> radlLineOpacityByZoom = [
    Expressions.interpolate,
    ['linear'],
    [Expressions.zoom],
    10,
    0.55,
    13,
    1.0,
  ];

  /// Gesamtnetz ("Weitere Strecken") line width: same stops as [radlLineWidthByZoom],
  /// kept as a separate constant so Radl- and Gesamt-Netz can diverge later.
  static const List<Object?> gesamtNetzLineWidthByZoom = [
    Expressions.interpolate,
    ['linear'],
    [Expressions.zoom],
    11,
    1.2,
    14,
    2.5,
    17,
    3.5,
  ];

  /// Gesamtnetz: same opacity ramp as [radlLineOpacityByZoom]; separate list so it
  /// can diverge later.
  static const List<Object?> gesamtNetzLineOpacityByZoom = [
    Expressions.interpolate,
    ['linear'],
    [Expressions.zoom],
    10,
    0.55,
    13,
    1.0,
  ];

  static const List<Object?> networkHitLineWidthByZoom = [
    Expressions.interpolate,
    ['linear'],
    [Expressions.zoom],
    11,
    10.0,
    14,
    16.0,
    17,
    22.0,
  ];
}
