import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/battery_status.dart';
import '../state/cfw_providers.dart';
import '../state/device_providers.dart';
import '../theme/app_colors.dart';

/// The CFW pedal's battery for the top bar, like the CFW app's icon next to
/// the USB / BT sign: shown only while connected once a reading arrived; low
/// (1 bar) and empty in the alert color. Its label is the CFW app's tooltip.
class BatteryChip extends ConsumerWidget {
  const BatteryChip({super.key});

  /// On battery, by bar count (0..4).
  static const _byBars = [
    Icons.battery_alert,
    Icons.battery_1_bar,
    Icons.battery_3_bar,
    Icons.battery_5_bar,
    Icons.battery_full,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(batteryProvider);

    if (!ref.watch(connectionStateProvider) || status == null) {
      return const SizedBox.shrink();
    }

    final onBattery = status.charge == BatteryCharge.onBattery;
    final glyph = !onBattery
        ? Icons.battery_charging_full
        : status.isEmpty
        ? Icons.battery_alert
        : _byBars[status.bars];
    final color = onBattery && status.bars <= 1
        ? Palette.error
        : Palette.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        label: status.label,
        excludeSemantics: true,
        child: Icon(glyph, size: 20, color: color),
      ),
    );
  }
}
