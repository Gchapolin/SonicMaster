import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/cfw_providers.dart';
import '../state/device_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// The CFW's DSP load ("DSP 57%") for the top bar: shown only while connected
/// to a CFW pedal once a load was read; in the alert color from 85 %, the
/// level the CFW itself flags.
class DspChip extends ConsumerWidget {
  const DspChip({super.key});

  static const alertFrom = 85;
  static const meterWidth = 86.0;
  static const trackKey = ValueKey('dsp-track');
  static const fillKey = ValueKey('dsp-fill');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCfw =
        ref.watch(connectionStateProvider) &&
        ref.watch(cfwInfoProvider) != null;
    final load = ref.watch(dspLoadProvider);

    if (!isCfw || load == null) return const SizedBox.shrink();

    final percent = load.clamp(0, 100);
    final isAlert = percent >= alertFrom;
    final color = isAlert ? Palette.error : Palette.onSurfaceVariant;
    // Flat stand-in for the prototype's ok-to-primary ramp (no gradients):
    // ok while light, primary once the load passes half, error at the alert.
    final fill = isAlert
        ? Palette.error
        : percent > 50
        ? Palette.primary
        : Palette.ok;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: .min,
        children: [
          Text(
            'DSP $percent%',
            style: AppText.mono.copyWith(color: color, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Container(
            key: trackKey,
            width: meterWidth,
            height: 6,
            decoration: BoxDecoration(
              color: Palette.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.centerLeft,
            child: Container(
              key: fillKey,
              width: meterWidth * percent / 100,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
