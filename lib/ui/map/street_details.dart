import 'package:munich_ways/common/logger_setup.dart';

class StreetDetails{

  final dynamic feature;

  StreetDetails(this.feature);

  @override
  String toString() {
    return 'StreetDetails{feature: $feature}';
  }

  String getName() {

    log.d("getNAme" + feature.toString());
    return "";

  }
}