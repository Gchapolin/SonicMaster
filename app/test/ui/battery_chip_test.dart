import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/battery_status.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/ui/battery_chip.dart';

import '../support/sonic_host.dart';

BatteryStatus _status({
  BatteryCharge charge = BatteryCharge.onBattery,
  int bars = 3,
}) => BatteryStatus(
  flags: 1,
  millivolts: 3880,
  charge: charge,
  bars: bars,
  emptyMillivolts: 3540,
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    BatteryStatus? status, {
    bool isConnected = true,
  }) async {
    // A fresh ProviderScope: re-pumped overrides would keep the old state.
    await tester.pumpWidget(const SizedBox());
    await pumpSonicHost(
      tester,
      home: const Center(child: BatteryChip()),
      overrides: [
        connectionStateProvider.overrideWith((_) => isConnected),
        batteryProvider.overrideWith((_) => status),
      ],
    );
  }

  Icon icon(WidgetTester tester) => tester.widget<Icon>(find.byType(Icon));

  testWidgets('on battery: one glyph per bar count', (tester) async {
    for (final (bars, glyph) in const [
      (4, Icons.battery_full),
      (3, Icons.battery_5_bar),
      (2, Icons.battery_3_bar),
    ]) {
      await pump(tester, _status(bars: bars));
      expect(icon(tester).icon, glyph);
      expect(icon(tester).color, Palette.onSurfaceVariant);
    }
  });

  testWidgets('low and empty show in the alert color', (tester) async {
    await pump(tester, _status(bars: 1));
    expect(icon(tester).icon, Icons.battery_1_bar);
    expect(icon(tester).color, Palette.error);

    await pump(tester, _status(bars: 0));
    expect(icon(tester).icon, Icons.battery_alert);
    expect(icon(tester).color, Palette.error);
  });

  testWidgets('on USB: the charging glyph, labelled like the CFW app', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await pump(tester, _status(charge: BatteryCharge.charging, bars: 2));

    expect(icon(tester).icon, Icons.battery_charging_full);
    expect(find.bySemanticsLabel('Charging (USB power)'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('absent with no reading or when disconnected', (tester) async {
    await pump(tester, null);
    expect(find.byType(Icon), findsNothing);

    await pump(tester, _status(), isConnected: false);
    expect(find.byType(Icon), findsNothing);
  });
}
