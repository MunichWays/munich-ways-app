import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/ui/map/big_junction_guidance.dart';
import 'junction_sequences_test.dart' show parse;

const straight = 'maximilian-ring-north-south-straight-entry-1-exit-3';
const nearLeft = 'maximilian-ring-west-north-left-entry-4-exit-6';
const standardLeft = 'maximilian-ring-west-north-left-entry-4-exit-1';
const standardStraight = 'maximilian-ring-south-north-straight-entry-3-exit-1';
Map<String, dynamic> contract(String name) => jsonDecode(
    File('test/fixtures/k24-instructions/$name.json').readAsStringSync());

void main() {
  for (final name in [straight, nearLeft]) {
    test('$name uses backend text twice, without checkpoints or spoken metres',
        () {
      final data = contract(name), route = parse(data);
      final j = route.bigJunctions.single;
      expect(j.instruction, isNotNull);
      expect(j.sequence, isNull);
      final state = BigJunctionGuidance()..reset([j]);
      for (final english in [false, true]) {
        state.reset([j]);
        final expected = j.instruction!.advance[english ? 'en' : 'de'];
        expect(state.announce(j, 119, english: english), expected);
        expect(state.announce(j, 60, english: english), isNull);
        expect(state.announce(j, 39, english: english), expected);
        expect(state.announce(j, 25, english: english), isNull);
        expect(j.displayAction(english),
            j.instruction!.display[english ? 'en' : 'de']);
      }
      if (name == nearLeft) expect(j.action(false), contains('vorne links'));
      if (name == straight) expect(j.action(false), contains('gegen\u00fcber'));
    });
  }
  test(
      'right-hand Exit-1 remains standard left/straight despite two-way cycleway',
      () {
    final left = parse(contract(standardLeft)).bigJunctions.single;
    final straight = parse(contract(standardStraight)).bigJunctions.single;
    expect(left.instruction, isNull);
    expect(straight.instruction, isNull);
    expect(left.action(false), 'an der gro\u00dfen Kreuzung links abbiegen');
    expect(
        straight.action(false), 'an der gro\u00dfen Kreuzung geradeaus fahren');
  });
  test('malformed or mismatched template falls back to usable ordinary route',
      () {
    for (final variant in ['unknown', 'mismatch', 'translation', 'protocol']) {
      final data = contract(nearLeft);
      final g = data['routes'][0]['guidance'];
      final i = g['junctions'][0]['instruction'];
      if (variant == 'unknown') i['templateId'] = 'unknown';
      if (variant == 'mismatch') i['templateId'] = 'two-way-straight-opposite';
      if (variant == 'translation') i['advance'].remove('en');
      if (variant == 'protocol') g['version'] = 'big-junctions-v2';
      final route = parse(data);
      expect(route.points, isNotEmpty);
      expect(route.bigJunctions, isEmpty, reason: variant);
    }
  });
}
