import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:munich_ways/api/route_transfer_io.dart';

void main() {
  test('only own HTTPS route links can fetch snapshots', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.radlnavi.munichways.de');
      expect(request.followRedirects, false);
      return Response(
          File('test_resources/routing/route-transfer.json').readAsStringSync(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final valid = Uri.parse('https://radlnavi.munichways.de/r/${'a' * 32}');
    expect(
        (await RouteTransferIo.loadLink(valid, client: client)).plan.length, 4);
    expect(
        () => RouteTransferIo.loadLink(
            Uri.parse('https://evil.invalid/r/${'a' * 32}'),
            client: client),
        throwsFormatException);
    final expired = MockClient((_) async => Response('', 410));
    expect(() => RouteTransferIo.loadLink(valid, client: expired),
        throwsFormatException);
    expect(
        (await RouteTransferIo.loadLink(valid, client: client)).hasNavigation,
        true);
  });
}
