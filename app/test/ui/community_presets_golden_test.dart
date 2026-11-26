import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/main.dart';
import 'package:sonicmaster/state/community_presets.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/ui/community_presets_dialog.dart';
import 'package:sonicmaster/ui/preset_browser_page.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

import '../support/page_harness.dart';
import '../support/silent_transport.dart';

class _Pedal extends DeviceService {
  _Pedal() : super(SilentTransport());

  @override
  Future<void> sendFrame(String frameHex) async {}

  @override
  Future<String?> requestStateDump({
    Duration timeout = const Duration(seconds: 1),
  }) async => null;
}

const _amps = {
  'a.json': 'Dark Twin',
  'b.json': 'Dizzy VH',
  'c.json': 'Tanger R100',
};

final _catalog = jsonEncode({
  'type': 'sonicake-cfw-community-catalog',
  'schema': 1,
  'presets': [
    {
      'id': 'a',
      'name': 'CLNGilmour',
      'file': 'a.json',
      'author': 'Usu (DrillKill666)',
      'genres': ['Ambient', 'Classic rock'],
      'description':
          'Clean sound based on a Twin Reverb amp with delay and reverb to '
          'create a big ambient sound.',
      'guitar': 'Humbucker guitar (Motherbucker), humbucker or split coil',
      'tuning': 'Standard',
      'controls':
          'Scene 1: compressor · Scene 2: compressor + chorus · no STOMP',
    },
    {
      'id': 'b',
      'name': 'DizzyHG',
      'file': 'b.json',
      'author': 'Usu (DrillKill666)',
      'genres': ['Metal (90s / modern)'],
      'description':
          'Very high gain sound based on a VH4 with overdrive, delay and '
          'reverb. Good for modern or 90s metal.',
    },
    {
      'id': 'c',
      'name': 'Tropicana',
      'file': 'c.json',
      'author': 'Mattia Bacca',
      'genres': ['Rock', 'Post-rock', 'Psychedelic', 'Ambient'],
      'description':
          'A refreshing, vitamin-rich tone for post-rock and psychedelic '
          'soundscapes. Built around the Orange Rockerverb 100 (Tanger R100).',
      'guitar': 'G4M Harlem headless, bridge Alnico 5 hot humbucker (demo)',
      'tuning': 'D Standard',
      'controls': 'STOMP: booster and delay on by default',
    },
  ],
});

Future<String> _fetch(Uri u) async {
  final amp = _amps[u.path.split('/').last];

  if (amp == null) return _catalog;

  return jsonEncode({
    'version': '1.0',
    'modules': {
      'AMP': {'enabled': true, 'effect': amp, 'parameters': {}},
    },
  });
}

void main() {
  setUp(() => appLang = Lang.pt);
  tearDown(() => appLang = Lang.en);

  testWidgets('community presets over the main screen, 1180x820', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1180, 820),
      overrides: [
        deviceServiceProvider.overrideWithValue(_Pedal()),
        communityFetchProvider.overrideWithValue(_fetch),
      ],
    );

    unawaited(
      showSonicDialog<void>(
        context: tester.element(find.byType(PresetBrowserPage)),
        builder: (_) => const CommunityPresetsDialog(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SonicButton, 'Testar').first);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SonicMasterApp),
      matchesGoldenFile('goldens/community_presets_1180x820.png'),
    );
  });
}
