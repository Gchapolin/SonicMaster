import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/preset_ref.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/ui/top_bar.dart';

import '../support/page_harness.dart';
import '../support/view_helpers.dart';

void main() {
  Finder inBar(Finder f) =>
      find.descendant(of: find.byType(TopBar), matching: f);

  for (final size in const [Size(1280, 800), Size(852, 393)]) {
    final where = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('$where: Preset Vol and BPM sit in the top bar', (
      tester,
    ) async {
      await pumpPage(tester, size: size);

      expect(inBar(find.text('VOL')), findsOneWidget);
      expect(inBar(find.text('44')), findsOneWidget);
      expect(inBar(find.text('BPM')), findsOneWidget);
      expect(inBar(find.text('120')), findsOneWidget);
      // They sit right after the preset name, not in the work area.
      expect(find.text('PRESET VOL'), findsNothing);
      expect(
        tester.getRect(inBar(find.text('VOL'))).left,
        greaterThan(tester.getRect(inBar(find.text('Clean'))).right),
      );
      expectNoOverflow(tester);
    });
  }

  testWidgets('dragging VOL up raises the preset volume', (tester) async {
    final c = await pumpPage(tester, size: const Size(852, 393));

    await tester.drag(inBar(find.text('44')), const Offset(0, -50));
    await tester.pump();

    expect(c.read(currentPresetStateProvider)!.presetVolume, greaterThan(44));
    expect(c.read(presetModifiedProvider), isTrue);
  });

  testWidgets('dragging BPM stops at its range', (tester) async {
    final c = await pumpPage(tester, size: const Size(852, 393));

    await tester.drag(inBar(find.text('120')), const Offset(0, -2000));
    await tester.pump();
    expect(c.read(currentPresetStateProvider)!.presetBpm, presetBpmMax);

    await tester.drag(inBar(find.text('$presetBpmMax')), const Offset(0, 4000));
    await tester.pump();
    expect(c.read(currentPresetStateProvider)!.presetBpm, presetBpmMin);
  });

  testWidgets('tapping a value opens the two knobs', (tester) async {
    await pumpPage(tester, size: const Size(852, 393));

    await tester.tap(inBar(find.text('120')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('PRESET VOL'), findsOneWidget);
    expectNoOverflow(tester);

    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('PRESET VOL'), findsNothing);
  });

  testWidgets('while a preset loads the values do not move', (tester) async {
    final c = await pumpPage(
      tester,
      size: const Size(852, 393),
      overrides: [presetLoadingProvider.overrideWith((_) => true)],
    );

    await tester.drag(inBar(find.text('44')), const Offset(0, -50));
    await tester.pump();

    expect(c.read(currentPresetStateProvider)!.presetVolume, 44);
  });

  testWidgets('disconnected: no preset values in the bar', (tester) async {
    await pumpPage(tester, size: const Size(852, 393), isConnected: false);

    expect(inBar(find.text('VOL')), findsNothing);
  });

  testWidgets('the narrowest phone bar still fits with a long name', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(568, 320),
      names: {const PresetRef(.user, 1): 'WWWWWWWWWW'},
      selectedEffects: const {},
    );

    expectNoOverflow(tester);
    expect(inBar(find.text('VOL')), findsOneWidget);
    expect(inBar(find.text('BPM')), findsOneWidget);
  });
}
