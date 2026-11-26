import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/model/battery_status.dart';
import 'package:sonicmaster/model/preset_ref.dart';
import 'package:sonicmaster/state/layout_providers.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/ui/dsp_chip.dart';
import 'package:sonicmaster/ui/preset_rail.dart';
import 'package:sonicmaster/ui/top_bar.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';
import '../support/view_helpers.dart';

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

  Finder inBar(Finder f) =>
      find.descendant(of: find.byType(TopBar), matching: f);
  final appearanceButton = inBar(
    find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Aparência',
    ),
  );

  group('appearance on tall tablets and phones', () {
    for (final size in const [Size(820, 1180), Size(834, 1194)]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}: the bar '
          'opens the dialog', (tester) async {
        await pumpPage(tester, size: size);
        expectNoOverflow(tester);

        await tester.tap(appearanceButton);
        await tester.pumpAndSettle();

        expect(find.text('COR DO APP'), findsOneWidget);
      });
    }

    testWidgets('568x320: no overflow, the drawer reaches the dialog', (
      tester,
    ) async {
      final c = await pumpPage(tester, size: const Size(568, 320));
      expectNoOverflow(tester);

      c.read(presetDrawerOpenProvider.notifier).state = true;
      await tester.pumpAndSettle();
      // The drawer opens scrolled to the loaded preset: scroll back up.
      await tester.ensureVisible(
        find.byKey(const ValueKey('drawer-appearance')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('drawer-appearance')));
      await tester.pumpAndSettle();

      expect(find.text('COR DO APP'), findsOneWidget);
    });

    testWidgets('the drawer entry exists while disconnected too', (
      tester,
    ) async {
      final c = await pumpPage(
        tester,
        size: const Size(568, 320),
        isConnected: false,
      );

      c.read(presetDrawerOpenProvider.notifier).state = true;
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('drawer-appearance')), findsOneWidget);
    });
  });

  testWidgets('1180x820 with CFW, DSP, battery and tuner: one row, no '
      'overflow', (tester) async {
    await pumpPage(
      tester,
      size: regular,
      overrides: [
        cfwInfoProvider.overrideWith((_) => cfw),
        dspLoadProvider.overrideWith((_) => 40),
        batteryProvider.overrideWith(
          (_) => const BatteryStatus(
            flags: 1,
            millivolts: 3880,
            charge: BatteryCharge.onBattery,
            bars: 3,
            emptyMillivolts: 3540,
          ),
        ),
      ],
    );
    expectNoOverflow(tester);

    final bar = tester.getRect(find.byType(TopBar));
    final items = [
      inBar(find.byIcon(Icons.chevron_left)),
      inBar(find.byIcon(Icons.chevron_right)),
      appearanceButton,
      inBar(find.byIcon(Icons.save)),
      inBar(find.byIcon(Icons.music_note)),
      inBar(find.text('DSP 40%')),
    ];

    for (final item in items) {
      expect(item, findsOneWidget);

      final r = tester.getRect(item);

      expect(r.left, greaterThanOrEqualTo(bar.left));
      expect(r.right, lessThanOrEqualTo(bar.right));
      expect(r.center.dy, closeTo(bar.center.dy, 12));
    }
  });

  testWidgets('Salvar is a primary filled button', (tester) async {
    await pumpPage(tester, size: regular);

    final save = find.byKey(const ValueKey('save-button'));
    final fill = tester.widget<DecoratedBox>(
      find.descendant(of: save, matching: find.byType(DecoratedBox)).first,
    );

    expect((fill.decoration as BoxDecoration).color, Palette.primary);
    expect(
      tester
          .widget<Text>(
            find.descendant(of: save, matching: find.text('Salvar')),
          )
          .style
          ?.color,
      Palette.onPrimary,
    );
  });
}
