import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/ui/info/app_version_label.dart';

void main() {
  test('formats a release version without a local test build', () {
    expect(
      formatAppVersionLabel(
        version: '3.1.21',
        buildNumber: '61',
        platform: 'Android',
      ),
      'Version 3.1.21+61 · Android',
    );
  });

  test('adds the local test build when supplied at build time', () {
    expect(
      formatAppVersionLabel(
        version: '3.1.21',
        buildNumber: '61',
        platform: 'Android',
        testBuild: '3',
      ),
      'Version 3.1.21+61 · Android · Testbuild 3',
    );
  });
}
