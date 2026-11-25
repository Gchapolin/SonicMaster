import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/model/preset_ref.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/layout_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/ui/top_bar.dart';

import '../support/page_harness.dart';
import '../support/silent_transport.dart';
import '../support/test_assets.dart';
import '../support/view_helpers.dart';

const _phone = Size(956, 440);

void main() {
  final commands = loadTestDataAssets().commands;

  Finder inBar(Finder f) =>
      find.descendant(of: find.byType(TopBar), matching: f);
  final previous = inBar(find.byIcon(Icons.chevron_left));
  final next = inBar(find.byIcon(Icons.chevron_right));

  Future<(ProviderContainer, SilentTransport)> pump(
    WidgetTester tester, {
    Size size = _phone,
    PresetRef current = const PresetRef(.user, 5),
    bool isConnected = true,
    List<Override> extra = const [],
  }) async {
    final transport = SilentTransport();
    final c = await pumpPage(
      tester,
      size: size,
      current: current,
      isConnected: isConnected,
      names: {current: 'Clean'},
      overrides: [
        deviceServiceProvider.overrideWith((ref) {
          final service = DeviceService(transport)..startListening();

          ref.onDispose(service.dispose);

          return service;
        }),
        ...extra,
      ],
    );

    return (c, transport);
  }

  String select(PresetRef p) =>
      commands.presetSelect(p.bank, p.number)!.toLowerCase();

  List<String> sent(SilentTransport t) => [
    for (final f in t.sentFrames) f.toLowerCase(),
  ];

  testWidgets('the tablet and desktop bar has no arrows', (tester) async {
    await pump(tester, size: const Size(1280, 800));

    expect(previous, findsNothing);
    expect(next, findsNothing);
  });

  testWidgets('the phone bar steps to the next and the previous preset', (
    tester,
  ) async {
    final (_, transport) = await pump(tester);

    await tester.tap(next);
    await tester.pump();
    expect(sent(transport), contains(select(const PresetRef(.user, 6))));
    await pumpPastAckTimeout(tester);

    await tester.tap(previous);
    await tester.pump();
    expect(sent(transport), contains(select(const PresetRef(.user, 4))));
    await pumpPastAckTimeout(tester);
  });

  testWidgets('stepping wraps inside the bank', (tester) async {
    final (_, transport) = await pump(
      tester,
      current: const PresetRef(.factory, 50),
    );

    await tester.tap(next);
    await tester.pump();
    expect(sent(transport), contains(select(const PresetRef(.factory, 1))));
    await pumpPastAckTimeout(tester);
  });

  testWidgets('P01 steps back to P50', (tester) async {
    final (_, transport) = await pump(
      tester,
      current: const PresetRef(.user, 1),
    );

    await tester.tap(previous);
    await tester.pump();
    expect(sent(transport), contains(select(const PresetRef(.user, 50))));
    await pumpPastAckTimeout(tester);
  });

  testWidgets('unsaved edits are asked about before stepping', (tester) async {
    final (_, transport) = await pump(
      tester,
      extra: [presetModifiedProvider.overrideWith((_) => true)],
    );

    await tester.tap(next);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    expect(sent(transport), isNot(contains(select(const PresetRef(.user, 6)))));
  });

  testWidgets('tapping the preset name opens the preset list', (tester) async {
    final (c, _) = await pump(tester);

    expect(c.read(presetDrawerOpenProvider), isFalse);
    await tester.tap(inBar(find.text('Clean')));
    await tester.pump();

    expect(c.read(presetDrawerOpenProvider), isTrue);
  });

  testWidgets('no arrows while disconnected, none active while loading', (
    tester,
  ) async {
    await pump(tester, isConnected: false);
    expect(next, findsNothing);

    final (_, transport) = await pump(
      tester,
      extra: [presetLoadingProvider.overrideWith((_) => true)],
    );

    await tester.tap(next);
    await tester.pump();
    expect(sent(transport), isEmpty);
  });

  testWidgets('the narrowest phone bar still fits with a long name', (
    tester,
  ) async {
    final transport = SilentTransport();

    await pumpPage(
      tester,
      size: const Size(568, 320),
      names: {const PresetRef(.user, 1): 'WWWWWWWWWW'},
      selectedEffects: const {},
      overrides: [
        deviceServiceProvider.overrideWith((ref) {
          final service = DeviceService(transport)..startListening();

          ref.onDispose(service.dispose);

          return service;
        }),
      ],
    );

    expectNoOverflow(tester);
    expect(next, findsOneWidget);
    expect(
      tester.getRect(next).right,
      lessThanOrEqualTo(tester.getRect(inBar(find.byIcon(Icons.tune))).left),
    );
  });
}
