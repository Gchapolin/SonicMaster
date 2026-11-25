// Live CFW gate — requires a Pocket Master running the community custom
// firmware, advertising over BLE ("Pocket Master BLE"), and free (no other app
// connected to it).
// Proves, on the real device, that the app detects the CFW, that the Settings
// dialog's theme control reaches the pedal, and that the DSP load reads back.
// Leaves the pedal's theme as it found it.
// Run: flutter test integration_test/cfw_settings_live_test.dart -d <device>
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/device/transport.dart';
import 'package:sonicmaster/device/transport_factory.dart';
import 'package:sonicmaster/device/transport_packages.dart';
import 'package:sonicmaster/main.dart';
import 'package:sonicmaster/protocol/cfw_setting_writer.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/global_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/ui/global_settings_dialog.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

const _themes = [
  'Default',
  'Amber CRT',
  'Tube Amp',
  'Synthwave',
  'Stage Hi-Contrast',
  'Game Boy',
];

/// Lets real time pass (BLE round-trips) while frames keep pumping.
Future<void> _settle(WidgetTester tester, {int ms = 1500}) async {
  for (var waited = 0; waited < ms; waited += 100) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CFW settings round-trip on the real pedal', (tester) async {
    await initTransports();

    final devices = await enumerateBleDevices();
    final pedal = devices
        .map((d) => d.name)
        .firstWhere((n) => n.contains('Pocket Master'), orElse: () => '');

    expect(pedal, isNotEmpty, reason: 'no Pocket Master advertising over BLE');

    final service = DeviceService(UniversalBleTransport())..startListening();

    await service.connect(target: pedal);
    addTearDown(service.disconnect);

    // 1. Detection.
    final hex = await service.requestCfwSettings(
      timeout: const Duration(seconds: 3),
    );
    final info = hex == null ? null : decodeCfwSettingsFrame(hex);

    expect(info, isNotNull, reason: 'the pedal did not answer 12 2A as a CFW');
    // ignore: avoid_print
    print('CFW ${info!.version} settings ${info.settings}');

    final original = info.theme;
    final target = original == 0 ? 1 : 0;

    // 2. The Settings dialog, on the live pedal, changes the theme.
    final global = const GlobalSettingsDecoder().decode(
      (await service.requestGlobalSettings(
        timeout: const Duration(seconds: 3),
      ))!,
    );
    final container = ProviderContainer(
      overrides: [
        deviceServiceProvider.overrideWithValue(service),
        connectionStateProvider.overrideWith((_) => true),
        globalSettingsProvider.overrideWith((_) => global),
        cfwInfoProvider.overrideWith((_) => info),
      ],
    );

    addTearDown(container.dispose);

    const home = Key('home');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SonicMasterApp(home: SizedBox.expand(key: home)),
      ),
    );
    unawaited(
      showSonicDialog<void>(
        context: tester.element(find.byKey(home)),
        builder: (_) => const GlobalSettingsDialog(),
      ),
    );
    await _settle(tester, ms: 800);

    expect(find.text(info.version.replaceFirst('CFW', 'CFW ')), findsOneWidget);

    final dropdown = find.text(_themes[original]);

    await tester.ensureVisible(dropdown);
    await _settle(tester, ms: 400);
    await tester.tap(dropdown);
    await _settle(tester, ms: 600);
    await tester.tap(find.text(_themes[target]).last);
    await _settle(tester);

    final after = decodeCfwSettingsFrame(
      (await service.requestCfwSettings(timeout: const Duration(seconds: 3)))!,
    );

    expect(after?.theme, target, reason: 'the pedal did not take the theme');

    // 3. DSP load reads back in range.
    final dsp = await service.requestDspLoad(
      timeout: const Duration(seconds: 3),
    );

    // ignore: avoid_print
    print('DSP $dsp%');
    expect(dsp, inInclusiveRange(0, 100));

    // 4. Put the pedal's theme back.
    expect(
      await service.sendAndAwaitAck(
        CfwSettingWriter.setting(CfwSettingWriter.theme, original),
        timeout: const Duration(seconds: 2),
      ),
      isTrue,
    );

    final restored = decodeCfwSettingsFrame(
      (await service.requestCfwSettings(timeout: const Duration(seconds: 3)))!,
    );

    expect(restored?.theme, original, reason: 'theme not restored');
  });
}
