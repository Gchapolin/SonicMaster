import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The flat Material look, checked in the source: no class in the UI carries a
/// gradient, shadow, blur or inline color of its own. Every color comes from
/// Palette (lib/theme/app_colors.dart). Top-level data such as the per-module
/// icon colors (moduleIconColor in chain_view.dart) are not classes and stay
/// out of the check.
final _forbidden = RegExp(r'Gradient\(|BoxShadow\(|MaskFilter|Color\(0x');

final _classLine = RegExp(
  r'^(?:abstract |final |base |sealed )*class (\w+)',
  multiLine: true,
);

/// The source of [className] in [path]: from its `class` line to the next
/// top-level `class` (or the end of the file).
String classSource(String path, String className) {
  final src = File(path).readAsStringSync();
  final start = RegExp(
    '^(?:abstract |final |base |sealed )*class ${RegExp.escape(className)}\\b',
    multiLine: true,
  ).firstMatch(src);

  if (start == null) throw StateError('class $className not found in $path');

  final next = _classLine.allMatches(src, start.end).firstOrNull;

  return src.substring(start.start, next?.start ?? src.length);
}

/// Every UI source file: lib/ui/*.dart and the app frame in lib/main.dart.
List<String> uiFiles() => [
  ...Directory('lib/ui')
      .listSync()
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.endsWith('.dart')),
  'lib/main.dart',
]..sort();

void main() {
  test('the scan finds the UI classes', () {
    final names = {
      for (final path in uiFiles())
        for (final m in _classLine.allMatches(File(path).readAsStringSync()))
          m.group(1),
    };

    expect(names, containsAll(['KnobControl', 'ModuleCard', 'SonicToggle']));
  });

  for (final path in uiFiles()) {
    for (final m in _classLine.allMatches(File(path).readAsStringSync())) {
      final name = m.group(1)!;

      test('$name ($path) has no gradient, shadow, blur or inline color', () {
        final hits = _forbidden
            .allMatches(classSource(path, name))
            .map((h) => h.group(0))
            .toSet();

        expect(hits, isEmpty);
      });
    }
  }
}
