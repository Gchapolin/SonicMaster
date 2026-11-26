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

/// The panel's width (prototype N_Principal) and the width its card's 12-px
/// padding leaves its controls (the prototype pads 14 and spaces 16; a little
/// tighter so every effect's controls fit at 1180x820).
const blockPanelWidth = 236.0;
const _inner = blockPanelWidth - 2 * 12;

/// Whether two switch labels each fit whole beside a 26pt switch when the pair
/// shares one panel row (16pt gap, 8pt between a label and its switch).
bool _pairFits(String a, String b) {
  const switchWidth = 26 * 104 / 46;

  double width(String s) => (TextPainter(
    text: TextSpan(text: s, style: AppText.ui),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout()).width;

  return width(a) + width(b) + 2 * (switchWidth + 8) + 16 <= _inner;
}

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
    final toggles = <Widget>[];
    final toggleLabels = <String>[];
    final bands = <Widget>[];

    for (final p in knobs) {
      final v = values[p.algId] ?? p.defaultValue;

      switch (p.widgetType) {
        case .toggle:
          toggleLabels.add(p.name);
          toggles.add(
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

          params.add(
            options.isEmpty
                ? labelled(
                    key: ValueKey('param:${p.name}'),
                    p.name,
                    const Text('—'),
                  )
                : dropdown(p, options, v.toInt()),
          );
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
              size: 32,
              isDense: true,
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
      // The switches two to a row when both labels fit beside their switch,
      // else one to a row.
      for (var i = 0; i < toggles.length; i += 2)
        if (i + 1 < toggles.length &&
            _pairFits(toggleLabels[i], toggleLabels[i + 1]))
          Row(
            children: [
              Expanded(child: toggles[i]),
              const SizedBox(width: 16),
              Expanded(child: toggles[i + 1]),
            ],
          )
        else ...[
          toggles[i],
          if (i + 1 < toggles.length) toggles[i + 1],
        ],
      ...params,
      // The EQ bands side by side, small and dense.
      if (bands.isNotEmpty)
        Row(
          crossAxisAlignment: .start,
          children: [
            for (final b in bands)
              Expanded(
                child: FittedBox(fit: .scaleDown, child: b),
              ),
          ],
        ),
      if (time != null)
        TapTempoControl(
          key: tapTempoKey,
          isPanel: true,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: child,
      ),
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
                  spacing: 6,
                  children: controls,
                ),
                // CFW only (empty otherwise).
                SceneControls(moduleId: physId, isPanel: true),
                ExpControls(
                  key: expControlsKey(physId),
                  moduleId: physId,
                  isPanel: true,
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
