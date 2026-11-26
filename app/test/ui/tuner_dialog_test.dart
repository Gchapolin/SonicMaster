import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/cfw_tuner_codec.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';
import 'package:sonicmaster/ui/top_bar.dart';
import 'package:sonicmaster/ui/tuner_dialog.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';
import '../support/silent_transport.dart';
import '../support/sonic_host.dart';
import '../support/text_fit.dart';
import '../support/view_helpers.dart';

List<int> _f32(double v) =>
    (ByteData(4)..setFloat32(0, v, Endian.little)).buffer.asUint8List();

String _reading({
  int flags = 0x03,
  int note = 0,
  int octave = 2,
  double cents = 0,
  double hz = 110,
  int a4 = 440,
}) => buildSysexWriteFrame([
  0x12, 0x3f, 1, flags, note, octave, //
  ..._f32(cents), ..._f32(hz), a4 & 0xff, a4 >> 8, 0, 0, 0, 0,
]);

final _silent = _reading(flags: 0x15, note: 0xff, octave: 0x7f, hz: 32.6);

/// A CFW pedal whose tuner answers [reading]; records what it is sent.
class _TunerPedal extends DeviceService {
  _TunerPedal(this.reading) : super(SilentTransport());

  String? reading;
  final sent = <String>[];
  var reads = 0;

  @override
  Future<void> sendFrame(String frameHex) async => sent.add(frameHex);

  @override
  Future<String?> requestTunerReading({
    Duration timeout = const Duration(milliseconds: 400),
  }) async {
    reads++;

    return reading;
  }
}

void main() {
  Future<_TunerPedal> open(
    WidgetTester tester, {
    String? reading,
    Size size = const Size(1280, 800),
  }) async {
    final pedal = _TunerPedal(reading);
    final context = await pumpSonicHost(
      tester,
      size: size,
      overrides: [deviceServiceProvider.overrideWithValue(pedal)],
    );

    unawaited(
      showSonicDialog<void>(
        context: context,
        builder: (_) => const TunerDialog(),
      ),
    );
    await tester.pump();
    await tester.pump(TunerDialog.pollEvery * 2);

    return pedal;
  }

  testWidgets('opening it opens the pedal\'s tuner and starts reading', (
    tester,
  ) async {
    final pedal = await open(tester, reading: _silent);

    expect(pedal.sent, [tunerOpenFrame(isOpen: true)]);
    expect(pedal.reads, greaterThan(0));
    expect(find.text('Play a string'), findsOneWidget);
  });

  testWidgets('with no answer yet it says it is opening', (tester) async {
    await open(tester);

    expect(find.text('Opening the pedal\'s tuner…'), findsOneWidget);
  });

  testWidgets('a flat note shows note, octave, cents and Hz', (tester) async {
    await open(tester, reading: _reading(cents: -4.5, hz: 109.71));

    expect(find.text('A'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('109.7 Hz · -4.5 cents'), findsOneWidget);
    expect(find.text('FLAT'), findsOneWidget);
  });

  testWidgets('sharp, and in tune within 5 cents', (tester) async {
    final pedal = await open(tester, reading: _reading(cents: 12, note: 7));

    expect(find.text('E'), findsOneWidget);
    expect(find.text('110.0 Hz · +12.0 cents'), findsOneWidget);
    expect(find.text('SHARP'), findsOneWidget);

    pedal.reading = _reading(cents: 4.9, note: 7);
    await tester.pump(TunerDialog.pollEvery * 2);

    expect(find.text('IN TUNE'), findsOneWidget);
  });

  testWidgets('mute switch', (tester) async {
    final pedal = await open(tester, reading: _silent);

    expect(tester.widget<SonicToggle>(find.byType(SonicToggle)).value, false);

    await tester.tap(find.byType(SonicToggle));
    await tester.pump();

    expect(pedal.sent.last, tunerOutputFrame(isMuted: true));

    pedal.reading = _reading(note: 0xff, octave: 0x7f);
    await tester.pump(TunerDialog.pollEvery * 2);

    expect(tester.widget<SonicToggle>(find.byType(SonicToggle)).value, true);

    await tester.tap(find.byType(SonicToggle));
    await tester.pump();

    expect(pedal.sent.last, tunerOutputFrame(isMuted: false));
  });

  test('the needle follows the cents', () {
    expect(tunerNeedleAngle(-50), closeTo(-60 * pi / 180, 1e-9));
    expect(tunerNeedleAngle(0), 0);
    expect(tunerNeedleAngle(25), closeTo(30 * pi / 180, 1e-9));
    expect(tunerNeedleAngle(50), closeTo(60 * pi / 180, 1e-9));
    expect(tunerNeedleAngle(80), closeTo(60 * pi / 180, 1e-9));
  });

  testWidgets('the gauge is given the pedal\'s cents', (tester) async {
    await open(tester, reading: _reading(cents: -12));

    expect(tester.widget<TunerGauge>(find.byType(TunerGauge)).cents, -12);
  });

  testWidgets('in tune within 5 cents turns the note green', (tester) async {
    final pedal = await open(tester, reading: _reading(cents: -3));

    Color noteColor() => tester.widget<Text>(find.text('A')).style!.color!;

    expect(noteColor(), Palette.ok);

    pedal.reading = _reading(cents: -8);
    await tester.pump(TunerDialog.pollEvery * 2);

    expect(noteColor(), Palette.onSurface);
  });

  testWidgets('the A4 picker sets the reference pitch', (tester) async {
    final pedal = await open(tester, reading: _silent);

    await tester.tap(find.text('440 Hz'));
    await tester.pump();
    await tester.ensureVisible(find.text('441 Hz').last);
    await tester.pump();
    await tester.tap(find.text('441 Hz').last);
    await tester.pump();

    expect(pedal.sent.last, tunerA4Frame(441));
  });

  testWidgets('the A4 dropdown shows its whole value', (tester) async {
    await open(tester, reading: _silent);

    expectNoTruncatedText(
      tester,
      find.ancestor(
        of: find.text('440 Hz'),
        matching: find.byType(SonicDropdown<int>),
      ),
    );
  });

  testWidgets('the pedal\'s own A4 and mute state are shown', (tester) async {
    await open(
      tester,
      reading: _reading(flags: 0x0d, note: 0xff, octave: 0x7f, a4: 442),
    );

    expect(find.text('442 Hz'), findsOneWidget);
  });

  testWidgets('closing it closes the pedal\'s tuner and stops reading', (
    tester,
  ) async {
    final pedal = await open(tester, reading: _silent);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    final reads = pedal.reads;

    await tester.pump(TunerDialog.pollEvery * 5);

    expect(pedal.sent.last, tunerOpenFrame(isOpen: false));
    expect(pedal.reads, reads);
    expect(find.byType(TunerDialog), findsNothing);
  });

  testWidgets('a lost connection closes the dialog', (tester) async {
    await open(tester, reading: _silent);

    final c = ProviderScope.containerOf(
      tester.element(find.byType(TunerDialog)),
    );

    c.read(connectionStateProvider.notifier).state = true;
    await tester.pump();
    c.read(connectionStateProvider.notifier).state = false;
    await tester.pumpAndSettle();

    expect(find.byType(TunerDialog), findsNothing);
  });

  testWidgets('a pedal that reports its tuner closed is asked to open again', (
    tester,
  ) async {
    final pedal = await open(tester, reading: _reading(flags: 0x10));

    expect(
      pedal.sent.where((f) => f == tunerOpenFrame(isOpen: true)).length,
      greaterThan(1),
    );
  });

  testWidgets('phone: the tuner fits', (tester) async {
    await open(
      tester,
      size: const Size(956, 440),
      reading: _reading(cents: -4.5),
    );

    expectNoOverflow(tester);
  });

  group('top bar', () {
    final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;
    Finder inBar(Finder f) =>
        find.descendant(of: find.byType(TopBar), matching: f);

    testWidgets('stock firmware has no tuner button', (tester) async {
      await pumpPage(tester, size: const Size(1280, 800));

      expect(inBar(find.byIcon(Icons.music_note)), findsNothing);
    });

    testWidgets('a CFW pedal has one, and it opens the tuner', (tester) async {
      await pumpPage(
        tester,
        size: const Size(1280, 800),
        overrides: [cfwInfoProvider.overrideWith((_) => cfw)],
      );
      await tester.tap(inBar(find.byIcon(Icons.music_note)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TunerDialog), findsOneWidget);

      // The harness pedal never answers: close and run out the last read
      // (400 ms), staying short of the page's own heartbeat.
      await tester.tap(find.text('Close'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(TunerDialog), findsNothing);
    });

    testWidgets('phone: the bar still fits with the tuner button', (
      tester,
    ) async {
      await pumpPage(
        tester,
        size: const Size(956, 440),
        overrides: [cfwInfoProvider.overrideWith((_) => cfw)],
      );

      expectNoOverflow(tester);
    });
  });

  group('in Portuguese', () {
    setUp(() => appLang = Lang.pt);
    tearDown(() => appLang = Lang.en);

    testWidgets('820x1180: the tuner reads in Portuguese', (tester) async {
      await open(
        tester,
        reading: _reading(cents: -4.5, hz: 109.71),
        size: const Size(820, 1180),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Afinador'), findsOneWidget);
      expect(find.text('BAIXO'), findsOneWidget);
      expect(find.text('Mudo'), findsOneWidget);
      expect(find.text('Fechar'), findsOneWidget);
    });
  });
}
