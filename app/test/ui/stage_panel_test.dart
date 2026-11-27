import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/model/preset_ref.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/ui/sonic_metrics.dart';
import 'package:sonicmaster/ui/stage_panel.dart';

import '../support/page_harness.dart';
import '../support/silent_transport.dart';
import '../support/test_assets.dart';

/// Stage mode: the narrow Slide Over window over a sheet-music app.
void main() {
  final commands = loadTestDataAssets().commands;
  const slideOver = Size(375, 1100);
  const stageSizes = [Size(320, 1000), slideOver, Size(420, 1180)];

  Finder inStage(Finder f) =>
      find.descendant(of: find.byType(StagePanel), matching: f);

  Future<(ProviderContainer, SilentTransport)> pump(
    WidgetTester tester, {
    Size size = slideOver,
    PresetRef current = const PresetRef(.user, 5),
    Map<PresetRef, String>? names,
    bool isConnected = true,
    List<Override> extra = const [],
  }) async {
    final transport = SilentTransport();
    final c = await pumpPage(
      tester,
      size: size,
      current: current,
      isConnected: isConnected,
      names: names ?? {current: 'Clean'},
      overrides: [
        deviceServiceProvider.overrideWith((ref) {
          final service = DeviceService(transport)..startListening();

          ref.onDispose(service.dispose);

          return service;
        }),
        ...extra,
      ],
    );

    return (c, transport);
  }

  String select(PresetRef p) =>
      commands.presetSelect(p.bank, p.number)!.toLowerCase();

  List<String> sent(SilentTransport t) => [
    for (final f in t.sentFrames) f.toLowerCase(),
  ];

  test('the stage rule: narrow and portrait only', () {
    for (final s in stageSizes) {
      expect(isStageViewport(s), isTrue, reason: '$s');
    }

    for (final s in const [
      Size(820, 1180),
      Size(1180, 820),
      Size(956, 440),
      Size(440, 300),
    ]) {
      expect(isStageViewport(s), isFalse, reason: '$s');
    }
  });

  for (final size in stageSizes) {
    testWidgets('stage mode at $size, no overflow with a long name', (
      tester,
    ) async {
      final long = 'A very long preset name that never fits ' * 3;

      await pump(tester, size: size, names: {const PresetRef(.user, 5): long});

      expect(find.byType(StagePanel), findsOneWidget);
      expect(inStage(find.text('P05')), findsWidgets);
      expect(inStage(find.text('Previous')), findsOneWidget);
      expect(inStage(find.text('Next')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in const [Size(820, 1180), Size(1180, 820), Size(956, 440)]) {
    testWidgets('no stage mode at $size', (tester) async {
      await pump(tester, size: size);

      expect(find.byType(StagePanel), findsNothing);
    });
  }

  testWidgets('Next and Previous load the neighbour preset', (tester) async {
    final (_, transport) = await pump(tester);

    await tester.tap(inStage(find.text('Next')));
    await tester.pump();
    expect(sent(transport), contains(select(const PresetRef(.user, 6))));
    await pumpPastAckTimeout(tester);

    await tester.tap(inStage(find.text('Previous')));
    await tester.pump();
    expect(sent(transport), contains(select(const PresetRef(.user, 4))));
    await pumpPastAckTimeout(tester);
  });

  testWidgets('tapping a row loads that preset', (tester) async {
    final (_, transport) = await pump(tester);

    await tester.tap(inStage(find.text('P08')));
    await tester.pump();
    expect(sent(transport), contains(select(const PresetRef(.user, 8))));
    await pumpPastAckTimeout(tester);
  });

  testWidgets('the current row is highlighted and on screen', (tester) async {
    await pump(tester, current: const PresetRef(.factory, 40));

    final rows = tester.widgetList<StagePresetRow>(find.byType(StagePresetRow));
    final selected = rows.where((r) => r.isSelected).toList();

    expect(selected.map((r) => r.preset), [const PresetRef(.factory, 40)]);
    // The list shows the current preset's bank and scrolled it into view.
    expect(find.widgetWithText(StagePresetRow, 'F40').hitTestable(), findsOne);
  });

  testWidgets('unsaved edits are asked about before Next', (tester) async {
    final (_, transport) = await pump(
      tester,
      extra: [presetModifiedProvider.overrideWith((_) => true)],
    );

    await tester.tap(inStage(find.text('Next')));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    // The unsaved-edits marker sits beside the name.
    expect(inStage(find.textContaining('✱')), findsOneWidget);
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    expect(sent(transport), isNot(contains(select(const PresetRef(.user, 6)))));
    expect(tester.takeException(), isNull);
  });

  for (final size in stageSizes) {
    testWidgets('disconnected at $size: Connect, no overflow', (tester) async {
      await pump(tester, size: size, isConnected: false);

      expect(inStage(find.text('Connect')), findsOneWidget);
      expect(inStage(find.text('Next')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Portuguese labels', (tester) async {
    appLang = Lang.pt;
    addTearDown(() => appLang = Lang.en);

    await pump(tester);
    expect(inStage(find.text('Anterior')), findsOneWidget);
    expect(inStage(find.text('Próximo')), findsOneWidget);
    expect(inStage(find.textContaining('modo palco')), findsOneWidget);

    await pump(tester, isConnected: false);
    expect(inStage(find.text('Conectar')), findsOneWidget);
  });

  testWidgets('golden: stage mode at 375x1100', (tester) async {
    await pump(
      tester,
      names: {
        const PresetRef(.user, 5): 'Clean',
        const PresetRef(.user, 6): 'Crunch Rhythm',
        const PresetRef(.user, 7): 'Lead Solo',
      },
    );

    await expectLater(
      find.byType(StagePanel),
      matchesGoldenFile('goldens/stage_panel_375x1100.png'),
    );
  });
}
