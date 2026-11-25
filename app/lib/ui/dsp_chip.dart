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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCfw =
        ref.watch(connectionStateProvider) &&
        ref.watch(cfwInfoProvider) != null;
    final load = ref.watch(dspLoadProvider);

    if (!isCfw || load == null) return const SizedBox.shrink();

    final percent = load.clamp(0, 100);
    final color = percent >= alertFrom
        ? Palette.error
        : Palette.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            'DSP $percent%',
            style: AppText.dialogBody.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}
