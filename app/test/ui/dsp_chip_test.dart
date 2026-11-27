import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/ui/dsp_chip.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/sonic_host.dart';

void main() {
  final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

  Future<void> pump(WidgetTester tester, {int? load, bool isCfw = true}) =>
      pumpSonicHost(
        tester,
        home: const Center(child: DspChip()),
        overrides: [
          connectionStateProvider.overrideWith((_) => true),
          cfwInfoProvider.overrideWith((_) => isCfw ? cfw : null),
          dspLoadProvider.overrideWith((_) => load),
        ],
      );

  Color? colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  testWidgets('shows the DSP load of a CFW pedal', (tester) async {
    await pump(tester, load: 57);

    expect(find.text('DSP 57%'), findsOneWidget);
    expect(colorOf(tester, 'DSP 57%'), Palette.meterCaption);
  });

  testWidgets('turns to the alert color from 85 %', (tester) async {
    await pump(tester, load: 90);

    expect(colorOf(tester, 'DSP 90%'), Palette.error);
  });

  testWidgets('caps a value over 100 at 100 %', (tester) async {
    await pump(tester, load: 250);

    expect(find.text('DSP 100%'), findsOneWidget);
  });

  testWidgets('is absent on stock firmware or before the first read', (
    tester,
  ) async {
    await pump(tester, load: 57, isCfw: false);
    expect(find.textContaining('DSP'), findsNothing);

    await pump(tester);
    expect(find.textContaining('DSP'), findsNothing);
  });
}
