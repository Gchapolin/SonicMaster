import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The iOS runner's Info.plist carries the two settings the app depends on:
/// the Bluetooth permission text (without it iOS kills the app on the first
/// BLE scan) and a landscape-only iPhone (the compact layout is landscape-only;
/// native builds have no rotate prompt). iPad keeps every orientation.
void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  List<String> orientations(String key) {
    final block = RegExp(
      '<key>${RegExp.escape(key)}</key>\\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist)!.group(1)!;

    return [
      for (final m in RegExp(r'<string>(.*?)</string>').allMatches(block))
        m.group(1)!,
    ];
  }

  test('declares why it needs Bluetooth', () {
    expect(plist, contains('<key>NSBluetoothAlwaysUsageDescription</key>'));
  });

  test('iPhone is landscape-only', () {
    expect(orientations('UISupportedInterfaceOrientations'), [
      'UIInterfaceOrientationLandscapeLeft',
      'UIInterfaceOrientationLandscapeRight',
    ]);
  });

  test('iPad keeps portrait', () {
    expect(
      orientations('UISupportedInterfaceOrientations~ipad'),
      contains('UIInterfaceOrientationPortrait'),
    );
  });

  // The PiP window (audio) and the pedal link (bluetooth-central) keep
  // running while another app is in front.
  test('runs PiP and BLE in the background', () {
    expect(orientations('UIBackgroundModes'), ['audio', 'bluetooth-central']);
  });
}
