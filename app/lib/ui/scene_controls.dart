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

/// The CFW scene controls of one module, under its knobs: a Scenes switch
/// (the module takes part in scenes), the live-scene selector BASE / SC1 / SC2
/// and, in SC1 or SC2, the module's on/off for that scene (BASE follows the
/// preset). Empty on stock firmware or while disconnected.
class SceneControls extends ConsumerWidget {
  const SceneControls({
    super.key,
    required this.moduleId,
    this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 8),
  });

  /// Physical module id (0 NR … 8 RVB).
  final int moduleId;

  /// Around the controls (the block panel pads them itself).
  final EdgeInsets padding;

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

    return Padding(
      padding: padding,
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
              SonicToggle(
                value: record != null,
                height: height,
                onChanged: isLoading
                    ? null
                    : (v) => setModuleInScenes(ref, moduleId, isIn: v),
              ),
            ],
          ),
          if (record != null)
            SonicSegmented<int>(
              value: scene,
              height: height,
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
              height: height,
              segments: [
                (value: 0, label: t.follow),
                (value: 1, label: t.on),
                (value: 2, label: t.off),
              ],
              onChanged: isLoading
                  ? null
                  : (v) => setSceneModuleState(
                      ref,
                      moduleId,
                      v == 0 ? null : v == 1,
                    ),
            ),
        ],
      ),
    );
  }
}
