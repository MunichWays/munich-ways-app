// ----------------------------------------
// Mapillary Service functions
//
// Autor: Stefan Heilmann
// ----------------------------------------

import 'dart:core';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:munich_ways/common/json_body_extension.dart';

import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/api/mapillary/mapillary_api_v4.dart' as api;
import 'package:munich_ways/api/mapillary/mapillary_thumb_data_model.dart';

// ----------------------------------------
// Get single POST data from Mapillary endpoint for image meta data.
// ----------------------------------------
Future<MapillaryThumbDataModel> getSinglePostData(String imageId) async {
  MapillaryThumbDataModel result;

  var buffer = new StringBuffer();
  buffer.write(api.mapillaryEndpoint);
  buffer.write(imageId);
  buffer.write(api.mapillaryHttpAccessToken);
  buffer.write(api.mapillaryAccessToken);
  buffer.write(api.mapillaryHttpFieldsParameter + api.mapillaryThumb1024Url);

  String encodedUrl = Uri.encodeFull(buffer.toString());

  try {
    final response = await http.get(
      Uri.parse(encodedUrl),
      headers: {
        HttpHeaders.contentTypeHeader: "application/json",
      },
    );

    if (response.statusCode == 200) {
      final item = response.jsonBody();
      result = MapillaryThumbDataModel.fromJson(item);
    } else {
      log.e("Error POST");
      return MapillaryThumbDataModel(thumbUrl: '', imageId: '');
    }
  } catch (e) {
    log.e(e.toString());
    return MapillaryThumbDataModel(thumbUrl: '', imageId: '');
  }

  return result;
}
