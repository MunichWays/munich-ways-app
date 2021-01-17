import 'package:html/parser.dart';

class ImgIdParser {
  String parse(String mapillaryLink, String strassenansicht) {
    if (!_validMapillaryLink(mapillaryLink) && strassenansicht != null) {
      var document = parseFragment(strassenansicht);
      var aTag = document.querySelector('a');
      if (aTag != null) {
        mapillaryLink = aTag.attributes['href'];
      }
    }

    if (!_validMapillaryLink(mapillaryLink)) {
      return null;
    }

    return mapillaryLink.split('/').last;
  }

  bool _validMapillaryLink(String link) {
    return link != null && link.startsWith("https://www.mapillary.com/map/im/");
  }
}
