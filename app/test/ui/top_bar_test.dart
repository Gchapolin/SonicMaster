import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/model/preset_ref.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/ui/dsp_chip.dart';
import 'package:sonicmaster/ui/preset_rail.dart';
import 'package:sonicmaster/ui/top_bar.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';

void main() {
  const regular = Size(1180, 820);
  final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

  setUp(() => appLang = Lang.pt);
  tearDown(() => appLang = Lang.en);

  testWidgets('the appearance button opens the appearance dialog', (
    tester,
  ) async {
    await pumpPage(tester, size: regular);

    final button = find.descendant(
      of: find.byType(TopBar),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Aparência',
      ),
    );

    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('COR DO APP'), findsOneWidget);
  });

  testWidgets('the DSP meter shows the load', (tester) async {
    await pumpPage(
      tester,
      size: regular,
      overrides: [
        cfwInfoProvider.overrideWith((_) => cfw),
        dspLoadProvider.overrideWith((_) => 40),
      ],
    );

    expect(find.text('DSP 40%'), findsOneWidget);

    final fill = tester.getSize(find.byKey(DspChip.fillKey));
    final track = tester.getSize(find.byKey(DspChip.trackKey));

    expect(track, const Size(86, 6));
    expect(fill.width, closeTo(86 * 0.4, 0.5));
  });

  testWidgets('the rail marks the current preset', (tester) async {
    await pumpPage(
      tester,
      size: regular,
      current: const PresetRef(.user, 3),
      names: {const PresetRef(.user, 3): 'Clean'},
    );

    final chips = tester.widgetList<PresetChip>(find.byType(PresetChip));

    expect(chips.where((c) => c.isSelected).map((c) => c.slot), ['P03']);

    final row = find.descendant(
      of: find.byWidgetPredicate((w) => w is PresetChip && w.isSelected),
      matching: find.byType(Container),
    );
    final decoration =
        tester.widget<Container>(row.first).decoration! as BoxDecoration;

    expect((decoration.border as Border).left.color, Palette.primary);
  });
}
