// ----------------------------------------
// Mapillary API V4
//
// Autor: Stefan Heilmann
// ----------------------------------------

// Mapillary endpoint for metadata
const String mapillaryEndpoint = 'https://graph.mapillary.com/';

//
const String mapillaryApp = 'https://www.mapillary.com/app/?pKey=';

const String mapillaryErrorId = '211265577336913';

// MunichWays customer Id
const String mapillaryAccessToken =
    'MLY|6504546039605278|d6cd752b757343ec344d59a87a363d88';

// image id
const String mapillaryId = 'id';

const String mapillaryHttpAccessToken = '?access_token=';

const String mapillaryHttpFieldsParameter = '&fields=';

// Image fields

// float, original altitude from camera Exif calculated from sea level.
const String mapillaryAltitude = 'altitude';

// float, scale of the SfM reconstruction around the image.
const String mapillaryAtomicScale = 'atomic_scale';

// array of float, focal length, k1, k2.
const String mapillaryCameraParameters = 'camera_parameters';

// enum, type of camera projection: "perspective", "fisheye", "equirectangular" (or equivalently "spherical")
const String mapillaryCameraType = 'camera_type';

// timestamp, capture time.
const String mapillaryCapturedAt = 'captured_at';

// float, original compass angle of the image.
const String mapillaryCompassAngle = 'compass_angle';

// float, altitude after running image processing, from sea level.
const String mapillaryComputedAltitude = 'computed_altitude';

// float, compass angle after running image processing.
const String mapillaryComputedCompassAngle = 'computed_compass_angle';

// GeoJSON Point, location after running image processing.
const String mapillaryComputedGeometry = 'computed_geometry';

// enum, corrected orientation of the image.
const String mapillaryComputedRotation = 'computed_rotation';

// enum, orientation of the camera as given by the Exif tag.
const String mapillaryExifOrientation = 'exif_orientation';

// GeoJSON Point geometry.
const String mapillaryGeometry = 'geometry';

// int, height of the original image uploaded.
const String mapillaryHeight = 'height';

//  string, URL to the 256px wide thumbnail.
const String mapillaryThumb256Url = 'thumb_256_url';

// string, URL to the 1024px wide thumbnail.
const String mapillaryThumb1024Url = 'thumb_1024_url';

// string, URL to the 2048px wide thumbnail.
const String mapillaryThumb2048Url = 'thumb_2048_url';

// string, URL to the original wide thumbnail.
const String mapillaryThumbOriginalUrl = 'thumb_original_url';

// int, ID of the connected component of images that were aligned together.
const String mapillaryMergeCc = 'merge_cc';

// { id: string, url: string } - URL to the mesh.
const String mapillaryMesh = 'mesh';

// string, ID of the sequence, which is a group of images captured in succession.
const String mapillarySequence = 'sequence';

// { id: string, url: string } - URL to the point cloud data in JSON and compressed by zlib. See the example below.
const String mapillarySfmCluster = 'sfm_cluster';

// int, width of the original image uploaded.
const String mapillaryWidth = 'width';

// detection entity, detections from the image
const String mapillaryDetections = 'detections';
