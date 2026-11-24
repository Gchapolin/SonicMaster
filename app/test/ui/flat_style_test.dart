import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The flat Material look, checked in the source: no UI file carries a
/// gradient, shadow, blur or color literal of its own. Every color comes from
/// Palette (lib/theme/app_colors.dart), including the per-module icon colors.
final _forbidden = RegExp(
  r'Gradient\(|BoxShadow\(|MaskFilter|Color\(\s*0x|Color\.from(?:ARGB|RGBO)\(',
);

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
  test('the scan covers the UI files', () {
    expect(
      uiFiles(),
      containsAll([
        'lib/ui/knob_control.dart',
        'lib/ui/chain_view.dart',
        'lib/main.dart',
      ]),
    );
  });

  for (final path in uiFiles()) {
    test('$path has no gradient, shadow, blur or color literal', () {
      final hits = _forbidden
          .allMatches(File(path).readAsStringSync())
          .map((h) => h.group(0))
          .toSet();

      expect(hits, isEmpty);
    });
  }
}
