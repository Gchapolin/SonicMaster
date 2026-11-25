import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/model/battery_status.dart';
import 'package:sonicmaster/state/edit_providers.dart';

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

  // AMP: knobs, Clone Mode and the foot-switch cell.
  Future<void> pumpAmp(WidgetTester tester, Size size) => pumpPage(
    tester,
    size: size,
    selectedEffects: const {3: 307},
    parameters: const {3: {}},
    overrides: [selectedModuleProvider.overrideWith((_) => 3)],
  );

  for (final (name, size) in [('iPad', ipad), ('phone', phone)]) {
    testWidgets('$name, disconnected: Portuguese empty state, no overflow', (
      tester,
    ) async {
      await pumpPage(tester, size: size, isConnected: false);

      expect(anyText('Nenhuma pedaleira conectada'), findsOneWidget);
      expect(anyText('Testar demo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name, AMP editor: Portuguese labels, no overflow', (
      tester,
    ) async {
      await pumpAmp(tester, size);

      expect(anyText('Modo Clone'), findsOneWidget);
      expect(anyText('Footswitch'), findsOneWidget);
      expect(anyText('Nenhum'), findsOneWidget);
      expect(anyText('FS1'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('iPad: the rail is in Portuguese', (tester) async {
    await pumpAmp(tester, ipad);

    expect(anyText('Fábrica'), findsOneWidget);
    expect(anyText('Usuário'), findsOneWidget);
    expect(anyText('Buscar presets'), findsOneWidget);
    expect(anyText('Volume geral'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('battery labels in Portuguese', () {
    const status = BatteryStatus(
      flags: 0x09,
      millivolts: 3700,
      charge: BatteryCharge.onBattery,
      bars: 2,
      emptyMillivolts: 3400,
    );

    expect(
      status.label,
      'Bateria: 2 de 4 · 3.70 V · Batt Only: sem carga pela USB',
    );
  });
}
