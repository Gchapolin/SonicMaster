import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../model/slider_nudge.dart';
import '../state/preset_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'preset_fields_panel.dart';
import 'sonic_controls.dart';

/// The loaded preset's volume and BPM in the top bar, right after its name:
/// drag a value up or down to turn it, or tap it for the two full knobs.
/// Empty until a preset is decoded.
class BarPresetFields extends ConsumerWidget {
  const BarPresetFields({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(currentPresetStateProvider);
    final isLoading = ref.watch(presetLoadingProvider);

    if (state == null) return const SizedBox.shrink();

    void openKnobs() => showSonicDialog<void>(
      context: context,
      builder: (_) => const _PresetFieldsDialog(),
    );

    return Row(
      mainAxisSize: .min,
      children: [
        BarValue(
          label: 'VOL',
          value: state.presetVolume,
          min: 0,
          max: 100,
          isEnabled: !isLoading,
          onChanged: (v) => setPresetVolume(ref, v),
          onTap: openKnobs,
        ),
        const SizedBox(width: 6),
        BarValue(
          label: 'BPM',
          value: state.presetBpm,
          min: presetBpmMin,
          max: presetBpmMax,
          isEnabled: !isLoading,
          onChanged: (v) => setPresetBpm(ref, v),
          onTap: openKnobs,
        ),
      ],
    );
  }
}

/// One small value for the top bar: a label over the number. A vertical drag
/// turns it like a knob (up raises it), the mouse wheel nudges it by one, and
/// a tap runs [onTap].
class BarValue extends HookWidget {
  const BarValue({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.isEnabled,
    required this.onChanged,
    required this.onTap,
  });

  /// Pixels of vertical drag across the whole range, as on the knobs.
  static const _travelPx = 250.0;

  final String label;
  final int value;
  final int min;
  final int max;
  final bool isEnabled;
  final ValueChanged<int> onChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Unsnapped drag accumulator, so slow drags still move.
    final dragValue = useRef<double>(0);

    void emit(int v) {
      if (v != value) onChanged(v);
    }

    return MouseRegion(
      cursor: isEnabled
          ? SystemMouseCursors.resizeUpDown
          : SystemMouseCursors.basic,
      child: Listener(
        onPointerSignal: (e) {
          if (!isEnabled || e is! PointerScrollEvent || e.scrollDelta.dy == 0) {
            return;
          }

          final direction = e.scrollDelta.dy < 0 ? 1 : -1;

          GestureBinding.instance.pointerSignalResolver.register(
            e,
            (_) => emit(nudge(value, 1, direction, min, max).round()),
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onVerticalDragStart: isEnabled
              ? (_) => dragValue.value = value.toDouble()
              : null,
          onVerticalDragUpdate: isEnabled
              ? (d) {
                  dragValue.value = dragLinearStep(
                    dragValue.value,
                    -d.delta.dy,
                    min,
                    max,
                    _travelPx,
                  );
                  emit(dragValue.value.round());
                }
              : null,
          child: SonicRecess(
            radius: 8,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Column(
              mainAxisSize: .min,
              children: [
                Text(
                  label,
                  style: AppText.controlLabel.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    height: 1.2,
                    color: Palette.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$value',
                  style: AppText.bpm.copyWith(
                    height: 1.1,
                    color: isEnabled ? Palette.textPrimary : Palette.textDim,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The two full knobs, opened from a tap on a bar value.
class _PresetFieldsDialog extends ConsumerWidget {
  const _PresetFieldsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(currentPresetStateProvider);
    final isLoading = ref.watch(presetLoadingProvider);

    return SonicDialog(
      maxWidth: 420,
      child: Column(
        mainAxisSize: .min,
        children: [
          if (state != null)
            PresetFieldsPanel(
              presetVolume: state.presetVolume,
              presetBpm: state.presetBpm,
              isLoading: isLoading,
              onVolume: (v) => setPresetVolume(ref, v),
              onBpm: (v) => setPresetBpm(ref, v),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: SonicButton(
              label: 'Close',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
