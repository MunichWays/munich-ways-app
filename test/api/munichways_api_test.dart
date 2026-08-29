import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/munichways/munichways_api.dart';
import 'package:munich_ways/model/polyline.dart';

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

  test('does not apply the network timeout to bundled ratings', () async {
    final polylines = await _SlowBundledMunichwaysApi()
        .getRadlvorrangnetzUpdates(
          responseTimeout: const Duration(milliseconds: 1),
        )
        .first;

    expect(polylines, isEmpty);
  });
}

class _SlowBundledMunichwaysApi extends MunichwaysApi {
  @override
  Future<Set<MPolyline>> getBundledRadlVorrangnetz() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return <MPolyline>{};
  }
}
