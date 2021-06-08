import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/street_details.dart';

/// Map framework independent polyline data class
class MPolyline {
  List<LatLng> points;
  StreetDetails details;

  /// true if gesamtnetz, false if RadlVorrang Munichways
  bool get isGesamtnetz {
    return !isRadlVorrangNetz;
  }

  bool get isRadlVorrangNetz {
    return details.isMunichWaysRadlVorrangNetz;
  }

  MPolyline({this.points, this.details});
}
