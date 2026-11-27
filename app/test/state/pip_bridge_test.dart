import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/model/preset_ref.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/names_providers.dart';
import 'package:sonicmaster/state/pip_bridge.dart';
import 'package:sonicmaster/state/preset_providers.dart';

import '../support/silent_transport.dart';
import '../support/test_assets.dart';

void main() {
  final assets = loadTestDataAssets();

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pipChannel, (call) async {
          calls.add(call);

          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pipChannel, null);
  });

  Future<ProviderContainer> pumpBridge(
    WidgetTester tester, {
    PresetRef? current = const PresetRef(.user, 7),
    bool isModified = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        deviceServiceProvider.overrideWith((ref) {
          final service = DeviceService(SilentTransport())..startListening();

          ref.onDispose(service.dispose);

          return service;
        }),
        dataAssetsProvider.overrideWith((_) => assets),
        currentPresetProvider.overrideWith((_) => current),
        presetModifiedProvider.overrideWith((_) => isModified),
        presetNamesProvider.overrideWith(
          (_) => {
            const PresetRef(.user, 6): 'Pure Clean',
            const PresetRef(.user, 7): 'Metal Riff',
            const PresetRef(.user, 8): 'Grunge',
          },
        ),
        connectionStateProvider.overrideWith((_) => true),
        connectedDeviceNameProvider.overrideWith((_) => 'Pocket Master'),
      ],
    );

    addTearDown(container.dispose);
    await container.read(dataAssetsProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: PipBridge(child: SizedBox()),
        ),
      ),
    );

    return container;
  }

  /// Sends [method] from the "native" side, as the PiP skip buttons do.
  Future<void> fromNative(WidgetTester tester, String method) =>
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        pipChannel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
        (_) {},
      );

  Map<Object?, Object?> lastUpdate() =>
      calls.lastWhere((c) => c.method == 'update').arguments
          as Map<Object?, Object?>;

  group('PresetRef.neighbour', () {
    test('steps within the bank and wraps at both ends', () {
      expect(
        const PresetRef(.user, 7).neighbour(1),
        const PresetRef(.user, 8),
      );
      expect(
        const PresetRef(.user, 7).neighbour(-1),
        const PresetRef(.user, 6),
      );
      expect(
        const PresetRef(.user, 50).neighbour(1),
        const PresetRef(.user, 1),
      );
      expect(
        const PresetRef(.factory, 1).neighbour(-1),
        const PresetRef(.factory, 50),
      );
    });
  });

  group('on iOS', () {
    final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

    testWidgets('enables PiP and sends the current preset', (tester) async {
      await pumpBridge(tester);

      expect(calls.first.method, 'setEnabled');
      expect(calls.first.arguments, isTrue);
      expect(lastUpdate()['label'], 'P07');
      expect(lastUpdate()['name'], 'Metal Riff');
      expect(lastUpdate()['device'], 'Pocket Master');
      expect(lastUpdate()['connected'], isTrue);
      expect(lastUpdate()['modified'], isFalse);
    }, variant: ios);

    testWidgets('sends the presets the skip buttons go to', (tester) async {
      await pumpBridge(tester);

      expect(lastUpdate()['prevLabel'], 'P06');
      expect(lastUpdate()['prevName'], 'Pure Clean');
      expect(lastUpdate()['nextLabel'], 'P08');
      expect(lastUpdate()['nextName'], 'Grunge');
    }, variant: ios);

    testWidgets('with no current preset, next is P01 and there is no previous', (
      tester,
    ) async {
      await pumpBridge(tester, current: null);

      expect(lastUpdate()['prevLabel'], '');
      expect(lastUpdate()['nextLabel'], 'P01');
    }, variant: ios);

    testWidgets('sends an update when the preset changes', (tester) async {
      final c = await pumpBridge(tester);

      c.read(currentPresetProvider.notifier).state = const PresetRef(.user, 8);
      c.read(presetModifiedProvider.notifier).state = true;
      await tester.pump();

      expect(lastUpdate()['label'], 'P08');
      expect(lastUpdate()['name'], 'Grunge');
      expect(lastUpdate()['modified'], isTrue);
    }, variant: ios);

    testWidgets('next loads the next preset, with no unsaved-changes dialog', (
      tester,
    ) async {
      final c = await pumpBridge(tester, isModified: true);

      await fromNative(tester, 'next');
      await tester.pump();

      expect(c.read(presetLoadingProvider), isTrue);
      expect(find.text('Discard'), findsNothing);

      await pumpPastAckTimeout(tester);

      expect(c.read(presetLoadStatusProvider), 'P08: no ACK (timeout)');
    }, variant: ios);

    testWidgets('previous loads the previous preset', (tester) async {
      final c = await pumpBridge(tester);

      await fromNative(tester, 'previous');
      await tester.pump();
      await pumpPastAckTimeout(tester);

      expect(c.read(presetLoadStatusProvider), 'P06: no ACK (timeout)');
    }, variant: ios);

    testWidgets('with no current preset, a skip loads P01', (tester) async {
      final c = await pumpBridge(tester, current: null);

      expect(lastUpdate()['label'], '--');

      await fromNative(tester, 'previous');
      await tester.pump();
      await pumpPastAckTimeout(tester);

      expect(c.read(presetLoadStatusProvider), 'P01: no ACK (timeout)');
    }, variant: ios);
  });

  testWidgets('off iOS it never touches the channel', (tester) async {
    await pumpBridge(tester);

    expect(calls, isEmpty);
  });
}
