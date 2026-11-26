import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/names_providers.dart';
import 'package:sonicmaster/ui/import_dialogs.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';
import 'package:sonicmaster/ui/user_slots_dialog.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/sonic_host.dart';
import '../support/test_assets.dart';

void main() {
  final assets = loadTestDataAssets();
  final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

  setUp(() => appLang = Lang.pt);
  tearDown(() => appLang = Lang.en);

  Future<BuildContext> pump(WidgetTester tester) async {
    final context = await pumpSonicHost(
      tester,
      size: const Size(820, 1180),
      home: const UserSlotsDialog(),
      overrides: [
        dataAssetsProvider.overrideWith((_) async => assets),
        connectionStateProvider.overrideWith((_) => true),
        cfwInfoProvider.overrideWith((_) => cfw),
        userNamesProvider.overrideWith(
          (_) => const {416: 'Jazz 2x12', 901: 'Satan 50'},
        ),
      ],
    );
    await tester.pumpAndSettle();

    return context;
  }

  Future<void> tapFirst(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  testWidgets('the slots dialog in Portuguese, without overflow', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Slots de IR do usuário e Clone'), findsOneWidget);
    expect(find.text('IR do usuário (cab)'), findsOneWidget);
    expect(find.text('Perfil do usuário (Clone)'), findsOneWidget);
    expect(find.text('Carregar…'), findsNWidgets(20));
    expect(find.text('Nome…'), findsNWidgets(20));
    expect(find.text('Limpar'), findsNWidgets(20));
    expect(find.text('Fechar'), findsOneWidget);
    expect(find.text('Jazz 2x12'), findsOneWidget); // names stay
    expect(tester.takeException(), isNull);
  });

  testWidgets('rename and clear dialogs in Portuguese', (tester) async {
    await pump(tester);

    await tapFirst(tester, 'Nome…');
    expect(find.text('Renomear IR do usuário 1'), findsOneWidget);
    expect(find.text('Renomear'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tapFirst(tester, 'Cancelar');

    await tapFirst(tester, 'Limpar');
    expect(find.text('Limpar IR do usuário 1?'), findsOneWidget);
    expect(
      find.text('Isso apaga a resposta ao impulso carregada.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tapFirst(tester, 'Cancelar');

    // The first Clone row's buttons come after the ten IR rows.
    await tester.tap(find.text('Nome…').at(10));
    await tester.pumpAndSettle();
    expect(find.text('Renomear Perfil do usuário 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('import dialogs in Portuguese', (tester) async {
    final context = await pump(tester);

    showSonicDialog<void>(
      context: context,
      builder: (_) =>
          const ImportProgressDialog(title: 'Importando para IR do usuário 1'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Preparando…'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(context, rootNavigator: true).pop();
    await tester.pumpAndSettle();

    showSonicDialog<void>(
      context: context,
      builder: (_) => const ImportErrorDialog(
        title: 'Falha ao importar',
        message: 'x',
        showSupportedFormats: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('FORMATOS SUPORTADOS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
