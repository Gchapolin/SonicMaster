// The Preset Vol + BPM panel the top bar's values open: two full knobs side
// by side at a fixed width.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/ui/knob_control.dart';
import 'package:sonicmaster/ui/preset_fields_panel.dart';
import 'package:sonicmaster/ui/sonic_metrics.dart';

import '../support/view_helpers.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    SonicMetrics metrics = SonicMetrics.regular,
    bool isLoading = false,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: SonicMetricsScope(
            metrics: metrics,
            child: Center(
              child: PresetFieldsPanel(
                presetVolume: 44,
                presetBpm: 120,
                isLoading: isLoading,
                onVolume: (_) {},
                onBpm: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final (mode, metrics, width) in const [
    ('regular', SonicMetrics.regular, 360.0),
    ('compact', SonicMetrics.compact, 194.0),
  ]) {
    testWidgets('$mode: both knobs on one line at the fixed width', (
      tester,
    ) async {
      await pump(tester, metrics: metrics);

      final knobs = find.byType(KnobControl);

      expect(knobs, findsNWidgets(2));
      expect(tester.getSize(find.byType(PresetFieldsPanel)).width, width);
      expect(
        tester.getTopLeft(knobs.first).dy,
        tester.getTopLeft(knobs.last).dy,
      );
      expectNoOverflow(tester);
    });
  }

  testWidgets('while a preset loads the knobs are disabled', (tester) async {
    await pump(tester, isLoading: true);

    for (final k in tester.widgetList<KnobControl>(find.byType(KnobControl))) {
      expect(k.isEnabled, isFalse);
    }
  });

  testWidgets('compact at 130% text reflows instead of overflowing', (
    tester,
  ) async {
    await pump(tester, metrics: SonicMetrics.compact, textScale: 1.3);

    expectNoOverflow(tester);
  });
}
