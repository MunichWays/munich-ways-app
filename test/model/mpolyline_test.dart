import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/model/street_details.dart';

void main() {
  group('isGesamtnetz', () {
    test('true for netzid 3', () {
      //GIVEN
      StreetDetails details = StreetDetails(netztypId: 3);
      MPolyline polyline = MPolyline(details: details);

      //WHEN/THEN
      expect(polyline.isGesamtnetz, true);
    });

    test('true for netzid 4', () {
      //GIVEN
      StreetDetails details = StreetDetails(netztypId: 4);
      MPolyline polyline = MPolyline(details: details);

      //WHEN/THEN
      expect(polyline.isGesamtnetz, true);
    });

    test('false for netzid 1', () {
      //GIVEN
      StreetDetails details = StreetDetails(netztypId: 1);
      MPolyline polyline = MPolyline(details: details);

      //WHEN/THEN
      expect(polyline.isGesamtnetz, false);
    });

    test('false for netzid 2', () {
      //GIVEN
      StreetDetails details = StreetDetails(netztypId: 2);
      MPolyline polyline = MPolyline(details: details);

      //WHEN/THEN
      expect(polyline.isGesamtnetz, false);
    });
  });

  group('isRadlvorrangnetz', () {
    test('true for netzid 1', () {
      //GIVEN
      StreetDetails details = StreetDetails(netztypId: 1);
      MPolyline polyline = MPolyline(details: details);

      //WHEN/THEN
      expect(polyline.isRadlVorrangNetz, true);
    });

    test('true for netzid 2', () {
      //GIVEN
      StreetDetails details = StreetDetails(netztypId: 2);
      MPolyline polyline = MPolyline(details: details);

      //WHEN/THEN
      expect(polyline.isRadlVorrangNetz, true);
    });
  });
}
