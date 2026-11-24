import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The flat Material look, checked in the source: a redesigned class carries
/// no gradient, shadow, blur or inline color of its own. Every color comes
/// from Palette (lib/theme/app_colors.dart).
///
/// Each redesign task adds its classes here.
const flatClasses = <String, List<String>>{
  'lib/ui/knob_control.dart': ['KnobControl', '_KnobPainter'],
  'lib/ui/led_button.dart': ['LedButton'],
};

final _forbidden = RegExp(r'Gradient\(|BoxShadow\(|MaskFilter|Color\(0x');

/// The source of [className] in [path]: from its `class` line to the next
/// top-level `class` (or the end of the file).
String classSource(String path, String className) {
  final src = File(path).readAsStringSync();
  final start = RegExp(
    '^(?:abstract |final |base |sealed )*class ${RegExp.escape(className)}\\b',
    multiLine: true,
  ).firstMatch(src);

  if (start == null) throw StateError('class $className not found in $path');

  final next = RegExp(
    r'^(?:abstract |final |base |sealed )*class ',
    multiLine: true,
  ).allMatches(src, start.end).firstOrNull;

  return src.substring(start.start, next?.start ?? src.length);
}

void main() {
  for (final MapEntry(key: path, value: classes) in flatClasses.entries) {
    for (final name in classes) {
      test('$name ($path) has no gradient, shadow, blur or inline color', () {
        final hits = _forbidden
            .allMatches(classSource(path, name))
            .map((m) => m.group(0))
            .toSet();

        expect(hits, isEmpty);
      });
    }
  }
}
