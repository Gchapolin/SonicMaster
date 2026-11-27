import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/module_controls_text.dart';
import '../state/cfw_providers.dart';
import '../state/device_providers.dart';
import '../state/preset_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'sonic_controls.dart';
import 'sonic_metrics.dart';

/// The panel's control height: a 44pt touch target.
const _touch = 44.0;

/// The CFW scene controls of one module, under its knobs: a Scenes switch
/// (the module takes part in scenes), the live-scene selector BASE / SC1 / SC2
/// and, in SC1 or SC2, the module's on/off for that scene (BASE follows the
/// preset). Empty on stock firmware or while disconnected.
class SceneControls extends ConsumerWidget {
  const SceneControls({
    super.key,
    required this.moduleId,
    this.isPanel = false,
  });

  /// Physical module id (0 NR … 8 RVB).
  final int moduleId;

  /// The block panel's tight rows: label and switch on one row, the scene
  /// selector and the scene state under it.
  final bool isPanel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCfw =
        ref.watch(connectionStateProvider) &&
        ref.watch(cfwInfoProvider) != null;

    if (!isCfw) return const SizedBox.shrink();

    final t = ModuleControlsText.current;
    final record = ref.watch(sceneRecordsProvider)[moduleId];
    final scene = ref.watch(currentSceneProvider);
    final isLoading = ref.watch(presetLoadingProvider);
    final height = SonicMetrics.of(context).editorControlHeight;
    final isOn = record?.isOn(scene);

    final switchIn = SonicToggle(
      value: record != null,
      height: isPanel ? 26 : height,
      touchHeight: isPanel ? _touch : 0,
      onChanged: isLoading
          ? null
          : (v) => setModuleInScenes(ref, moduleId, isIn: v),
    );
    final selectors = [
      if (record != null)
        SonicSegmented<int>(
          value: scene,
          height: isPanel ? 34 : height,
          isExpanded: isPanel,
          isFilled: isPanel,
          segmentPadding: isPanel ? 4 : 16,
          segments: const [
            (value: 0, label: 'Base'),
            (value: 1, label: 'SC1'),
            (value: 2, label: 'SC2'),
          ],
          onChanged: isLoading ? null : (v) => selectScene(ref, v),
        ),
      if (record != null && scene != 0)
        SonicSegmented<int>(
          value: isOn == null ? 0 : (isOn ? 1 : 2),
          height: isPanel ? 34 : height,
          isExpanded: isPanel,
          isFilled: isPanel,
          segmentPadding: isPanel ? 4 : 16,
          segments: [
            (value: 0, label: t.follow),
            (value: 1, label: t.on),
            (value: 2, label: t.off),
          ],
          onChanged: isLoading
              ? null
              : (v) =>
                    setSceneModuleState(ref, moduleId, v == 0 ? null : v == 1),
        ),
    ];

    // The panel: label and switch on one row; the live-scene selector (its
    // labels need the full width to keep one size) and the module's state for
    // SC1 / SC2 under it.
    if (isPanel) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 8,
          children: [
            Row(
              children: [
                Text(
                  t.scenes,
                  style: AppText.ui.copyWith(color: Palette.textPrimary),
                ),
                const Spacer(),
                switchIn,
              ],
            ),
            ...selectors,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Wrap(
        alignment: .center,
        crossAxisAlignment: .center,
        spacing: 12,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: .min,
            children: [
              Text(
                t.scenes,
                style: AppText.dialogBody.copyWith(
                  color: Palette.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              switchIn,
            ],
          ),
          ...selectors,
        ],
      ),
    );
  }
}
