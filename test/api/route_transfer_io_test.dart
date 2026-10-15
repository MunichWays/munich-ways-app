import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:munich_ways/api/route_transfer_io.dart';

void main() {
  test(
      'pasted and scanned text must be one bounded own-domain HTTPS sharing link',
      () {
    final link = 'https://radlnavi.munichways.de/r/${'a' * 32}';
    expect(RouteTransferIo.parseLink('  $link  '), Uri.parse(link));
    for (final value in [
      '',
      'not a link',
      'x' * 2049,
      link.replaceFirst('https:', 'http:'),
      '$link?redirect=elsewhere',
      '$link#fragment',
      link.replaceFirst('radlnavi.', 'evil.radlnavi.'),
      link.replaceFirst('radlnavi.', 'user@radlnavi.'),
      link.replaceFirst('.de/', '.de:8080/'),
      'https://radlnavi.munichways.de/r/short'
    ]) {
      expect(RouteTransferIo.parseLink(value), isNull, reason: value);
    }
  });
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
