import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/model/cfw_exp.dart';
import 'package:sonicmaster/protocol/cfw_exp_codec.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/silent_transport.dart';

const _nrThre = ExpAssign(module: 0, algId: 0, max: 35);

/// A pedal that answers the EXP read with [reply] and records what it is sent.
class _FakePedal extends DeviceService {
  _FakePedal(this.reply) : super(SilentTransport());

  final String? reply;
  final sentFrames = <String>[];
  var expReads = 0;

  @override
  Future<void> sendFrame(String frameHex) async => sentFrames.add(frameHex);

  @override
  Future<String?> requestExpAssigns({
    Duration timeout = const Duration(seconds: 1),
  }) async {
    expReads++;

    return reply;
  }

  @override
  Future<String?> requestSceneRecords({
    Duration timeout = const Duration(seconds: 1),
  }) async => null;

  @override
  Future<String?> requestCurrentScene({
    Duration timeout = const Duration(seconds: 1),
  }) async => null;
}

final _reply = buildSysexWriteFrame([
  0x12, 0x3d, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x23, 0x00, //
  for (var i = 0; i < 3; i++) ...[0xff, 0, 0, 0, 0, 0],
]);

Future<(WidgetRef, ProviderContainer, _FakePedal)> _pedal(
  WidgetTester tester, {
  bool isCfw = true,
  String? reply,
}) async {
  final fake = _FakePedal(reply);
  final c = ProviderContainer(
    overrides: [deviceServiceProvider.overrideWithValue(fake)],
  );

  addTearDown(c.dispose);
  if (isCfw) {
    c.read(cfwInfoProvider.notifier).state = decodeCfwSettingsFrame(
      cfwSettingsOriginal,
    );
  }

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

  return (ref, c, fake);
}

void main() {
  testWidgets('the preset\'s EXP slots are read with its scenes', (
    tester,
  ) async {
    final (ref, c, _) = await _pedal(tester, reply: _reply);

    await tester.runAsync(() => refreshScenes(ref));

    expect(c.read(expAssignsProvider), const [_nrThre, null, null, null]);
  });

  testWidgets('a missed read keeps the slots', (tester) async {
    final (ref, c, _) = await _pedal(tester);

    c.read(expAssignsProvider.notifier).state = const [
      null,
      _nrThre,
      null,
      null,
    ];
    await tester.runAsync(() => refreshScenes(ref));

    expect(c.read(expAssignsProvider)[1], _nrThre);
  });

  testWidgets('stock firmware is never asked', (tester) async {
    final (ref, c, fake) = await _pedal(tester, isCfw: false, reply: _reply);

    await tester.runAsync(() => refreshScenes(ref));
    await tester.runAsync(() => setExpAssign(ref, 0, _nrThre));

    expect(fake.expReads, 0);
    expect(fake.sentFrames, isEmpty);
    expect(c.read(expAssignsProvider), const [null, null, null, null]);
  });

  testWidgets('assigning a slot sends all four and marks the preset edited', (
    tester,
  ) async {
    final (ref, c, fake) = await _pedal(tester, reply: _reply);

    await tester.runAsync(() => refreshScenes(ref));

    const amp = ExpAssign(module: 3, algId: 1, mode: ExpAssign.toggle);

    await tester.runAsync(() => setExpAssign(ref, 2, amp));

    expect(c.read(expAssignsProvider), const [_nrThre, null, amp, null]);
    expect(fake.sentFrames, [
      buildExpFrame(const [_nrThre, null, amp, null]),
    ]);
    expect(c.read(presetModifiedProvider), isTrue);
  });

  testWidgets('freeing a slot sends FF for it', (tester) async {
    final (ref, c, fake) = await _pedal(tester, reply: _reply);

    await tester.runAsync(() => refreshScenes(ref));
    await tester.runAsync(() => setExpAssign(ref, 0, null));

    expect(c.read(expAssignsProvider), const [null, null, null, null]);
    expect(
      fake.sentFrames.single,
      buildExpFrame(const [null, null, null, null]),
    );
  });

  testWidgets('after a missed read, an edit reads the pedal first', (
    tester,
  ) async {
    // The load-time read was missed: the app shows four free slots while the
    // pedal still holds EXP A.
    final (ref, c, fake) = await _pedal(tester, reply: _reply);

    const amp = ExpAssign(module: 3, algId: 1);

    await tester.runAsync(() => setExpAssign(ref, 1, amp));

    expect(fake.expReads, 1);
    expect(c.read(expAssignsProvider), const [_nrThre, amp, null, null]);
    expect(
      fake.sentFrames.single,
      buildExpFrame(const [_nrThre, amp, null, null]),
    );
  });

  testWidgets('with the pedal\'s slots unknown, nothing is written', (
    tester,
  ) async {
    final (ref, c, fake) = await _pedal(tester);

    await tester.runAsync(
      () => setExpAssign(ref, 1, const ExpAssign(module: 3, algId: 1)),
    );

    expect(fake.sentFrames, isEmpty);
    expect(c.read(expAssignsProvider), const [null, null, null, null]);
  });

  testWidgets('a new preset or connection drops the slots', (tester) async {
    final (ref, c, _) = await _pedal(tester, reply: _reply);

    await tester.runAsync(() => refreshScenes(ref));
    clearSceneState(ref);

    expect(c.read(expAssignsProvider), const [null, null, null, null]);
  });
}
