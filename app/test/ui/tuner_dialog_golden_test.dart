import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/ui/preset_browser_page.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';
import 'package:sonicmaster/ui/tuner_dialog.dart';

import '../support/page_harness.dart';
import '../support/silent_transport.dart';

class _Pedal extends DeviceService {
  _Pedal() : super(SilentTransport());

  @override
  Future<void> sendFrame(String frameHex) async {}

  @override
  Future<String?> requestTunerReading({
    Duration timeout = const Duration(milliseconds: 400),
  }) async => buildSysexWriteFrame([
    0x12, 0x3f, 1, 0x03, 0, 2, //
    0, 0, 0x40, 0xc0, // -3.0 cents (float32 LE)
    0, 0, 0xdc, 0x42, // 110.0 Hz
    0xb8, 0x01, 0, 0, 0, 0,
  ]);
}

void main() {
  setUp(() => appLang = Lang.pt);
  tearDown(() => appLang = Lang.en);

  testWidgets('tuner dialog over the main screen, 1180x820', (tester) async {
    await pumpPage(
      tester,
      size: const Size(1180, 820),
      overrides: [deviceServiceProvider.overrideWithValue(_Pedal())],
    );

    unawaited(
      showSonicDialog<void>(
        context: tester.element(find.byType(PresetBrowserPage)),
        builder: (_) => const TunerDialog(),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/tuner_dialog_1180x820.png'),
    );
  });
}
