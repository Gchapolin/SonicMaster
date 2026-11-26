import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonicmaster/device/device_model.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/connection_prefs.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/names_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/state/reconnect.dart';

import '../support/test_assets.dart';

void main() {
  testWidgets('the demo connects to a virtual CFW Pocket Master and leaves '
      'no trace when disconnected', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final prefs = ConnectionPrefs(await SharedPreferences.getInstance());
    final c = ProviderContainer(
      overrides: [
        connectionPrefsProvider.overrideWithValue(prefs),
        dataAssetsProvider.overrideWith((_) => loadTestDataAssets()),
      ],
    );

    addTearDown(c.dispose);

    late WidgetRef ref;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: Consumer(
          builder: (_, r, _) {
            ref = r;

            return const SizedBox();
          },
        ),
      ),
    );
    await tester.runAsync(() async {
      await c.read(dataAssetsProvider.future);
      await startDemo(ref);
      // connectAndSync fires the names, CFW, slot-name and scene reads
      // unawaited; wait for all of them so nothing outlives the test.
      await pendingConnectReads;
    });

    expect(c.read(demoModeProvider), isTrue);
    expect(c.read(connectionStateProvider), isTrue);
    expect(c.read(connectedDeviceNameProvider), contains('demo'));
    expect(c.read(detectedDeviceModelProvider), DeviceModel.pocketMaster);
    expect(c.read(globalSettingsProvider), isNotNull);
    expect(c.read(presetNamesProvider), isNotEmpty);
    expect(c.read(cfwInfoProvider)?.version, 'CFW1.0.2');
    expect(prefs.autoConnectProfile, isNull); // the demo is never auto-restored

    // The heartbeat's USB liveness probe must not drop the virtual pedal.
    await tester.runAsync(
      () => checkUsbLiveness(ref, probe: (_) async => false),
    );
    expect(c.read(connectionStateProvider), isTrue);

    await tester.runAsync(() => disconnectDevice(ref));

    expect(c.read(connectionStateProvider), isFalse);
    expect(c.read(demoModeProvider), isFalse);
  });
}
