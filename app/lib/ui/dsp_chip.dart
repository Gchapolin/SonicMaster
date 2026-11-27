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

    // Stacked as in the prototype: the caption over an 86x6 bar, a dark inset
    // track with the ok-to-accent ramp (the alert color from 85 %).
    return SizedBox(
      width: meterWidth,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        spacing: 3,
        children: [
          Text(
            'DSP $percent%',
            style: AppText.gearLabel.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 10,
              letterSpacing: 1,
              height: 1.2,
              color: isAlert ? Palette.error : Palette.meterCaption,
            ),
          ),
          Container(
            key: trackKey,
            width: meterWidth,
            height: 6,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Palette.meterTrack,
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.centerLeft,
            child: Container(
              key: fillKey,
              width: meterWidth * percent / 100,
              decoration: BoxDecoration(
                color: isAlert ? Palette.error : null,
                gradient: isAlert ? null : Palette.meterFill,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
