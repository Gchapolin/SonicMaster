import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/state/edit_providers.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/theme/app_palettes.dart';

import '../support/page_harness.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();

  return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
}

void main() {
  tearDown(() => Palette.current = appPalettes.first);

  testWidgets('the amp band chip text reads at 4.5:1 on all 18 palettes', (
    tester,
  ) async {
    for (final p in appPalettes) {
      Palette.current = p;
      await pumpPage(
        tester,
        size: const Size(1180, 820),
        selectedEffects: const {3: 308},
        parameters: const {},
        overrides: [selectedModuleProvider.overrideWith((_) => 3)],
      );

      final chip = find.byKey(const Key('amp-band'));
      final fill =
          (tester.widget<DecoratedBox>(chip).decoration as BoxDecoration)
              .color!;
      final text = tester.widget<Text>(
        find.descendant(of: chip, matching: find.byType(Text)),
      );

      // The fill is opaque, so the pair is the whole story.
      expect(fill.a, 1, reason: p.id);
      expect(
        _contrast(text.style!.color!, fill),
        greaterThanOrEqualTo(4.5),
        reason: p.id,
      );
    }
  });
}
