import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/battery_status.dart';

void main() {
  // `12 2D` as the pedal sent it on USB (capture session 6): 3880 mV,
  // charging, 2 bars, empty below 3540 mV.
  const onUsb = [0x12, 0x2D, 1, 0x01, 0x28, 0x0F, 1, 2, 5, 2, 0xD4, 0x0D];

  List<int> reply({
    int flags = 0x01,
    int mv = 3880,
    int charge = 0,
    int byte7 = 2,
    int bars = 2,
  }) => [
    0x12, 0x2D, 1, flags, mv & 0xFF, mv >> 8, charge, byte7, 5, bars, //
    0xD4, 0x0D,
  ];

  test('decodes the captured reply', () {
    final s = decodeBatteryReply(onUsb)!;

    expect(s.millivolts, 3880);
    expect(s.charge, BatteryCharge.charging);
    expect(s.bars, 2);
    expect(s.emptyMillivolts, 3540);
    expect(s.label, 'Charging (USB power)');
  });

  test('rejects a short, foreign or unknown-version reply', () {
    expect(decodeBatteryReply(onUsb.sublist(0, 11)), isNull);
    expect(decodeBatteryReply([0x12, 0x2B, ...onUsb.skip(2)]), isNull);
    expect(decodeBatteryReply([0x12, 0x2D, 0, ...onUsb.skip(3)]), isNull);
  });

  test('a pedal without a battery reading has no status', () {
    expect(decodeBatteryReply(reply(flags: 0)), isNull);
  });

  test('charge byte: 0 battery, 1 charging, 2 charged, other charging', () {
    expect(
      decodeBatteryReply(reply(charge: 0))!.charge,
      BatteryCharge.onBattery,
    );
    expect(decodeBatteryReply(reply(charge: 2))!.charge, BatteryCharge.charged);
    expect(
      decodeBatteryReply(reply(charge: 7))!.charge,
      BatteryCharge.charging,
    );
  });

  test('bars clamp to 4; byte 7 = 255 counts the voltage steps', () {
    expect(decodeBatteryReply(reply(bars: 9))!.bars, 4);
    expect(decodeBatteryReply(reply(byte7: 255, mv: 3500))!.bars, 0);
    expect(decodeBatteryReply(reply(byte7: 255, mv: 3700))!.bars, 2);
    expect(decodeBatteryReply(reply(byte7: 255, mv: 3950))!.bars, 4);
  });

  test('labels on battery follow the CFW app', () {
    expect(
      decodeBatteryReply(reply(bars: 3))!.label,
      'Battery: 3 of 4 · 3.88 V',
    );
    expect(
      decodeBatteryReply(reply(bars: 1))!.label,
      'Battery low: 1 of 4 · 3.88 V',
    );
    expect(
      decodeBatteryReply(reply(bars: 0))!.label,
      'Battery empty (below 3.54 V): charge the pedal',
    );
    expect(decodeBatteryReply(reply(flags: 0x05, bars: 3))!.isEmpty, isTrue);
    expect(
      decodeBatteryReply(reply(charge: 2))!.label,
      'Charged (on USB power)',
    );
    expect(
      decodeBatteryReply(reply(flags: 0x09, bars: 3))!.label,
      'Battery: 3 of 4 · 3.88 V · Batt Only: not charging from USB',
    );
  });
}
