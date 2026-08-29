import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

const localTestBuild = String.fromEnvironment('LOCAL_TEST_BUILD');

Future<String> loadAppVersionLabel() async {
  final info = await PackageInfo.fromPlatform();
  return formatAppVersionLabel(
    version: info.version,
    buildNumber: info.buildNumber,
    platform: Platform.isIOS ? 'iOS' : 'Android',
    testBuild: localTestBuild,
  );
}

String formatAppVersionLabel({
  required String version,
  required String buildNumber,
  required String platform,
  String testBuild = '',
}) {
  final testBuildLabel = testBuild.isEmpty ? '' : ' · Testbuild $testBuild';
  return 'Version $version+$buildNumber · $platform$testBuildLabel';
}
