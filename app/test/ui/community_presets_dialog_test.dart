import 'dart:convert';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/state/community_presets.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/ui/community_presets_dialog.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

import '../support/page_harness.dart';
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
        dataAssetsProvider.overrideWith((_) async => assets),
        connectionStateProvider.overrideWith((_) => isConnected),
        communityFetchProvider.overrideWithValue(
          fetch ?? (_) async => _catalog,
        ),
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
}
