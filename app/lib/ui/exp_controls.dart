import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../model/cfw_exp.dart';
import '../model/effect_parameter.dart';
import '../state/cfw_providers.dart';
import '../state/data_providers.dart';
import '../state/device_providers.dart';
import '../state/preset_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'sonic_controls.dart';
import 'sonic_metrics.dart';

const _slotNames = ['A', 'B', 'C', 'D'];

/// Target value of a slot that drives another module (shown, not pickable
/// here: assigning from this editor replaces it).
const _elsewhere = -2;
const _none = -1;

/// The CFW's EXP A-D assignment for one module, under its scene controls:
/// pick a slot, the knob of this module it moves, how (continuous, toggle,
/// momentary) and between which ends of the knob's range. The slots belong to
/// the loaded preset. Empty on stock firmware or while disconnected.
class ExpControls extends HookConsumerWidget {
  const ExpControls({super.key, required this.moduleId, required this.params});

  /// Physical module id (0 NR … 8 RVB).
  final int moduleId;

  /// The knobs of the module's current effect.
  final List<EffectParameter> params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCfw =
        ref.watch(connectionStateProvider) &&
        ref.watch(cfwInfoProvider) != null;
    final slots = ref.watch(expAssignsProvider);
    final mine = slots.indexWhere((a) => a?.module == moduleId);
    // Opens on the slot that drives this module, if any.
    final slot = useState(mine < 0 ? 0 : mine);

    if (!isCfw || params.isEmpty) return const SizedBox.shrink();

    final isLoading = ref.watch(presetLoadingProvider);
    final modules = ref.watch(dataAssetsProvider).valueOrNull?.modules;
    final height = SonicMetrics.of(context).editorControlHeight;
    final assign = slots[slot.value];
    final isHere = assign?.module == moduleId;
    final isKnown = isHere && params.any((p) => p.algId == assign!.algId);

    void set(ExpAssign? a) => setExpAssign(ref, slot.value, a);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        alignment: .center,
        crossAxisAlignment: .center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Text(
            'EXP',
            style: AppText.dialogBody.copyWith(color: Palette.onSurfaceVariant),
          ),
          SonicDropdown<int>(
            value: slot.value,
            width: 64,
            height: height,
            items: [
              for (final (i, name) in _slotNames.indexed)
                (value: i, label: name),
            ],
            onChanged: (v) => slot.value = v,
          ),
          SonicDropdown<int>(
            value: assign == null
                ? _none
                : (isKnown ? assign.algId : _elsewhere),
            width: 132,
            height: height,
            isEnabled: !isLoading,
            items: [
              (value: _none, label: 'None'),
              if (assign != null && !isKnown)
                (
                  value: _elsewhere,
                  label: isHere
                      ? 'Knob ${assign.algId}'
                      : modules?.nameOf(assign.module) ??
                            'Module ${assign.module}',
                ),
              for (final p in params) (value: p.algId, label: p.name),
            ],
            onChanged: (v) {
              if (v == _elsewhere) return;

              set(v == _none ? null : ExpAssign(module: moduleId, algId: v));
            },
          ),
          if (isKnown) ...[
            SonicSegmented<int>(
              value: assign!.mode,
              height: height,
              segments: const [
                (value: ExpAssign.continuous, label: 'Cont'),
                (value: ExpAssign.toggle, label: 'Toggle'),
                (value: ExpAssign.momentary, label: 'Moment'),
              ],
              onChanged: isLoading
                  ? null
                  : (v) => set(assign.copyWith(mode: v)),
            ),
            _Percent(
              value: assign.min,
              height: height,
              isEnabled: !isLoading,
              onChanged: (v) => set(assign.copyWith(min: v)),
            ),
            _Percent(
              value: assign.max,
              height: height,
              isEnabled: !isLoading,
              onChanged: (v) => set(assign.copyWith(max: v)),
            ),
          ],
        ],
      ),
    );
  }
}

/// One end of the range, 0..100 % in steps of 5 (plus the pedal's own value
/// when it sits between steps).
class _Percent extends StatelessWidget {
  const _Percent({
    required this.value,
    required this.height,
    required this.isEnabled,
    required this.onChanged,
  });

  final int value;
  final double height;
  final bool isEnabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SonicDropdown<int>(
    value: value,
    width: 84,
    height: height,
    isEnabled: isEnabled,
    items: [
      for (final v in {
        for (var i = 0; i <= 100; i += 5) i,
        value,
      }.toList()..sort())
        (value: v, label: '$v %'),
    ],
    onChanged: onChanged,
  );
}
