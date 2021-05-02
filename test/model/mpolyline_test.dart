import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/model/street_details.dart';

void main() {
  group('isGesamtnetz', () {
    test('true for isMunichWaysRadlVorrangNetz false', () {
      //GIVEN
      StreetDetails details = StreetDetails(isMunichWaysRadlVorrangNetz: false);
      MPolyline polyline = MPolyline(details: details);

      //WHEN/THEN
      expect(polyline.isGesamtnetz, true);
    });

    test('false for isMunichWaysRadlVorrangNetz true', () {
      //GIVEN
      StreetDetails details = StreetDetails(isMunichWaysRadlVorrangNetz: true);
      MPolyline polyline = MPolyline(details: details);

      //WHEN/THEN
      expect(polyline.isGesamtnetz, false);
    });
  });

  group('isRadlvorrangnetz', () {
    test('true for isMunichWaysRadlVorrangNetz true', () {
      //GIVEN
      StreetDetails details = StreetDetails(isMunichWaysRadlVorrangNetz: true);
      MPolyline polyline = MPolyline(details: details);

      //WHEN/THEN
      expect(polyline.isRadlVorrangNetz, true);
    });

    test('false for isMunichWaysRadlVorrangNetz false', () {
      //GIVEN
      StreetDetails details = StreetDetails(isMunichWaysRadlVorrangNetz: false);
      MPolyline polyline = MPolyline(details: details);

      //WHEN/THEN
      expect(polyline.isRadlVorrangNetz, false);
    });
  });
}
