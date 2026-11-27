import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/edit_providers.dart';
import 'package:sonicmaster/ui/chain_view.dart';
import 'package:sonicmaster/ui/knob_control.dart';
import 'package:sonicmaster/ui/led_button.dart';
import 'package:sonicmaster/ui/module_editor.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';

/// The shared controls, the editor and the chain draw their text in the
/// prototype's faces (Inter for UI text, JetBrains Mono for numbers, Space
/// Grotesk for the editor tag), never the old condensed Oswald. The gear
/// pieces keep their own Barlow Condensed.
void main() {
  const faces = {'Inter', 'JetBrains Mono', 'Space Grotesk', 'MaterialIcons'};

  // Every paragraph under [of] that no gear piece draws, with its face.
  Map<String, String?> facesUnder(WidgetTester tester, Finder of) => {
    for (final e
        in find.descendant(of: of, matching: find.byType(RichText)).evaluate())
      if (find
          .ancestor(
            of: find.byWidget(e.widget),
            matching: find.byType(GearPiece),
          )
          .evaluate()
          .isEmpty)
        (e.renderObject! as RenderParagraph).text.toPlainText():
            (e.renderObject! as RenderParagraph).text.style?.fontFamily,
  };

  void expectFaces(WidgetTester tester, Finder of) {
    final found = facesUnder(tester, of);

    for (final MapEntry(:key, :value) in found.entries) {
      expect(faces, contains(value), reason: '"$key" is set in $value');
    }
  }

  for (final size in const [Size(1280, 800), Size(852, 393)]) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()}: '
        'editor, chain and controls', (tester) async {
      final c = await pumpPage(
        tester,
        size: size,
        selectedEffects: {...fullPresetEffects, 7: 701},
        parameters: const {
          7: {1: 500},
        },
        overrides: [
          cfwInfoProvider.overrideWith(
            (_) => decodeCfwSettingsFrame(cfwSettingsOriginal),
          ),
          expKnownProvider.overrideWith((_) => true),
        ],
      );

      c.read(selectedModuleProvider.notifier).state = 3;
      await tester.pump();

      for (final f in [
        find.byType(ModuleEditor),
        find.byType(ChainView),
        find.byType(SonicSegmented<Object?>, skipOffstage: false),
        find.byType(LedButton),
        find.byType(KnobControl),
      ]) {
        if (f.evaluate().isEmpty) continue;
        expectFaces(tester, f.first);
      }

      // Cancels DLY's beat timer.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('button, segments, dropdown, LED, knob', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => Column(
                children: [
                  SonicButton(label: 'Salvar', onPressed: () {}),
                  SonicSegmented<int>(
                    value: 0,
                    segments: const [
                      (value: 0, label: 'A'),
                      (value: 1, label: 'B'),
                    ],
                    onChanged: (_) {},
                  ),
                  SonicDropdown<int>(
                    value: 0,
                    items: const [(value: 0, label: 'Um')],
                    onChanged: (_) {},
                  ),
                  const LedButton(isOn: true, label: 'ON'),
                  KnobControl(
                    value: 50,
                    min: 0,
                    max: 100,
                    step: 1,
                    label: 'Gain',
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    expectFaces(tester, find.byType(Column).first);
    // Numbers in JetBrains Mono.
    expect(
      (tester.renderObject<RenderParagraph>(
        find.text('50'),
      )).text.style!.fontFamily,
      'JetBrains Mono',
    );
  });

  // JetBrains Mono is wider than the old condensed face: a dense knob's
  // reading stays on one line, shrunk to the dial.
  testWidgets('a dense knob reading stays on one line', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Center(
          child: KnobControl(
            value: 2,
            min: -10,
            max: 10,
            step: 0.5,
            label: 'Bass',
            valueText: '+2.0dB',
            size: 32,
            isDense: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final p = tester.renderObject<RenderParagraph>(find.text('+2.0dB'));

    expect(p.getMinIntrinsicHeight(1000), p.size.height);
    expect(tester.getRect(find.text('+2.0dB')).width, lessThanOrEqualTo(32.01));
  });
}
