import 'package:latlong/latlong.dart';
import 'package:munich_ways/model/street_details.dart';

/// Map framework independent polyline data class
class MPolyline {
  List<LatLng> points;
  StreetDetails details;

  /// true if gesamtnetz, false if Radlvorrangnetz
  bool get isGesamtnetz {
    return [3, 4].contains(details.netztypId);
  }

  bool get isRadlVorrangNetz {
    return !isGesamtnetz;
  }

  MPolyline({this.points, this.details});
}
