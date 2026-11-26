import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/shell_text.dart';
import '../model/effect_parameter.dart';
import '../model/footswitch_assignment.dart';
import '../model/footswitch_state.dart';
import '../state/cfw_providers.dart';
import '../state/data_providers.dart';
import '../state/device_providers.dart';
import '../state/preset_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'exp_controls.dart';
import 'knob_control.dart';
import 'module_editor.dart';
import 'scene_controls.dart';
import 'sonic_controls.dart';
import 'tap_tempo_control.dart';
import 'user_slots_dialog.dart';

/// The panel's width (prototype N_Principal) and the width its card's 14-px
/// padding leaves its controls.
const blockPanelWidth = 236.0;
const _inner = blockPanelWidth - 2 * 14;

/// The regular editor's right-hand panel (prototype N_Principal): block on,
/// Clone Mode (amp), the user slots (cab / clone), the footswitch, the
/// effect's non-knob params (toggles, selects, synced divisions, EQ bands),
/// DLY's tap tempo, the CFW scenes and EXP, then the effect's description.
/// Each param's row is keyed `param:<name>`.
class BlockPanel extends ConsumerWidget {
  const BlockPanel(this.moduleId, {super.key});

  /// Editor module id (9 = the clone amp).
  final int moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dataAssetsProvider).valueOrNull;
    final fxId = ref.watch(currentSelectedEffectsProvider)[moduleId];
    final def = fxId == null ? null : data?.effects.byId(fxId);

    if (data == null || def == null) return const SizedBox.shrink();

    final state = ref.watch(currentPresetStateProvider);
    final isLoading = ref.watch(presetLoadingProvider);
    final isConnected = ref.watch(connectionStateProvider);
    final isCfw = ref.watch(cfwInfoProvider) != null;
    final t = ShellText.current;
    // On/off, Clone Mode and the footswitch act on the physical slot; the
    // clone amp (editor id 9) is the real AMP slot (3).
    final physId = moduleId == 9 ? 3 : moduleId;
    final moduleOn =
        state?.moduleStates[data.modules.nameOf(physId) ?? ''] ?? false;
    final values = editorValues(ref, moduleId);
    final knobs = def.paramsFor(isCfw: isCfw);

    void set(EffectParameter p, num v) =>
        setParameter(ref, moduleId, p.algId, v);

    Widget labelled(String label, Widget control, {Key? key}) => Row(
      key: key,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: .ellipsis,
            style: AppText.ui.copyWith(color: Palette.textPrimary),
          ),
        ),
        control,
      ],
    );

    Widget section(String label, Widget control, {Key? key}) => Column(
      key: key,
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        Text(
          label.toUpperCase(),
          style: AppText.section.copyWith(color: Palette.textMuted),
        ),
        control,
      ],
    );

    Widget dropdown(EffectParameter p, List<String> labels, int value) =>
        section(
          key: ValueKey('param:${p.name}'),
          p.name,
          SonicDropdown<int>(
            value: value.clamp(0, labels.length - 1),
            width: _inner,
            height: 34,
            items: [for (final (i, l) in labels.indexed) (value: i, label: l)],
            isEnabled: !isLoading,
            onChanged: (i) => set(p, i),
          ),
        );

    // The params the piece doesn't draw.
    final params = <Widget>[];
    final bands = <Widget>[];

    for (final p in knobs) {
      final v = values[p.algId] ?? p.defaultValue;

      switch (p.widgetType) {
        case .toggle:
          params.add(
            labelled(
              key: ValueKey('param:${p.name}'),
              p.name,
              SonicToggle(
                value: v != 0,
                onChanged: isLoading ? null : (on) => set(p, on ? 1 : 0),
              ),
            ),
          );
        case .select:
          final options = p.options ?? const <String>[];

          if (options.isNotEmpty) params.add(dropdown(p, options, v.toInt()));
        case .knob when p.isSynced(values):
          // Tempo-sync engaged: the slot holds a note division.
          params.add(dropdown(p, syncDivisions, v.round()));
        case .knob:
          break; // on the piece
        case .eqBand:
          bands.add(
            KnobControl(
              value: v,
              min: p.min ?? 0,
              max: p.max ?? 100,
              step: p.step ?? 1,
              label: p.name,
              unit: p.unit,
              valueText: p.textFor(v),
              size: 44,
              isEnabled: !isLoading,
              onChanged: (x) => set(p, x),
            ),
          );
      }
    }

    // DLY: tap tempo drives Time in ms, only while Sync is off.
    EffectParameter? time;

    if (moduleId == 7) {
      for (final p in knobs) {
        if (p.algId == 1 && !p.isSynced(values)) time = p;
      }
    }

    final controls = <Widget>[
      labelled(
        t.blockOn,
        SonicToggle(
          key: const Key('block-on'),
          value: moduleOn,
          onChanged: isLoading ? null : (v) => toggleModule(ref, physId, v),
        ),
      ),
      if (physId == 3 && state != null)
        labelled(
          t.cloneMode,
          SonicToggle(
            value: state.isCloneMode,
            onChanged: isLoading ? null : (v) => setAmpMode(ref, v),
          ),
        ),
      // Every User IR / Clone slot in one list: load, rename, clear.
      if ((moduleId == 4 || moduleId == 9) && isConnected)
        SonicButton(
          label: t.userSlots,
          height: 34,
          minWidth: _inner,
          onPressed: isLoading
              ? null
              : () => showSonicDialog<void>(
                  context: context,
                  builder: (_) => const UserSlotsDialog(),
                ),
        ),
      if (state != null)
        section(
          t.footSwitch,
          SonicSegmented<FootswitchAssignment>(
            value: footswitchAssignmentOf(
              state.footswitchFs1Mask,
              state.footswitchFs2Mask,
              physId,
            ),
            isExpanded: true,
            segmentPadding: 4,
            segments: [
              (value: FootswitchAssignment.none, label: t.none),
              (value: FootswitchAssignment.fs1, label: 'FS1'),
              (value: FootswitchAssignment.fs2, label: 'FS2'),
            ],
            disabledValues: footswitchDisabledOptions(
              state.footswitchFs1Mask,
              state.footswitchFs2Mask,
              physId,
            ),
            onChanged: isLoading
                ? null
                : (a) => setModuleFootswitch(ref, physId, a),
          ),
        ),
      ...params,
      if (bands.isNotEmpty)
        Wrap(alignment: .center, spacing: 4, runSpacing: 4, children: bands),
      if (time != null)
        TapTempoControl(
          timeMin: (time.min ?? 20).round(),
          timeMax: (time.max ?? 1000).round(),
          currentMs: (values[1] ?? time.defaultValue).round(),
          onSend: (ms) => setParameter(ref, moduleId, 1, ms),
        ),
    ];

    Widget card(Widget child) => DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );

    return SizedBox(
      width: blockPanelWidth,
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 12,
        children: [
          card(
            Column(
              crossAxisAlignment: .stretch,
              children: [
                Column(
                  crossAxisAlignment: .stretch,
                  spacing: 16,
                  children: controls,
                ),
                // CFW only (empty otherwise).
                SceneControls(
                  moduleId: physId,
                  padding: const EdgeInsets.only(top: 16),
                ),
                ExpControls(
                  padding: const EdgeInsets.only(top: 16),
                  isModeExpanded: true,
                  // A fresh state per module: it opens on that module's slot.
                  key: ValueKey(physId),
                  moduleId: physId,
                  params: [
                    for (final p in knobs)
                      if (p.widgetType == .knob || p.widgetType == .eqBand) p,
                  ],
                ),
              ],
            ),
          ),
          if (def.descriptionEn.isNotEmpty)
            card(
              Text(
                def.descriptionEn,
                style: AppText.moduleDescription.copyWith(height: 1.55),
              ),
            ),
        ],
      ),
    );
  }
}
