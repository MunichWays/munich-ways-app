import 'package:html/parser.dart';

class ImgIdParser {
  String? parse(
      String? mapillaryImgId, String? mapillaryLink, String? strassenansicht) {
    if (mapillaryImgId != null) {
      return mapillaryImgId;
    }

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

    return mapillaryLink!.split('=').last;
  }

  bool _validMapillaryLink(String? link) {
    return link != null && link.startsWith("https://www.mapillary.com/app/?pKey=");
  }
}
