import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/module_controls_text.dart';
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

/// The panel's control height: a 44pt touch target.
const _touch = 44.0;

/// The CFW's EXP A-D assignment for one module, under its scene controls:
/// pick a slot, the knob of this module it moves, how (continuous, toggle,
/// momentary) and between which ends of the knob's range. The slots belong to
/// the loaded preset. Empty on stock firmware or while disconnected.
class ExpControls extends HookConsumerWidget {
  const ExpControls({
    super.key,
    required this.moduleId,
    required this.params,
    this.isPanel = false,
  });

  /// The block panel's tight rows: label, slot and target, the mode across
  /// the width, then the range ends.
  final bool isPanel;

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

    final t = ModuleControlsText.current;
    final isLoading = ref.watch(presetLoadingProvider);
    final modules = ref.watch(dataAssetsProvider).valueOrNull?.modules;
    final height = SonicMetrics.of(context).editorControlHeight;
    final assign = slots[slot.value];
    final isHere = assign?.module == moduleId;
    final isKnown = isHere && params.any((p) => p.algId == assign!.algId);

    void set(ExpAssign? a) => setExpAssign(ref, slot.value, a);

    final h = isPanel ? _touch : height;
    // The panel (prototype N_Principal): filled 34-px fields, radius 8, in
    // 44-pt tap targets; the slot a 44-wide letter, the target the rest of
    // the row.
    final slotPicker = isPanel
        ? SonicDropdown<int>(
            value: slot.value,
            width: 44,
            height: 34,
            isFilled: true,
            hasArrow: false,
            labelStyle: AppText.ui.copyWith(fontWeight: FontWeight.w600),
            boxKey: const Key('exp-slot-box'),
            items: [
              for (final (i, name) in _slotNames.indexed)
                (value: i, label: name),
            ],
            onChanged: (v) => slot.value = v,
          )
        : SonicDropdown<int>(
            value: slot.value,
            width: 64,
            height: h,
            items: [
              for (final (i, name) in _slotNames.indexed)
                (value: i, label: name),
            ],
            onChanged: (v) => slot.value = v,
          );
    final targetItems = [
      (value: _none, label: t.none),
      if (assign != null && !isKnown)
        (
          value: _elsewhere,
          label: isHere
              ? t.knob(assign.algId)
              : modules?.nameOf(assign.module) ?? t.module(assign.module),
        ),
      for (final p in params) (value: p.algId, label: p.name),
    ];
    final targetValue = assign == null
        ? _none
        : (isKnown ? assign.algId : _elsewhere);
    void pickTarget(int v) {
      if (v == _elsewhere) return;

      set(v == _none ? null : ExpAssign(module: moduleId, algId: v));
    }

    Widget targetAt(double? width) => isPanel
        ? SonicDropdown<int>(
            value: targetValue,
            width: width,
            height: 34,
            isFilled: true,
            labelStyle: AppText.ui.copyWith(fontWeight: FontWeight.w400),
            boxKey: const Key('exp-target-box'),
            isEnabled: !isLoading,
            items: targetItems,
            onChanged: pickTarget,
          )
        : SonicDropdown<int>(
            value: targetValue,
            width: width,
            height: h,
            isEnabled: !isLoading,
            items: targetItems,
            onChanged: pickTarget,
          );
    final mode = isKnown
        ? SonicSegmented<int>(
            value: assign!.mode,
            height: isPanel ? 34 : h,
            isExpanded: isPanel,
            isFilled: isPanel,
            segmentPadding: isPanel ? 4 : 16,
            segments: [
              (value: ExpAssign.continuous, label: t.continuous),
              (value: ExpAssign.toggle, label: t.toggle),
              (value: ExpAssign.momentary, label: t.momentary),
            ],
            onChanged: isLoading ? null : (v) => set(assign.copyWith(mode: v)),
          )
        : null;
    final range = isKnown
        ? [
            _Percent(
              value: assign!.min,
              width: 84,
              height: h,
              isEnabled: !isLoading,
              onChanged: (v) => set(assign.copyWith(min: v)),
            ),
            _Percent(
              value: assign.max,
              width: 84,
              height: h,
              isEnabled: !isLoading,
              onChanged: (v) => set(assign.copyWith(max: v)),
            ),
          ]
        : const <Widget>[];

    if (isPanel) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 8,
          children: [
            Text(
              t.expPedal.toUpperCase(),
              style: AppText.section.copyWith(color: Palette.outline),
            ),
            // One row: the slot letter and the target filling the rest.
            LayoutBuilder(
              builder: (context, box) => Row(
                children: [
                  slotPicker,
                  const SizedBox(width: 6),
                  targetAt(box.maxWidth - 44 - 6),
                ],
              ),
            ),
            ?mode,
            if (range.isNotEmpty)
              // The ends grow to show "100 %" whole; two do not share the
              // panel's width, so the second wraps under the first.
              Wrap(
                alignment: .spaceBetween,
                runSpacing: 8,
                spacing: 8,
                children: range,
              ),
          ],
        ),
      );
    }

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
            style: AppText.ui.copyWith(
              fontSize: 14,
              color: Palette.onSurfaceVariant,
            ),
          ),
          slotPicker,
          targetAt(132),
          ?mode,
          ...range,
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
    required this.width,
    required this.height,
    required this.isEnabled,
    required this.onChanged,
  });

  final int value;
  final double width;
  final double height;
  final bool isEnabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SonicDropdown<int>(
    value: value,
    width: width,
    height: height,
    isEnabled: isEnabled,
    fitLabels: true,
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
