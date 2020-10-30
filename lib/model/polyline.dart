import 'package:latlong/latlong.dart';
import 'package:munich_ways/model/street_details.dart';

/// Map framework independent polyline data class
class MPolyline {
  List<LatLng> points;
  StreetDetails details;
  bool isGesamtnetz;

  MPolyline({this.points, this.details, this.isGesamtnetz = false});
}
