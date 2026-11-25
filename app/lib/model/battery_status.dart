import '../l10n/shell_text.dart';

/// Where the CFW pedal's power comes from (byte 6 of `12 2D`).
enum BatteryCharge { onBattery, charging, charged }

/// The CFW pedal's battery (register 0x2D, docs/cfw-protocol/capture-notes.md,
/// capture session 6), read the way the CFW app reads it.
class BatteryStatus {
  const BatteryStatus({
    required this.flags,
    required this.millivolts,
    required this.charge,
    required this.bars,
    required this.emptyMillivolts,
  });

  /// bit0 battery reading present, bit2 empty, bit3 not charging from USB.
  final int flags;
  final int millivolts;
  final BatteryCharge charge;

  /// 0..4, as on the pedal's own icon.
  final int bars;

  /// Below this the pedal calls the battery empty.
  final int emptyMillivolts;

  bool get isEmpty =>
      charge == BatteryCharge.onBattery && (flags & 0x04 != 0 || bars == 0);

  /// The CFW app's tooltip text for this status.
  String get label {
    final text = ShellText.current;
    String volts(int mv) => '${(mv / 1000).toStringAsFixed(2)} V';
    final battOnly = flags & 0x08 != 0 ? text.battOnly : '';

    return switch (charge) {
      BatteryCharge.charging => text.batteryCharging,
      BatteryCharge.charged => text.batteryCharged,
      _ when isEmpty => text.batteryEmpty(volts(emptyMillivolts)) + battOnly,
      _ when bars == 1 => text.batteryLow(volts(millivolts)) + battOnly,
      _ => text.battery(bars, volts(millivolts)) + battOnly,
    };
  }
}

/// The voltage steps the CFW app counts when the pedal sends no bar count.
const _barSteps = [3540, 3620, 3760, 3900];

/// Decodes a `12 2D` reply ([p] starts at 0x12). Null when it is not one, its
/// version is unknown, or the pedal has no battery reading (flags bit0 clear).
BatteryStatus? decodeBatteryReply(List<int> p) {
  if (p.length < 12 || p[0] != 0x12 || p[1] != 0x2D || p[2] < 1) return null;

  final flags = p[3];

  if (flags & 0x01 == 0) return null;

  final mv = p[4] | (p[5] << 8);

  return BatteryStatus(
    flags: flags,
    millivolts: mv,
    charge: switch (p[6]) {
      0 => BatteryCharge.onBattery,
      2 => BatteryCharge.charged,
      _ => BatteryCharge.charging,
    },
    bars: p[7] == 255
        ? _barSteps.where((step) => mv > step).length
        : p[9].clamp(0, 4),
    emptyMillivolts: p[10] | (p[11] << 8),
  );
}
