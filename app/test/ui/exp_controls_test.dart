import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/model/cfw_exp.dart';
import 'package:sonicmaster/protocol/cfw_exp_codec.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/ui/exp_controls.dart';
import 'package:sonicmaster/ui/module_editor.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';
import '../support/silent_transport.dart';
import '../support/view_helpers.dart';

void main() {
  final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;
  const nrThre = ExpAssign(module: 0, algId: 0, max: 35);

  Future<(ProviderContainer, SilentTransport)> pump(
    WidgetTester tester, {
    bool isCfw = true,
    List<ExpAssign?> slots = const [null, null, null, null],
    Size size = const Size(1280, 800),
  }) async {
    final transport = SilentTransport();
    final c = await pumpPage(
      tester,
      size: size,
      overrides: [
        deviceServiceProvider.overrideWith((ref) {
          final service = DeviceService(transport)..startListening();

          ref.onDispose(service.dispose);

          return service;
        }),
        cfwInfoProvider.overrideWith((_) => isCfw ? cfw : null),
        expAssignsProvider.overrideWith((_) => slots),
      ],
    );

    return (c, transport);
  }

  Finder inExp(Finder f) =>
      find.descendant(of: find.byType(ExpControls), matching: f);

  Future<void> pick(WidgetTester tester, String from, String to) async {
    await tester.tap(inExp(find.text(from)));
    await tester.pump();
    await tester.ensureVisible(find.text(to).last);
    await tester.pump();
    await tester.tap(find.text(to).last);
    await tester.pump();
  }

  List<String> sent(SilentTransport t) => [
    for (final f in t.sentFrames) f.toLowerCase(),
  ];

  testWidgets('stock firmware: no EXP controls', (tester) async {
    await pump(tester, isCfw: false);

    expect(
      find.descendant(
        of: find.byType(ModuleEditor),
        matching: find.text('EXP'),
      ),
      findsNothing,
    );
  });

  testWidgets('a free slot shows only the slot and the target pickers', (
    tester,
  ) async {
    await pump(tester);

    expect(inExp(find.text('EXP')), findsOneWidget);
    expect(inExp(find.text('A')), findsOneWidget);
    expect(inExp(find.text('None')), findsOneWidget);
    expect(inExp(find.text('MOMENT')), findsNothing);
  });

  testWidgets('a slot on this module shows its knob, mode and range', (
    tester,
  ) async {
    await pump(tester, slots: const [nrThre, null, null, null]);

    expect(inExp(find.text('THRE')), findsOneWidget);
    expect(inExp(find.text('CONT')), findsOneWidget);
    expect(inExp(find.text('0 %')), findsOneWidget);
    expect(inExp(find.text('35 %')), findsOneWidget);
  });

  testWidgets('the editor opens on the slot that drives this module', (
    tester,
  ) async {
    await pump(tester, slots: const [null, null, nrThre, null]);

    expect(inExp(find.text('C')), findsOneWidget);
    expect(inExp(find.text('THRE')), findsOneWidget);
  });

  testWidgets('a slot on another module names that module', (tester) async {
    await pump(
      tester,
      slots: const [ExpAssign(module: 3, algId: 0), null, null, null],
    );

    expect(inExp(find.text('AMP')), findsOneWidget);
    expect(inExp(find.text('CONT')), findsNothing);
  });

  testWidgets('picking a knob assigns the slot over its whole range', (
    tester,
  ) async {
    final (c, transport) = await pump(tester);

    await pick(tester, 'None', 'THRE');

    const expected = [ExpAssign(module: 0, algId: 0), null, null, null];

    expect(c.read(expAssignsProvider), expected);
    expect(sent(transport), [buildExpFrame(expected).toLowerCase()]);
  });

  testWidgets('None frees the slot', (tester) async {
    final (c, transport) = await pump(
      tester,
      slots: const [nrThre, null, null, null],
    );

    await pick(tester, 'THRE', 'None');

    expect(c.read(expAssignsProvider), const [null, null, null, null]);
    expect(sent(transport), [
      buildExpFrame(const [null, null, null, null]).toLowerCase(),
    ]);
  });

  testWidgets('mode and range changes keep the target', (tester) async {
    final (c, _) = await pump(tester, slots: const [nrThre, null, null, null]);

    await tester.tap(inExp(find.text('TOGGLE')));
    await tester.pump();
    await pick(tester, '35 %', '40 %');

    expect(
      c.read(expAssignsProvider).first,
      const ExpAssign(module: 0, algId: 0, mode: ExpAssign.toggle, max: 40),
    );
  });

  testWidgets('another slot can be picked and assigned', (tester) async {
    final (c, _) = await pump(tester, slots: const [nrThre, null, null, null]);

    await pick(tester, 'A', 'B');
    expect(inExp(find.text('None')), findsOneWidget);

    await pick(tester, 'None', 'THRE');

    expect(c.read(expAssignsProvider), const [
      nrThre,
      ExpAssign(module: 0, algId: 0),
      null,
      null,
    ]);
  });

  testWidgets('phone: the EXP controls fit', (tester) async {
    await pump(
      tester,
      size: const Size(956, 440),
      slots: const [nrThre, null, null, null],
    );

    expectNoOverflow(tester);
  });
}
