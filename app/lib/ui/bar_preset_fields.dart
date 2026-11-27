import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/common_text.dart';
import '../model/slider_nudge.dart';
import '../model/tap_tempo.dart';
import '../state/preset_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'preset_fields_panel.dart';
import 'sonic_controls.dart';
import 'sonic_metrics.dart';

/// The loaded preset's volume and BPM in the top bar, right after its name:
/// drag a value up or down to turn it, or tap it for the two full knobs.
/// Regular adds the prototype's TAP button (tap tempo for the preset BPM).
/// The group opens with a hairline on its left (prototype N_Principal).
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

    final isCompact = SonicMetrics.of(context).isCompact;

    return Container(
      margin: EdgeInsets.only(left: isCompact ? 0 : 10),
      padding: EdgeInsets.only(left: isCompact ? 6 : 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Palette.outlineVariant)),
      ),
      child: Row(
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
          SizedBox(width: isCompact ? 2 : 6),
          BarValue(
            label: 'BPM',
            value: state.presetBpm,
            min: presetBpmMin,
            max: presetBpmMax,
            isEnabled: !isLoading,
            onChanged: (v) => setPresetBpm(ref, v),
            onTap: openKnobs,
          ),
          if (!isCompact) ...[
            const SizedBox(width: 6),
            BarTapButton(
              isEnabled: !isLoading,
              onBpm: (bpm) => setPresetBpm(ref, bpm),
            ),
          ],
        ],
      ),
    );
  }
}

/// The bar's TAP: each tap's pointer time feeds [bpmFromTaps] (the last four
/// taps; a pause over 2 s starts over), and every tempo it yields goes to
/// [onBpm], rounded.
class BarTapButton extends HookWidget {
  const BarTapButton({super.key, required this.isEnabled, required this.onBpm});

  final bool isEnabled;
  final ValueChanged<int> onBpm;

  @override
  Widget build(BuildContext context) {
    final taps = useMemoized(() => <int>[]);

    void tap(Duration at) {
      final ms = at.inMilliseconds;

      if (taps.isNotEmpty && ms - taps.last > 2000) taps.clear();

      taps.add(ms);

      if (taps.length > 4) taps.removeAt(0);

      final bpm = bpmFromTaps(taps);

      if (bpm != null) onBpm(bpm.round());
    }

    // A 44-pt target around the prototype's 32-pt outlined button.
    return Listener(
      behavior: .opaque,
      onPointerDown: isEnabled ? (e) => tap(e.timeStamp) : null,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.4,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Palette.secondaryContainer),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'TAP',
                style: AppText.ui.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: Palette.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
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
          // A 44-pt target around the prototype's small label over value.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: .min,
                mainAxisAlignment: .center,
                crossAxisAlignment: .start,
                children: [
                  Text(
                    label,
                    style: AppText.section.copyWith(
                      fontSize: 10,
                      height: 1.1,
                      color: Palette.muted,
                    ),
                  ),
                  Text(
                    '$value',
                    style: AppText.mono.copyWith(
                      fontSize: 15,
                      height: 1.1,
                      color: isEnabled ? Palette.textPrimary : Palette.textDim,
                    ),
                  ),
                ],
              ),
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
              label: CommonText.current.close,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
