import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/munichways/munichways_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the bundled Munich RadlVorrang network', () async {
    final polylines = await MunichwaysApi().getBundledRadlVorrangnetz();

    expect(polylines, isNotEmpty);
    expect(polylines.every((polyline) => polyline.isRadlVorrangNetz), isTrue);
    expect(
      polylines.every((polyline) => polyline.details?.farbe != null),
      isTrue,
    );
  });
}
