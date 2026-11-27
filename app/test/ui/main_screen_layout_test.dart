import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/model/cfw_exp.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/edit_providers.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/ui/block_panel.dart';
import 'package:sonicmaster/ui/chain_view.dart';
import 'package:sonicmaster/ui/module_editor.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';
import '../support/view_helpers.dart';

/// The main screen against the prototype (N_Principal.dc.html): the 210-px
/// pedalboard band with its cable, the editor straight on the background,
/// the value line always on screen, and the block panel's cards.
void main() {
  // The iPad's status bar and home indicator.
  const insets = FakeViewPadding(top: 24, bottom: 20);
  const landscape = Size(1180, 820);
  const portrait = Size(820, 1180);

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    Map<int, int> effects = fullPresetEffects,
    int module = 0,
    bool isCfw = false,
  }) async {
    tester.view.padding = insets;
    final c = await pumpPage(
      tester,
      size: size,
      selectedEffects: effects,
      parameters: const {},
      overrides: [
        if (isCfw) ...[
          cfwInfoProvider.overrideWith(
            (_) => decodeCfwSettingsFrame(cfwSettingsOriginal),
          ),
          expAssignsProvider.overrideWith((_) => [null, null, null, null]),
          expKnownProvider.overrideWith((_) => true),
        ],
      ],
    );

    c.read(selectedModuleProvider.notifier).state = module;
    await tester.pump();
  }

  // Cancels DLY's beat timer before the test ends.
  tearDown(() => appLang = Lang.en);

  testWidgets('the pedalboard band: 210 tall, side colour, hairline, cable', (
    tester,
  ) async {
    await pumpAt(tester, landscape);

    final band = find.byKey(const Key('pedalboard-band'));
    final rect = tester.getRect(band);
    final deco = tester.widget<DecoratedBox>(band).decoration as BoxDecoration;

    expect(rect.height, 210);
    expect(deco.color, Palette.surfaceContainerLow);
    expect((deco.border! as Border).bottom.color, Palette.outlineVariant);
    expect((deco.border! as Border).bottom.width, 1);
    expect(
      find.descendant(of: band, matching: find.byType(ChainView)),
      findsOneWidget,
    );

    final cable = find.byKey(const Key('pedalboard-cable'));
    final line = tester.getRect(cable);

    expect(line.height, 2);
    expect(line.left, rect.left + 24);
    expect(line.right, rect.right - 24);
    expect(
      (tester.widget<ColoredBox>(cable)).color,
      Palette.outlineVariant,
    );

    // At the pieces' vertical centre, behind them.
    final pieces = find.descendant(
      of: find.byType(ChainView),
      matching: find.byType(GearPiece),
    );
    final centres = [
      for (final e in pieces.evaluate())
        tester.getRect(find.byWidget(e.widget)).center.dy,
    ];
    final mid = centres.reduce((a, b) => a + b) / centres.length;

    expect((line.center.dy - mid).abs(), lessThan(8));

    final stack = tester.widget<Stack>(
      find.ancestor(of: cable, matching: find.byType(Stack)).first,
    );
    final order = stack.children.map((w) => w.key).toList();

    expect(order.indexOf(const Key('pedalboard-cable-slot')), 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the fixed block is labelled and the label clears the pieces', (
    tester,
  ) async {
    appLang = Lang.pt;
    await pumpAt(tester, landscape);

    final label = find.text('BLOCO FIXO');

    expect(label, findsOneWidget);

    final r = tester.getRect(label);

    for (final e in find.byType(GearPiece).evaluate()) {
      final piece = tester.getRect(find.byWidget(e.widget));

      expect(r.overlaps(piece), isFalse, reason: '$piece');
    }
    expectWithin(
      r,
      tester.getRect(find.byKey(const Key('pedalboard-band'))),
      'label',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the editor sits on the background, 16 under the band', (
    tester,
  ) async {
    await pumpAt(tester, landscape);

    final band = tester.getRect(find.byKey(const Key('pedalboard-band')));
    final editor = tester.getRect(find.byType(ModuleEditor));
    final surface = tester.widget<SonicSurface>(
      find.ancestor(
        of: find.byType(ModuleEditor),
        matching: find.byType(SonicSurface),
      ),
    );

    expect(editor.top, band.bottom + 16);
    expect(editor.left, band.left + 16);
    expect(editor.right, band.right - 16);
    expect(surface.color, Palette.transparent);
    expect(surface.borderColor, Palette.transparent);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // (module, effect): Gate pedal, Brit 800 amp, Analog rack, Pure delay,
  // Studio Delay (CFW).
  const kinds = [(0, 1), (3, 308), (7, 707), (7, 701), (8, 802)];

  for (final size in const [landscape, portrait]) {
    for (final (module, fx) in kinds) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} effect $fx: '
          'the value line is on screen', (tester) async {
        await pumpAt(
          tester,
          size,
          effects: {...fullPresetEffects, module: fx},
          module: module,
        );
        expectNoOverflow(tester);

        final screen = Rect.fromLTRB(0, 24, size.width, size.height - 20);
        final line = find.byKey(const Key('piece-value'));

        expect(line, findsOneWidget);
        expectWithin(tester.getRect(line), screen, 'value line');
        expectWithin(
          tester.getRect(
            find.descendant(
              of: find.byType(ModuleEditor),
              matching: find.byType(GearPiece),
            ),
          ),
          screen,
          'piece',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  group('block panel', () {
    Finder inPanel(Finder f) =>
        find.descendant(of: find.byType(BlockPanel), matching: f);

    testWidgets('top card: card fill, line border, radius 14, padding 14', (
      tester,
    ) async {
      await pumpAt(tester, landscape, module: 7, effects: {7: 707});

      final card = tester.widget<Container>(find.byKey(const Key('panel-card')));
      final deco = card.decoration! as BoxDecoration;

      expect(deco.color, Palette.surfaceContainerHigh);
      expect((deco.border! as Border).top.color, Palette.outlineVariant);
      expect(deco.borderRadius, BorderRadius.circular(14));
      expect(card.padding, const EdgeInsets.all(14));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('pt: sentence-case Inter rows, upper-case headers', (
      tester,
    ) async {
      appLang = Lang.pt;
      await pumpAt(tester, landscape, module: 7, effects: {7: 707}, isCfw: true);

      for (final label in ['Bloco ligado', 'Sync', 'Cenas']) {
        final style = tester.widget<Text>(inPanel(find.text(label))).style!;

        expect(style.fontFamily, 'Inter', reason: label);
        expect(style.fontSize, 13, reason: label);
        expect(style.fontWeight, FontWeight.w500, reason: label);
      }
      expect(inPanel(find.text('CENAS')), findsNothing);
      for (final header in ['FOOTSWITCH', 'PEDAL DE EXPRESSÃO']) {
        final style = tester.widget<Text>(inPanel(find.text(header))).style!;

        expect(style.fontSize, 11, reason: header);
        expect(style.fontWeight, FontWeight.w600, reason: header);
        expect(style.letterSpacing, 1, reason: header);
        expect(style.color, Palette.outline, reason: header);
      }
      // The footswitch: sentence case, Inter, on a filled ctrl track.
      final fs = find.byKey(const Key('panel-footswitch'));

      for (final label in ['Nenhum', 'FS1', 'FS2']) {
        final text = find.descendant(of: fs, matching: find.text(label));

        expect(text, findsOneWidget, reason: label);
        expect(tester.widget<Text>(text).style!.fontFamily, 'Inter');
      }
      final track = tester.widget<Container>(
        find.descendant(of: fs, matching: find.byKey(const Key('seg-track'))),
      );
      final trackDeco = track.decoration! as BoxDecoration;

      expect(trackDeco.color, Palette.surfaceContainerHighest);
      expect(trackDeco.borderRadius, BorderRadius.circular(10));
      expect(track.padding, const EdgeInsets.all(3));
      // A 44-pt hit area around it.
      expect(tester.getSize(fs).height, greaterThanOrEqualTo(44));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('EXP: slot and target on one row, filled, 34 high', (
      tester,
    ) async {
      appLang = Lang.pt;
      await pumpAt(tester, landscape, module: 7, effects: {7: 707}, isCfw: true);

      expect(inPanel(find.text('EXP')), findsNothing);

      final slot = tester.getRect(find.byKey(const Key('exp-slot-box')));
      final target = tester.getRect(find.byKey(const Key('exp-target-box')));
      final card = tester.getRect(find.byKey(const Key('panel-card')));

      expect(slot.size, const Size(44, 34));
      expect(target.height, 34);
      expect(target.center.dy, slot.center.dy);
      expect(target.left, slot.right + 6);
      expect(target.right, card.right - 1 - 14);
      // "Nenhum" on one line.
      expect(
        tester.getSize(inPanel(find.text('Nenhum')).last).height,
        lessThan(20),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the description fills the rest of the panel', (tester) async {
      await pumpAt(tester, landscape, module: 7, effects: {7: 707});

      final desc = find.byKey(const Key('panel-description'));
      final panel = tester.getRect(find.byType(BlockPanel));
      final card = tester.widget<Container>(desc);
      final deco = card.decoration! as BoxDecoration;

      expect(tester.getRect(desc).bottom, panel.bottom);
      expect(deco.color, Palette.surfaceContainerHigh);
      expect(deco.borderRadius, BorderRadius.circular(14));
      expect(card.padding, const EdgeInsets.all(14));

      final text = tester.widget<Text>(
        find.descendant(of: desc, matching: find.byType(Text)),
      );

      expect(text.style!.fontFamily, 'Inter');
      expect(text.style!.fontSize, 13);
      expect(text.style!.height, 1.55);
      expect(text.style!.color, Palette.textDescription);
      expect(
        find.descendant(of: desc, matching: find.byType(Scrollable)),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('the model header: filled selector and arrows, tag column', (
    tester,
  ) async {
    await pumpAt(tester, landscape, module: 7, effects: {7: 707});

    final box = tester.widget<Container>(
      find.byKey(const Key('model-selector-box')),
    );
    final deco = box.decoration! as BoxDecoration;

    expect(deco.color, Palette.surfaceContainerHighest);
    expect(deco.border, isNull);
    expect(deco.borderRadius, BorderRadius.circular(10));
    expect(
      tester.getSize(find.byKey(const Key('model-selector-box'))).height,
      36,
    );
    expect(
      tester.getSize(find.byKey(const Key('model-selector-box'))).width,
      greaterThanOrEqualTo(220),
    );

    final label = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('model-selector-box')),
        matching: find.text('Analog'),
      ),
    );

    expect(label.style!.fontFamily, 'Inter');
    expect(label.style!.fontSize, 15);
    expect(label.style!.fontWeight, FontWeight.w600);

    for (final k in ['model-prev', 'model-next']) {
      final arrow = find.descendant(
        of: find.byKey(Key(k)),
        matching: find.byKey(const Key('arrow-box')),
      );

      expect(tester.getSize(arrow), const Size(36, 36));
      expect(tester.getSize(find.byKey(Key(k))).height, 44);
    }

    final tag = tester.widget<Text>(
      find.descendant(
        of: find.byType(ModuleEditor),
        matching: find.text('DLY'),
      ),
    );

    expect(tag.style!.fontFamily, 'Space Grotesk');
    expect(tag.style!.fontSize, 13);
    expect(tag.style!.fontWeight, FontWeight.w600);
    expect(tag.style!.letterSpacing, 1);
    expect(tag.style!.color, Palette.outline);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // isCompactViewport: below 960 wide or 600 tall.
  for (final size in const [
    Size(852, 393),
    Size(1180, 590),
    Size(820, 1180),
    Size(956, 440),
  ]) {
    testWidgets('compact ${size.width.toInt()}x${size.height.toInt()}: '
        'no overflow', (tester) async {
      for (final (module, fx) in kinds) {
        await pumpAt(
          tester,
          size,
          effects: {...fullPresetEffects, module: fx},
          module: module,
        );
        expectNoOverflow(tester);
        expect(find.byKey(const Key('pedalboard-cable')), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}
