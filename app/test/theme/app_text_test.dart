import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/theme/app_text.dart';

void main() {
  test('the prototype fonts are declared', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final family in [
      'Inter',
      'Space Grotesk',
      'JetBrains Mono',
      'Barlow Condensed',
      'Share Tech Mono',
    ]) {
      expect(pubspec, contains('family: $family'));
    }
  });

  test('the prototype text styles use the prototype families', () {
    expect(AppText.ui.fontFamily, 'Inter');
    expect(AppText.ui.fontSize, 13);
    expect(AppText.uiStrong.fontWeight, FontWeight.w600);
    expect(AppText.title.fontFamily, 'Space Grotesk');
    expect(AppText.section.letterSpacing, 1);
    expect(AppText.mono.fontFamily, 'JetBrains Mono');
    expect(AppText.gearLabel.fontFamily, 'Barlow Condensed');
    expect(AppText.meter.fontFamily, 'Share Tech Mono');
  });
}
