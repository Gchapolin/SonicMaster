import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/ui/knob_control.dart';
import 'package:sonicmaster/ui/preset_rail.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';
import 'package:sonicmaster/ui/sonic_metrics.dart';

import '../support/sonic_host.dart';

/// KnobControl and PanelCell form one grid: a PanelCell is exactly as tall as a
/// panel-knob cell and centres its control on the dial, in both densities.
/// Heights use Oswald's 1.482-em lines.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpCells(WidgetTester tester, SonicMetrics metrics) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: SonicMetricsScope(
            metrics: metrics,
            child: Align(
              alignment: Alignment.topLeft,
              child: Row(
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                children: [
                  KnobControl(
                    value: 50,
                    min: 0,
                    max: 100,
                    step: 1,
                    label: 'Gain',
                    size: metrics.panelKnobSize,
                    onChanged: (_) {},
                  ),
                  const PanelCell(
                    label: 'Trail',
                    control: SizedBox(
                      key: Key('control'),
                      width: 40,
                      height: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // The prototype faces (JetBrains Mono readout, Inter caption) at their
  // sizes, in whole-pixel lines.
  for (final (metrics, cellSize) in const [
    (SonicMetrics.regular, Size(136, 177)),
    (SonicMetrics.compact, Size(80, 113)),
  ]) {
    final mode = metrics.isCompact ? 'compact' : 'regular';

    testWidgets('$mode: the knob cell and PanelCell share one grid', (
      tester,
    ) async {
      await pumpCells(tester, metrics);

      final knob = tester.getRect(find.byType(KnobControl));
      final cell = tester.getRect(find.byType(PanelCell));
      final dial = tester.getRect(find.byKey(const Key('knob')));
      final control = tester.getRect(find.byKey(const Key('control')));

      expect(dial.size, Size.square(metrics.panelKnobSize));
      expect(knob.width, cellSize.width);
      expect(knob.height, closeTo(cellSize.height, 0.01));
      expect(cell.height, closeTo(knob.height, 0.01));
      expect(control.center.dy, closeTo(dial.center.dy, 0.01));
    });
  }

  testWidgets('compact: the readout and the caption use the compact tokens', (
    tester,
  ) async {
    await pumpCells(tester, SonicMetrics.compact);

    expect(tester.widget<Text>(find.text('50')).style!.fontSize, 13);
    expect(tester.widget<Text>(find.text('GAIN')).style!.fontSize, 10);
    expect(tester.widget<Text>(find.text('TRAIL')).style!.fontSize, 10);
  });

  // The rail's Master Vol is the prototype's compact row: a 44-px dial in
  // both layouts (the rail and the compact drawer).
  for (final size in const [Size(1280, 800), Size(852, 393)]) {
    testWidgets('Master Vol is a 44-px dial at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await pumpSonicHost(
        tester,
        size: size,
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: railWidth,
            child: MasterVolumeRow(onMasterVolume: (_) {}),
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(const Key('knob'))),
        const Size.square(44),
      );
      expect(tester.takeException(), isNull);
    });
  }

  // A tablet turned to portrait while a knob value is being typed: the layout
  // flips regular -> compact under the open editor. A mode only changes sizes
  // and styles, so the editor, its text and its focus survive.
  testWidgets('an open value editor survives a regular -> compact flip', (
    tester,
  ) async {
    final changes = <num>[];

    await pumpSonicHost(
      tester,
      home: Center(
        child: KnobControl(
          value: 50,
          min: 0,
          max: 100,
          step: 1,
          label: 'Gain',
          onChanged: changes.add,
        ),
      ),
    );

    final readout = tester.getCenter(find.text('50'));

    await tester.tapAt(readout);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(readout);
    await tester.pump();
    await tester.enterText(find.byType(EditableText), '73');

    final editor = tester.state<EditableTextState>(find.byType(EditableText));

    tester.view.physicalSize = const Size(800, 1280);
    await tester.pump();

    expect(
      tester.state<EditableTextState>(find.byType(EditableText)),
      same(editor),
    );
    expect(editor.widget.controller.text, '73');
    expect(editor.widget.focusNode.hasFocus, isTrue);
    expect(editor.widget.style.fontSize, 13);

    await tester.testTextInput.receiveAction(.done);
    await tester.pump();

    expect(changes, [73]);
    expect(find.byType(EditableText), findsNothing);

    // Flushes the double-tap recognizer's timer.
    await tester.pump(const Duration(milliseconds: 50));
  });
}
