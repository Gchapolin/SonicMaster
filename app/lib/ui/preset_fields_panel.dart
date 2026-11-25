import 'package:flutter/widgets.dart';

import '../l10n/shell_text.dart';
import '../state/preset_providers.dart';
import 'knob_control.dart';
import 'sonic_controls.dart';
import 'sonic_metrics.dart';

/// Preset Vol and Preset BPM as two full knobs, side by side: the panel the
/// top bar's values open (tap a value there).
///
/// The width is [SonicMetrics.presetPanelWidth]. Side by side is a [Wrap], so
/// a caption that outgrows its knob (a large browser text size) drops BPM to a
/// second line instead of overflowing.
class PresetFieldsPanel extends StatelessWidget {
  const PresetFieldsPanel({
    super.key,
    required this.presetVolume,
    required this.presetBpm,
    required this.isLoading,
    required this.onVolume,
    required this.onBpm,
  });

  final int presetVolume;
  final int presetBpm;
  final bool isLoading;
  final ValueChanged<int> onVolume;
  final ValueChanged<int> onBpm;

  @override
  Widget build(BuildContext context) {
    final metrics = SonicMetrics.of(context);

    return SizedBox(
      width: metrics.presetPanelWidth,
      child: SonicSurface(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          alignment: .center,
          spacing: 8,
          children: [
            KnobControl(
              value: presetVolume,
              min: 0,
              max: 100,
              step: 1,
              label: ShellText.current.presetVol,
              size: metrics.panelKnobSize,
              isEnabled: !isLoading,
              onChanged: (v) => onVolume(v.round()),
            ),
            KnobControl(
              value: presetBpm,
              min: presetBpmMin,
              max: presetBpmMax,
              step: 1,
              label: 'BPM',
              size: metrics.panelKnobSize,
              isEnabled: !isLoading,
              onChanged: (v) => onBpm(v.round()),
            ),
          ],
        ),
      ),
    );
  }
}
