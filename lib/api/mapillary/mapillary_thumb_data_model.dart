// ----------------------------------------
// Mapillary Data Model for image thumbnail
//
// Autor: Stefan Heilmann
// ----------------------------------------

import 'package:munich_ways/api/mapillary/mapillary_api_v4.dart' as api;

class MapillaryThumbDataModel {
  final String _thumbUrl;
  final String _imageId;

  MapillaryThumbDataModel({required String thumbUrl, required String imageId})
      : _thumbUrl = thumbUrl,
        _imageId = imageId;

  factory MapillaryThumbDataModel.fromJson(Map<String, dynamic> json) {
    return MapillaryThumbDataModel(
        thumbUrl: json[api.mapillaryThumb1024Url], imageId: json[api.mapillaryId]);
  }

  String get thumbUrl => this._thumbUrl;

  String get imageId => this._imageId;
}
