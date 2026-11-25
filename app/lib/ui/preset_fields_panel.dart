import 'package:flutter/widgets.dart';

import '../state/preset_providers.dart';
import 'knob_control.dart';
import 'sonic_controls.dart';
import 'sonic_metrics.dart';

/// The preset-level panel: Preset Vol and Preset BPM. Regular layout: on its
/// own row above the effect chain. Compact (phone): to the left of the effect
/// editor, where the screen has no height to spare. [topSpacer] lines the first knob up with the module's knob row.
///
/// Layout mirrors the module knobs: [stacked] (the module's Wrap spilled onto a
/// second line) puts BPM below Preset Vol; otherwise they sit side by side on the
/// single row. [patchKnobKey] lets the parent measure one knob's height to
/// decide [stacked].
///
/// The width is [SonicMetrics.presetPanelWidth]: fixed per mode, never derived
/// from [stacked] (see that field). Side by side is a [Wrap], so a caption
/// that outgrows its knob (a large browser text size) drops BPM to a second
/// line instead of overflowing.
class PresetFieldsPanel extends StatelessWidget {
  const PresetFieldsPanel({
    super.key,
    required this.presetVolume,
    required this.presetBpm,
    required this.isLoading,
    required this.topSpacer,
    required this.stacked,
    required this.patchKnobKey,
    this.bottomSpacer = 0,
    this.knobSize,
    required this.onVolume,
    required this.onBpm,
  });

  final int presetVolume;
  final int presetBpm;
  final bool isLoading;
  final double topSpacer;
  final bool stacked;
  final Key patchKnobKey;

  /// Space under the knobs: the panel standing on its own row (regular
  /// layout, above the chain) is not stretched to a neighbour's height.
  final double bottomSpacer;

  /// The dials' size; null takes the layout's [SonicMetrics.panelKnobSize].
  /// The regular layout's row above the chain uses a smaller dial, so the
  /// effect's own knobs stay on screen below the chain.
  final double? knobSize;
  final ValueChanged<int> onVolume;
  final ValueChanged<int> onBpm;

  @override
  Widget build(BuildContext context) {
    final metrics = SonicMetrics.of(context);

    // The module knobs' dial: the page's stacked test compares the module knob
    // row with 1.4x this knob's cell height.
    final patchVol = KnobControl(
      key: patchKnobKey,
      value: presetVolume,
      min: 0,
      max: 100,
      step: 1,
      label: 'Preset Vol',
      size: knobSize ?? metrics.panelKnobSize,
      isEnabled: !isLoading,
      onChanged: (v) => onVolume(v.round()),
    );

    final bpm = KnobControl(
      value: presetBpm,
      min: presetBpmMin,
      max: presetBpmMax,
      step: 1,
      label: 'BPM',
      size: knobSize ?? metrics.panelKnobSize,
      isEnabled: !isLoading,
      onChanged: (v) => onBpm(v.round()),
    );

    return SizedBox(
      width: metrics.presetPanelWidth,
      child: SonicSurface(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: .min,
          children: [
            SizedBox(height: topSpacer),
            if (stacked) ...[
              patchVol,
              bpm,
            ] else
              Wrap(alignment: .center, spacing: 8, children: [patchVol, bpm]),
            SizedBox(height: bottomSpacer),
          ],
        ),
      ),
    );
  }
}
