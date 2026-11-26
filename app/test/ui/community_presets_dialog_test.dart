import 'dart:convert';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
import 'package:sonicmaster/state/community_presets.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/ui/community_presets_dialog.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

import '../support/page_harness.dart';
import '../support/silent_transport.dart';
import '../support/sonic_host.dart';
import '../support/test_assets.dart';

final _catalog = jsonEncode({
  'type': 'sonicake-cfw-community-catalog',
  'schema': 1,
  'presets': [
    {
      'id': 'a',
      'name': 'CLNGilmour',
      'file': 'presets/a.json',
      'author': 'Usu',
      'genres': ['Ambient', 'Classic rock'],
      'description': 'Clean sound based on a Twin Reverb amp.',
      'guitar': 'Humbucker',
      'tuning': 'Standard',
      'controls': 'no STOMP',
    },
    {'id': 'b', 'name': 'DizzyHG', 'file': 'presets/b.json'},
  ],
});

String _presetFile(String amp) => jsonEncode({
  'version': '1.0',
  'ampMode': 'Normal',
  'modules': {
    'AMP': {'enabled': true, 'effect': amp, 'parameters': {}},
  },
});

class _Pedal extends DeviceService {
  _Pedal() : super(SilentTransport());

  @override
  Future<void> sendFrame(String frameHex) async {}

  @override
  Future<String?> requestStateDump({
    Duration timeout = const Duration(seconds: 1),
  }) async => null;
}

Future<String> _fetchAll(Uri u) async => switch (u.path.split('/').last) {
  'a.json' => _presetFile('Dark Twin'),
  'b.json' => _presetFile('Dizzy VH'),
  _ => _catalog,
};

void main() {
  final assets = loadTestDataAssets();

  Future<void> pump(
    WidgetTester tester, {
    bool isConnected = true,
    Future<String> Function(Uri)? fetch,
  }) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpSonicHost(
      tester,
      home: const CommunityPresetsDialog(),
      overrides: [
        dataAssetsProvider.overrideWith((_) => assets),
        connectionStateProvider.overrideWith((_) => isConnected),
        deviceServiceProvider.overrideWithValue(_Pedal()),
        communityFetchProvider.overrideWithValue(fetch ?? _fetchAll),
      ],
    );
    await tester.pumpAndSettle();
  }

  SonicButton button(WidgetTester tester, String label) =>
      tester.widget<SonicButton>(find.widgetWithText(SonicButton, label).first);

  testWidgets('lists the catalogue with its details', (tester) async {
    await pump(tester);

    expect(find.text('CLNGilmour'), findsOneWidget);
    expect(find.text('DizzyHG'), findsOneWidget);
    expect(find.text('Usu · Ambient, Classic rock'), findsOneWidget);
    expect(
      find.text('Clean sound based on a Twin Reverb amp.'),
      findsOneWidget,
    );
    expect(find.text('Humbucker · Standard · no STOMP'), findsOneWidget);
    expect(find.text('Try'), findsNWidgets(2));
    expect(find.text('Save to…'), findsNWidgets(2));
    expect(button(tester, 'Try').onPressed, isNotNull);
  });

  testWidgets('disconnected: Try and Save are off', (tester) async {
    await pump(tester, isConnected: false);

    expect(button(tester, 'Try').onPressed, isNull);
    expect(button(tester, 'Save to…').onPressed, isNull);
    expect(find.text('Connect a pedal to try a preset.'), findsOneWidget);
  });

  testWidgets('a failed catalogue download offers Retry', (tester) async {
    var calls = 0;

    await pump(
      tester,
      fetch: (_) async {
        calls++;
        if (calls == 1) throw Exception('offline');

        return _catalog;
      },
    );

    expect(find.textContaining('could not be read'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('CLNGilmour'), findsOneWidget);
  });

  testWidgets('the top bar opens it', (tester) async {
    await pumpPage(
      tester,
      size: const Size(820, 1180),
      overrides: [
        communityFetchProvider.overrideWithValue((_) async => _catalog),
      ],
    );

    await tester.tap(find.widgetWithIcon(SonicIconButton, Icons.public));
    await tester.pumpAndSettle();

    expect(find.byType(CommunityPresetsDialog), findsOneWidget);
  });

  testWidgets('each card shows its amp piece', (tester) async {
    await pump(tester);

    final pieces = tester
        .widgetList<GearPiece>(find.byType(GearPiece))
        .map((p) => p.model)
        .toList();

    expect(pieces, ['Dark Twin', 'Dizzy VH']);
    expect(find.text('Dark Twin'), findsOneWidget);
  });

  testWidgets('a preset whose file has no amp shows no thumbnail', (
    tester,
  ) async {
    await pump(
      tester,
      fetch: (u) async => u.path.endsWith('catalog.json')
          ? _catalog
          : throw Exception('offline'),
    );

    expect(find.byType(GearPiece), findsNothing);
    expect(find.text('CLNGilmour'), findsOneWidget);
  });

  testWidgets('Testar moves the on-pedal status to that preset', (
    tester,
  ) async {
    await pump(tester);

    const status = 'On the pedal. Save to keep it.';

    expect(find.text(status), findsNothing);

    await tester.tap(find.widgetWithText(SonicButton, 'Try').first);
    await tester.pumpAndSettle();

    double y(Finder f) => tester.getCenter(f).dy;

    expect(find.text(status), findsOneWidget);
    expect(y(find.text(status)), lessThan(y(find.text('DizzyHG'))));

    await tester.tap(find.widgetWithText(SonicButton, 'Try').last);
    await tester.pumpAndSettle();

    expect(find.text(status), findsOneWidget);
    expect(y(find.text(status)), greaterThan(y(find.text('DizzyHG'))));
  });
}
