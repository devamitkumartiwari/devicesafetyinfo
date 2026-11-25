// Patrol tests for app info and the update check.
import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('app info comes from the platform', ($) async {
    await $.pumpWidgetAndSettle(const ExampleApp());
    final info = await DeviceSafety.versionCheck.appInfo();
    expect(info.packageName, isNotEmpty);
    expect(info.version, isNotEmpty);
    expect(
      await DeviceSafety.versionCheck.localVersion(),
      matches(RegExp(r'^\d+\.\d+')),
    );
  });

  patrolTest('status never throws (unpublished app returns null)', ($) async {
    await $.pumpWidgetAndSettle(const ExampleApp());
    final status = await DeviceSafety.versionCheck.status(
      forceAppVersion: '999.0.0',
    );
    expect(status?.urgency, anyOf(isNull, UpdateUrgency.optional));
  });

  patrolTest('the Version check page shows a version result', ($) async {
    await $.pumpWidgetAndSettle(const ExampleApp());
    await $(#menu_version_check).scrollTo().tap();
    await $.pumpAndSettle();
    await $(#version_check).scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 20));
    expect($(#version_result), findsOneWidget);
  });
}
