import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/l10n/presets_text.dart';
import 'package:sonicmaster/state/community_presets.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/ui/community_presets_dialog.dart';
import 'package:sonicmaster/ui/save_preset_dialog.dart';
import 'package:sonicmaster/ui/unsaved_changes_dialog.dart';

import '../support/sonic_host.dart';
import '../support/test_assets.dart';

final _catalog = jsonEncode({
  'type': 'sonicake-cfw-community-catalog',
  'schema': 1,
  'presets': [
    {'id': 'a', 'name': 'CLNGilmour', 'file': 'presets/a.json'},
  ],
});

void main() {
  final assets = loadTestDataAssets();

  setUp(() => appLang = Lang.pt);
  tearDown(() => appLang = Lang.en);

  Future<BuildContext> pump(
    WidgetTester tester, {
    Widget home = const SizedBox.shrink(),
    bool isConnected = true,
  }) async {
    final context = await pumpSonicHost(
      tester,
      size: const Size(820, 1180),
      home: home,
      overrides: [
        dataAssetsProvider.overrideWith((_) async => assets),
        connectionStateProvider.overrideWith((_) => isConnected),
        communityFetchProvider.overrideWithValue((_) async => _catalog),
      ],
    );
    await tester.pumpAndSettle();

    return context;
  }

  testWidgets('community presets in Portuguese, without overflow', (
    tester,
  ) async {
    await pump(tester, home: const CommunityPresetsDialog());

    expect(find.text('Presets da comunidade'), findsOneWidget);
    expect(find.text('Testar'), findsOneWidget);
    expect(find.text('Salvar em…'), findsOneWidget);
    expect(find.text('Fechar'), findsOneWidget);
    expect(find.text('CLNGilmour'), findsOneWidget); // names stay
    expect(tester.takeException(), isNull);
  });

  testWidgets('disconnected: asks for a pedal in Portuguese', (tester) async {
    await pump(
      tester,
      home: const CommunityPresetsDialog(),
      isConnected: false,
    );

    expect(
      find.text('Conecte uma pedaleira para testar um preset.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('save preset dialog in Portuguese', (tester) async {
    final context = await pump(tester);

    showSavePresetDialog(context, name: 'Clean');
    await tester.pumpAndSettle();

    expect(find.text('Salvar preset'), findsOneWidget);
    expect(find.text('NOME DO PRESET'), findsOneWidget);
    expect(find.text('Máximo de 10 caracteres.'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsaved changes dialog in Portuguese', (tester) async {
    final context = await pump(tester);

    showUnsavedChangesDialog(context);
    await tester.pumpAndSettle();

    expect(find.text('Descartar alterações não salvas?'), findsOneWidget);
    expect(find.text('Descartar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('status messages in Portuguese', () {
    final t = PresetsText.current;

    expect(t.imported(0, 0), 'importado');
    expect(t.imported(2, 1), 'importado, 2 ignorado(s) (1 aviso(s))');
    expect(t.savedTo('Clean', 'U03'), '"Clean" salvo em U03');
    expect(t.onThePedal, 'Na pedaleira. Salve para manter.');
  });
}
