import 'package:maplibre_gl/maplibre_gl.dart';

class ExamplePlacesMapStyle {
  const ExamplePlacesMapStyle({required this.dark});

  final bool dark;

  // Text in an icon layer makes native layout depend on remote glyphs, even
  // with text-optional enabled. Keep the local marker in its own layer.
  SymbolLayerProperties markers(String imageId) => SymbolLayerProperties(
        iconImage: imageId,
        iconSize: .9,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      );

  SymbolLayerProperties get labels => SymbolLayerProperties(
        textField: const ['get', 'name'],
        // Use the same available font stack as the bundled Liberty basemap.
        textFont: const ['Roboto Regular'],
        textSize: 12,
        textOffset: const [0, 1.5],
        textAnchor: 'top',
        textIgnorePlacement: true,
        textColor: dark ? '#ffffff' : '#142e40',
        textHaloColor: dark ? '#142e40' : '#ffffff',
        textHaloWidth: 2,
      );
}
