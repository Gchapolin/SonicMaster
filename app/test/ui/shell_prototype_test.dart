import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/model/battery_status.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/state/reconnect.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/ui/dsp_chip.dart';
import 'package:sonicmaster/ui/global_settings_dialog.dart';
import 'package:sonicmaster/ui/preset_browser_page.dart';
import 'package:sonicmaster/ui/preset_rail.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';
import 'package:sonicmaster/ui/top_bar.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';
import '../support/sonic_host.dart';
import '../support/test_assets.dart';
import '../support/view_helpers.dart';

/// The editor shell against the prototype (docs/design/prototipo/
/// N_Principal.dc.html) on the iPad landscape it was drawn for.
void main() {
  const ipad = Size(1180, 820);
  final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

  setUp(() => appLang = Lang.pt);
  tearDown(() => appLang = Lang.en);

  Finder inBar(Finder f) =>
      find.descendant(of: find.byType(TopBar), matching: f);
  Finder inRail(Finder f) =>
      find.descendant(of: find.byType(PresetRail), matching: f);

  // The demo pedal: a CFW Pocket Master with its DSP load and battery.
  final demo = <Override>[
    connectedDeviceNameProvider.overrideWith((_) => demoDeviceName),
    cfwInfoProvider.overrideWith((_) => cfw),
    dspLoadProvider.overrideWith((_) => 42),
    batteryProvider.overrideWith(
      (_) => const BatteryStatus(
        flags: 1,
        millivolts: 3880,
        charge: BatteryCharge.onBattery,
        bars: 3,
        emptyMillivolts: 3540,
      ),
    ),
  ];

  TextStyle styleOf(WidgetTester tester, Finder text) {
    final widget = tester.widget<Text>(text);

    return DefaultTextStyle.of(
      tester.element(text),
    ).style.merge(widget.style ?? widget.textSpan?.style);
  }

  testWidgets('the app-wide default text is Inter', (tester) async {
    await pumpPage(tester, size: ipad);

    final page = tester.element(find.byType(PresetBrowserPage));

    expect(DefaultTextStyle.of(page).style.fontFamily, 'Inter');
  });

  group('top bar at 1180x820 on the demo pedal', () {
    testWidgets('fits one row: no overflow, the device name on screen', (
      tester,
    ) async {
      await pumpPage(tester, size: ipad, overrides: demo);
      expectNoOverflow(tester);

      final bar = tester.getRect(find.byType(TopBar));
      final name = inBar(find.text(demoDeviceName));

      expect(name, findsOneWidget);
      expect(tester.getRect(name).right, lessThanOrEqualTo(bar.right));
      // The status is a dot and the name: Desconectar moved to a menu.
      expect(inBar(find.text('Desconectar')), findsNothing);
      expect(styleOf(tester, name).fontFamily, 'Inter');
      expect(styleOf(tester, name).fontSize, 13);
    });

    testWidgets('tapping the device status offers Desconectar', (tester) async {
      final c = await pumpPage(tester, size: ipad, overrides: demo);

      await tester.tap(inBar(find.text(demoDeviceName)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final disconnect = find.text('Desconectar');

      expect(disconnect, findsOneWidget);

      await tester.tap(disconnect);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(c.read(connectionStateProvider), isFalse);
    });

    testWidgets('the icons run tuner, community, appearance, settings, the '
        'file actions, Salvar, then the device', (tester) async {
      await pumpPage(tester, size: ipad, overrides: demo);

      final order = [
        inBar(find.byIcon(Icons.music_note)),
        inBar(find.byIcon(Icons.public)),
        inBar(find.byIcon(Icons.palette)),
        inBar(find.byIcon(Icons.tune)),
        inBar(find.byIcon(Icons.file_download)),
        inBar(find.byIcon(Icons.file_upload)),
        inBar(find.text('Salvar')),
        inBar(find.text(demoDeviceName)),
      ].map((f) => tester.getRect(f).left).toList();

      for (var i = 1; i < order.length; i++) {
        expect(order[i], greaterThan(order[i - 1]), reason: 'item $i');
      }

      // DSP sits before the tuner.
      expect(
        tester.getRect(inBar(find.text('DSP 42%'))).left,
        lessThan(order.first),
      );
    });

    testWidgets('the DSP meter stacks its label over the bar', (tester) async {
      await pumpPage(tester, size: ipad, overrides: demo);

      final label = inBar(find.text('DSP 42%'));
      final track = tester.getRect(find.byKey(DspChip.trackKey));

      expect(styleOf(tester, label).fontFamily, 'Barlow Condensed');
      expect(styleOf(tester, label).fontSize, 10);
      expect(tester.getRect(label).bottom, lessThanOrEqualTo(track.top));
      expect(track.size, const Size(86, 6));
    });
  });

  group('preset, VOL, BPM and TAP', () {
    testWidgets('the pill: slot in mono accent, name in Inter 15 w600', (
      tester,
    ) async {
      await pumpPage(tester, size: ipad);

      final slot = styleOf(tester, inBar(find.text('P01')));
      final name = styleOf(tester, inBar(find.text('Clean')));

      expect(slot.fontFamily, 'JetBrains Mono');
      expect(slot.fontSize, 13);
      expect(slot.color, Palette.primary);
      expect(name.fontFamily, 'Inter');
      expect(name.fontSize, 15);
      expect(name.fontWeight, FontWeight.w600);
    });

    testWidgets('VOL and BPM: a small label over a mono value, 44-pt '
        'targets', (tester) async {
      await pumpPage(tester, size: ipad);

      final label = styleOf(tester, inBar(find.text('VOL')));
      final value = styleOf(tester, inBar(find.text('44')));

      expect(label.fontSize, 10);
      expect(value.fontFamily, 'JetBrains Mono');
      expect(value.fontSize, 15);
      expect(
        tester.getRect(inBar(find.text('VOL'))).bottom,
        lessThanOrEqualTo(tester.getRect(inBar(find.text('44'))).top + 1),
      );

      final target = find
          .ancestor(
            of: inBar(find.text('120')),
            matching: find.byType(GestureDetector),
          )
          .first;

      expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(target).width, greaterThanOrEqualTo(44));
    });

    testWidgets('TAP sits right of BPM and taps the preset tempo', (
      tester,
    ) async {
      final c = await pumpPage(tester, size: ipad);
      final tap = inBar(find.text('TAP'));

      expect(tap, findsOneWidget);
      expect(
        tester.getRect(tap).left,
        greaterThan(tester.getRect(inBar(find.text('BPM'))).right),
      );

      // Four taps 400 ms apart: 150 BPM.
      final at = tester.getCenter(tap);
      final pointer = TestPointer(1, PointerDeviceKind.touch);

      for (var i = 0; i < 4; i++) {
        final t = Duration(milliseconds: 400 * i);

        await tester.sendEventToBinding(pointer.down(at, timeStamp: t));
        await tester.sendEventToBinding(pointer.up(timeStamp: t));
        await tester.pump();
      }

      expect(c.read(currentPresetStateProvider)!.presetBpm, 150);
    });
  });

  group('rail', () {
    testWidgets('bank segments read Fábrica / Usuário, search in Inter', (
      tester,
    ) async {
      await pumpPage(tester, size: ipad);

      expect(inRail(find.text('Fábrica')), findsOneWidget);
      expect(inRail(find.text('Usuário')), findsOneWidget);
      expect(find.text('FÁBRICA'), findsNothing);
      expect(find.text('USUÁRIO'), findsNothing);
      expect(styleOf(tester, inRail(find.text('Fábrica'))).fontFamily, 'Inter');
    });

    testWidgets('master volume is a compact row at the bottom of the rail', (
      tester,
    ) async {
      await pumpPage(tester, size: ipad);

      final rail = tester.getRect(find.byType(PresetRail));
      final label = inRail(find.text('VOLUME GERAL'));
      final knob = inRail(find.byKey(const Key('knob')));

      expect(label, findsOneWidget);
      expect(tester.getRect(label).bottom, greaterThan(rail.bottom - 70));
      expect(tester.getSize(knob).width, lessThanOrEqualTo(44));
      expect(tester.getRect(knob).left, lessThan(tester.getRect(label).left));
      expect(
        styleOf(tester, inRail(find.text('75'))).fontFamily,
        'JetBrains Mono',
      );
      // The preset list sits above it.
      expect(
        tester.getRect(inRail(find.text('P01'))).top,
        lessThan(tester.getRect(label).top),
      );
      expectNoOverflow(tester);
    });

    testWidgets('no footer credit in the rail', (tester) async {
      await pumpPage(tester, size: ipad);

      expect(find.textContaining('Skyggedans'), findsNothing);
    });
  });

  testWidgets('Ajustes shows the version and the Skyggedans credit', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'SonicMaster',
      packageName: 'dev.skyggedans.sonicmaster',
      version: '1.0.8',
      buildNumber: '1',
      buildSignature: '',
    );

    final context = await pumpSonicHost(
      tester,
      size: ipad,
      overrides: [dataAssetsProvider.overrideWith((_) => loadTestDataAssets())],
    );

    unawaited(
      showSonicDialog<void>(
        context: context,
        builder: (_) => const GlobalSettingsDialog(),
      ),
    );
    await tester.pumpAndSettle();

    final dialog = find.byType(GlobalSettingsDialog);

    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('SonicMaster 1.0.8'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('por Skyggedans'),
      ),
      findsOneWidget,
    );
  });
}
