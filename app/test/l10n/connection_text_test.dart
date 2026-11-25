import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/ui/device_dialog.dart';

import '../support/page_harness.dart';

/// Any rendered text equal to [s], whatever its case (labels are upper-cased).
Finder anyText(String s) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().toLowerCase() == s.toLowerCase(),
);

void main() {
  const ipad = Size(820, 1180);
  const phone = Size(852, 393);

  setUp(() => appLang = Lang.pt);
  tearDown(() => appLang = Lang.en);

  for (final (name, size) in [('iPad', ipad), ('phone', phone)]) {
    testWidgets('$name: Conectar opens the picker in Portuguese', (
      tester,
    ) async {
      await pumpPage(tester, size: size, isConnected: false);

      expect(tester.takeException(), isNull);

      await tester.tap(anyText('Conectar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // the dialog fade

      expect(anyText('Selecione um dispositivo'), findsOneWidget);
      expect(anyText('Buscar de novo'), findsOneWidget);
      expect(anyText('Cancelar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name, connected: Desconectar fits the top bar', (
      tester,
    ) async {
      await pumpPage(tester, size: size);

      expect(anyText('Desconectar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('browser support messages in Portuguese', () {
    expect(
      webMidiUnsupportedMessage(TargetPlatform.android),
      startsWith('O Web MIDI não está disponível'),
    );
    expect(
      webBluetoothUnsupportedMessage(TargetPlatform.iOS),
      startsWith('Nenhum navegador de iPhone ou iPad'),
    );
  });
}
