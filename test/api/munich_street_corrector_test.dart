import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/munich_street_corrector.dart';

void main() {
  final corrector = MunichStreetCorrector.fromStreetNames([
    'Blumenstr.',
    'Bunsenstr.',
    'Marienpl.',
    'Rosenheimer Str.',
  ]);

  test('corrects a missing letter to the uniquely closest Munich street',
      () async {
    final correction = await corrector.correct('bumenstr münchen');

    expect(correction?.query, 'Blumenstr., München');
    expect(correction?.displayName, 'Blumenstraße');
  });

  test('corrects a transposed letter and keeps a house number', () async {
    final correction = await corrector.correct('marienpatz 8');

    expect(correction?.query, 'Marienpl., 8, München');
    expect(correction?.displayName, 'Marienplatz');
  });

  test('does not guess unrelated input', () async {
    expect(await corrector.correct('hjkhkhjk'), isNull);
  });

  test('keeps an exact street query unchanged', () async {
    final correction = await corrector.correct('Rosenheimer Straße');

    expect(correction?.query, 'Rosenheimer Straße');
  });
}
