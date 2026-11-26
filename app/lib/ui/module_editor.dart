import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gear/gear_lookup.dart';
import '../gear/gear_piece.dart';
import '../l10n/amp_text.dart';
import '../l10n/shell_text.dart';
import '../model/amp_gain.dart';
import '../model/effect_parameter.dart';
import '../model/footswitch_assignment.dart';
import '../model/footswitch_state.dart';
import '../model/slider_nudge.dart';
import '../protocol/cfw_slot_names_codec.dart';
import '../state/cfw_providers.dart';
import '../state/data_providers.dart';
import '../state/device_providers.dart';
import '../state/names_providers.dart';
import '../state/preset_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'block_panel.dart';
import 'exp_controls.dart';
import 'knob_control.dart';
import 'knob_mapping.dart';
import 'scene_controls.dart';
import 'sonic_controls.dart';
import 'sonic_field.dart';
import 'sonic_metrics.dart';
import 'tap_tempo_control.dart';
import 'user_ir_actions.dart';
import 'user_profile_actions.dart';
import 'user_slots_dialog.dart';

/// Tempo-sync note divisions, indexed by the value the pedal stores in a
/// sync-capable Rate slot (0 = 1/1 … 10 = 1/16). Captured off the device.
const syncDivisions = <String>[
  '1/1', '1/2', '1/2D', '1/2T', '1/4', '1/4D', '1/4T', //
  '1/8', '1/8D', '1/8T', '1/16',
];

/// The tap tempo and each module's EXP controls keep their state (tempo,
/// beat, picked slot) across a regular/compact flip, where they move between
/// the control row and the block panel: a GlobalKey carries them over.
final tapTempoKey = GlobalKey();
final _expKeys = <int, GlobalKey>{};

/// The EXP controls' key for physical module [physId]: a fresh state per
/// module, the same one in both layouts.
GlobalKey expControlsKey(int physId) =>
    _expKeys.putIfAbsent(physId, GlobalKey.new);

/// The values [moduleId]'s editor shows: its params, with the live scene's
/// over them on the CFW in SC1 / SC2 when the module takes part in scenes
/// (values for knobs the effect lacks are never looked up).
Map<int, num> editorValues(WidgetRef ref, int moduleId) {
  final physId = moduleId == 9 ? 3 : moduleId;
  final sceneRecord = ref.watch(sceneRecordsProvider)[physId];
  final scene = ref.watch(currentSceneProvider);
  final isSceneLive =
      ref.watch(cfwInfoProvider) != null && scene != 0 && sceneRecord != null;

  return {
    ...?ref.watch(currentParametersProvider)[moduleId],
    if (isSceneLive)
      ...sceneRecord
          .values(scene)
          .map((k, v) => MapEntry(k, v == v.roundToDouble() ? v.round() : v)),
  };
}

/// Editing controls for one module's selected effect. Each change sends a
/// `0408` command via [setParameter].
class ModuleEditor extends ConsumerWidget {
  const ModuleEditor(this.moduleId, {super.key, this.knobRowKey});

  final int moduleId;

  /// Attached to the horizontal knob row so the parent can vertically align the
  /// Patch Vol knob with the effect's knobs.
  final Key? knobRowKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dataAssetsProvider).valueOrNull;
    final userNames = ref.watch(userNamesProvider);
    final selected = ref.watch(currentSelectedEffectsProvider);
    final modified = ref.watch(presetModifiedProvider);
    final isLoading = ref.watch(presetLoadingProvider);
    final isConnected = ref.watch(connectionStateProvider);
    final model = ref.watch(effectiveDeviceModelProvider);
    final state = ref.watch(currentPresetStateProvider);
    final metrics = SonicMetrics.of(context);

    if (data == null) return const SizedBox.shrink();

    // The header on/off toggle acts on the physical slot; the clone amp (editor
    // id 9) toggles the real AMP slot (3).
    final physId = moduleId == 9 ? 3 : moduleId;
    final moduleName = data.modules.nameOf(physId) ?? 'M$moduleId';
    final moduleOn = state?.moduleStates[moduleName] ?? false;
    final fxId = selected[moduleId];
    final def = fxId == null ? null : data.effects.byId(fxId);

    if (def == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(ShellText.current.noDecodedEffect(moduleName)),
      );
    }

    final values = editorValues(ref, moduleId);
    final isCfw = ref.watch(cfwInfoProvider) != null;
    final effectIds = data.capabilities.availableEffectIds(
      data.commands,
      model,
      moduleId,
      isCfw: isCfw,
    );
    // The knobs this firmware has (the CFW adds some to the stock delays and
    // reverbs).
    final knobs = def.paramsFor(isCfw: isCfw);
    // Keep the current effect in the dropdown even if it isn't in the pickable
    // set — some presets hold legacy/hidden effects (e.g. Fullchor / Flash /
    // Doctor CL) that decode but have no select command; this keeps the value
    // valid and the name shown.
    final offered = effectIds.contains(fxId)
        ? effectIds
        : <int>[fxId!, ...effectIds];
    // Amps run clean to high gain, under band titles.
    final isAmp = moduleId == 3;
    final dropdownIds = isAmp ? byAmpGain(offered) : offered;
    final sections = isAmp
        ? {
            for (final e in ampBandStarts(dropdownIds).entries)
              e.key: AmpText.current.band(e.value),
          }
        : const <int, String>{};

    // Regular (prototype N_Principal): the header, the big piece and its
    // value line, beside the block panel holding every other control.
    if (!metrics.isCompact) {
      // The effect's knobs live on the piece; a synced Rate / Time holds a
      // note division, not a position: it stays off the piece and keeps its
      // division dropdown in the panel.
      final onPiece = [
        for (final p in pieceKnobs(def, isCfw: isCfw))
          if (!p.isSynced(values)) p,
      ];

      // The header, piece and value line set the height; the panel lives
      // beside them within it and scrolls on its own if ever taller, so the
      // piece never leaves the screen.
      return Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: blockPanelWidth + 16),
            child: Column(
              crossAxisAlignment: .stretch,
              mainAxisSize: .min,
              children: [
                Padding(
                  padding: metrics.editorHeaderPadding,
                  child: _ModelHeader(
                    tag: '$moduleName${modified ? '  ✱' : ''}',
                    ids: dropdownIds,
                    current: fxId!,
                    labelOf: (id) =>
                        effectDisplayName(id, data.effects, userNames),
                    sections: sections,
                    band: isAmp ? ampGainOf(fxId) : null,
                    isEnabled: !isLoading,
                    onPick: (id) => setEffectType(ref, moduleId, id),
                  ),
                ),
                _PieceEditor(
                  // A new model starts the value line on its first knob again.
                  key: ValueKey(def.id),
                  model: def.name,
                  kind: gearKindForModule(physId),
                  knobs: onPiece,
                  values: values,
                  isOn: moduleOn,
                  isEnabled: !isLoading,
                  onSet: (p, v) => setParameter(ref, moduleId, p.algId, v),
                  onSwitch: () => toggleModule(ref, physId, !moduleOn),
                ),
              ],
            ),
          ),
          // Level with the header's 12-px top padding.
          Positioned(
            top: 12,
            right: 16,
            bottom: 12,
            width: blockPanelWidth,
            child: SingleChildScrollView(child: BlockPanel(moduleId)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      children: [
        Padding(
          padding: metrics.editorHeaderPadding,
          child: Row(
            children: [
              // abbreviation — pinned left. The forced Oswald strut holds the
              // line when "✱" (not in Oswald) shows: its fallback face, which
              // the web fetches only after the first layout, would make the
              // line taller than the IntrinsicHeight pass measured.
              Text(
                '$moduleName${modified ? '  ✱' : ''}',
                strutStyle: StrutStyle.fromTextStyle(
                  AppText.moduleTitle,
                  forceStrutHeight: true,
                ),
                style: AppText.moduleTitle.copyWith(color: Palette.textPrimary),
              ),
              // effect type — dropdown (if selectable) or static name, centered
              // between the title and the toggle. Expanded + Center puts it
              // exactly where the former Spacer pair did whenever it fits, and
              // lets a long name (a user-named clone holds up to 15 chars)
              // ellipsize instead of overflowing the header.
              // Gate on dropdownIds (not effectIds): device filtering can narrow
              // the pickable set to one, but a legacy/unsupported current effect
              // is still prepended, and the user must be able to switch off it.
              Expanded(
                child: Center(
                  child: dropdownIds.length > 1
                      ? SonicDropdown<int>(
                          value: fxId,
                          height: metrics.editorControlHeight,
                          items: [
                            for (final id in dropdownIds)
                              (
                                value: id,
                                label: effectDisplayName(
                                  id,
                                  data.effects,
                                  userNames,
                                ),
                              ),
                          ],
                          sections: sections,
                          isEnabled: !isLoading,
                          onChanged: (id) => setEffectType(ref, moduleId, id),
                        )
                      : Text(
                          effectDisplayName(fxId!, data.effects, userNames),
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: AppText.controlLabel.copyWith(
                            color: Palette.textPrimary,
                          ),
                        ),
                ),
              ),
              // enabled — BOOST-style toggle (no label), pinned right
              SonicToggle(
                value: moduleOn,
                onChanged: isLoading
                    ? null
                    : (v) => toggleModule(ref, physId, v),
              ),
            ],
          ),
        ),
        // Every control — knobs, toggles, dropdowns — flows in ONE horizontal
        // Wrap like a hardware unit's front panel (always a single row that
        // wraps; never separate full-width rows). DLY (module 7) prepends its
        // tap-tempo cells (TAP / BPM / division / computed-ms) to the same row.
        Builder(
          key: const ValueKey('control-row'),
          builder: (context) {
            final cells = [
              // AMP-only: Clone Mode toggle in the settings row (off = Normal/
              // factory amp, on = Clone) — switches the amp slot between factory
              // models (module 3) and the User-Profile clone (module 9).
              if (physId == 3 && state != null)
                PanelCell(
                  label: ShellText.current.cloneMode,
                  control: SonicToggle(
                    value: state.isCloneMode,
                    height: metrics.editorControlHeight,
                    onChanged: isLoading ? null : (v) => setAmpMode(ref, v),
                  ),
                ),
              // Every User IR / Clone slot in one list, whatever the preset
              // uses here: a file goes into a slot without switching to it.
              if ((moduleId == 4 || moduleId == 9) && isConnected)
                PanelCell(
                  label: ShellText.current.userSlots,
                  control: SonicButton(
                    label: 'Slots…',
                    height: metrics.editorControlHeight,
                    minWidth: 72,
                    onPressed: isLoading
                        ? null
                        : () => showSonicDialog<void>(
                            context: context,
                            builder: (_) => const UserSlotsDialog(),
                          ),
                  ),
                ),
              // User-IR slots (module 4): load a WAV into the slot, rename it
              // or clear it. Slots 6-10 (fxId 422-426) exist on the CFW only
              // and take the same commands (seen in the capture).
              if (moduleId == 4 && fxId != null)
                if (userIrSlotOf(fxId) case final slot?)
                  UserIrActions(
                    slot: slot,
                    isEnabled: isConnected && !isLoading,
                    currentName: effectDisplayName(
                      fxId,
                      data.effects,
                      userNames,
                    ),
                  ),
              // User-Profile clone slots (module 9): convert a .nam natively
              // and load it into the selected slot (6-10 on the CFW only).
              if (moduleId == 9 && fxId != null)
                if (userProfileSlotOf(fxId) case final slot?)
                  UserProfileActions(
                    slot: slot,
                    isEnabled: isConnected && !isLoading,
                    currentName: effectDisplayName(
                      fxId,
                      data.effects,
                      userNames,
                    ),
                  ),
              for (final p in knobs)
                _control(
                  context,
                  ref,
                  p,
                  values[p.algId] ?? p.defaultValue,
                  isLoading,
                  values,
                ),
              // Per-module footswitch assignment (None/FS1/FS2). Keyed on the
              // physical slot so the clone-amp editor (id 9) drives the amp's.
              if (state != null)
                _FootswitchCell(
                  moduleId: physId,
                  fs1Mask: state.footswitchFs1Mask,
                  fs2Mask: state.footswitchFs2Mask,
                  isEnabled: !isLoading,
                  onChanged: (a) => setModuleFootswitch(ref, physId, a),
                ),
            ];

            // Tap tempo drives DLY's Time slot in milliseconds — but only while
            // Sync is off. Engaged, the pedal rereads that same slot as a
            // note-division index (confirmed: Time 500 -> 4.0 = "1/4"), so a tap
            // would write nonsense into it. Drop back to the plain row then; the
            // division dropdown is the control that belongs there.
            EffectParameter? timeParam;

            if (moduleId == 7) {
              for (final p in knobs) {
                if (p.algId != 1) continue;

                if (!p.isSynced(values)) timeParam = p;

                break;
              }
            }

            return Padding(
              key: knobRowKey,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: timeParam != null
                  ? TapTempoControl(
                      key: tapTempoKey,
                      timeMin: (timeParam.min ?? 20).round(),
                      timeMax: (timeParam.max ?? 1000).round(),
                      currentMs: (values[1] ?? timeParam.defaultValue).round(),
                      onSend: (ms) => setParameter(ref, moduleId, 1, ms),
                      trailing: cells,
                    )
                  : Wrap(
                      alignment: .center,
                      spacing: 4,
                      runSpacing: 4,
                      children: cells,
                    ),
            );
          },
        ),
        SceneControls(moduleId: physId),
        ExpControls(
          // A fresh state per module: it opens on that module's own slot.
          key: expControlsKey(physId),
          moduleId: physId,
          params: [
            for (final p in knobs)
              if (p.widgetType == .knob || p.widgetType == .eqBand) p,
          ],
        ),
      ],
    );
  }

  Widget _control(
    BuildContext context,
    WidgetRef ref,
    EffectParameter param,
    num value,
    bool isLoading,
    Map<int, num> values,
  ) {
    final metrics = SonicMetrics.of(context);

    switch (param.widgetType) {
      case .toggle:
        return PanelCell(
          label: param.name,
          control: SonicToggle(
            value: value != 0,
            height: metrics.editorControlHeight,
            onChanged: isLoading
                ? null
                : (v) => setParameter(ref, moduleId, param.algId, v ? 1 : 0),
          ),
        );
      case .select:
        final options = param.options ?? const <String>[];

        if (options.isEmpty) {
          return PanelCell(label: param.name, control: const Text('—'));
        }

        return PanelCell(
          label: param.name,
          control: SonicDropdown<int>(
            value: value.toInt().clamp(0, options.length - 1),
            height: metrics.editorControlHeight,
            items: [
              for (final (i, opt) in options.indexed) (value: i, label: opt),
            ],
            isEnabled: !isLoading,
            onChanged: (i) => setParameter(ref, moduleId, param.algId, i),
          ),
        );
      case .knob:
      case .eqBand:
        if (param.isSynced(values)) {
          // Tempo-sync engaged: the pedal reads this slot as a note-division
          // index (0 = 1/1 … 10 = 1/16), so show a division selector instead
          // of the Hz knob.
          final idx = value.round().clamp(0, syncDivisions.length - 1);

          return PanelCell(
            label: param.name,
            // Fixed width wide enough for the widest label ("1/2D"/"1/16");
            // passing SonicDropdown.width also sizes its menu to match.
            control: SonicDropdown<int>(
              value: idx,
              width: 112,
              height: metrics.editorControlHeight,
              items: [
                for (final (i, div) in syncDivisions.indexed)
                  (value: i, label: div),
              ],
              isEnabled: !isLoading,
              onChanged: (i) => setParameter(ref, moduleId, param.algId, i),
            ),
          );
        }

        return KnobControl(
          value: value,
          min: param.min ?? 0,
          max: param.max ?? 100,
          step: param.step ?? 1,
          label: param.name,
          unit: param.unit,
          // The CFW models' data texts ("21Hz", "-3.5dB").
          valueText: param.textFor(value),
          size: metrics.panelKnobSize,
          isEnabled: !isLoading,
          onChanged: (v) => setParameter(ref, moduleId, param.algId, v),
        );
    }
  }
}

/// The per-module FOOT SWITCH selector: None / FS1 / FS2, laid out as a panel
/// cell in the module's control row. A switch already owned by another module is
/// greyed out — each footswitch has a single global owner.
class _FootswitchCell extends StatelessWidget {
  const _FootswitchCell({
    required this.moduleId,
    required this.fs1Mask,
    required this.fs2Mask,
    required this.isEnabled,
    required this.onChanged,
  });

  final int moduleId;
  final int fs1Mask;
  final int fs2Mask;
  final bool isEnabled;
  final ValueChanged<FootswitchAssignment> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = footswitchAssignmentOf(fs1Mask, fs2Mask, moduleId);
    // A switch is greyed out only once it is FULL (holds the max modules) and
    // this module isn't on it — each switch takes up to [footswitchCapacity].
    final disabled = footswitchDisabledOptions(fs1Mask, fs2Mask, moduleId);

    return PanelCell(
      label: ShellText.current.footSwitch,
      control: SonicSegmented<FootswitchAssignment>(
        value: current,
        segmentPadding: SonicMetrics.of(context).footswitchSegmentPadding,
        segments: [
          (value: FootswitchAssignment.none, label: ShellText.current.none),
          (value: FootswitchAssignment.fs1, label: 'FS1'),
          (value: FootswitchAssignment.fs2, label: 'FS2'),
        ],
        disabledValues: disabled,
        onChanged: isEnabled ? onChanged : null,
      ),
    );
  }
}

/// The regular editor's header (prototype N_Principal): the module tag, the
/// model selector between previous / next arrows (wrapping), the amp's band
/// chip. The block's on/off is the panel's (BlockPanel).
class _ModelHeader extends StatelessWidget {
  const _ModelHeader({
    required this.tag,
    required this.ids,
    required this.current,
    required this.labelOf,
    required this.sections,
    required this.band,
    required this.isEnabled,
    required this.onPick,
  });

  final String tag;
  final List<int> ids;
  final int current;
  final String Function(int id) labelOf;
  final Map<int, String> sections;
  final AmpGain? band;
  final bool isEnabled;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final canWalk = ids.length > 1;

    // The model [by] steps away in the list, wrapping at either end.
    void walk(int by) {
      final i = ids.indexOf(current);

      onPick(ids[(i + by) % ids.length]);
    }

    // A 36-px box in a 44-wide hit area, as tall as the selector.
    Widget arrow(String key, IconData icon, int by) => SizedBox(
      key: Key(key),
      width: 44,
      height: SonicMetrics.of(context).editorControlHeight,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SonicIconButton(
            icon: icon,
            size: 16,
            padding: const EdgeInsets.all(10),
            onPressed: isEnabled ? () => walk(by) : null,
          ),
        ),
      ),
    );

    return Row(
      children: [
        // Pinned to the prototype's 40-px tag column; the forced strut holds
        // the line when "✱" (not in the face) shows.
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40),
          child: Text(
            tag,
            strutStyle: StrutStyle.fromTextStyle(
              AppText.moduleTitle,
              forceStrutHeight: true,
            ),
            style: AppText.moduleTitle.copyWith(color: Palette.textPrimary),
          ),
        ),
        const SizedBox(width: 4),
        // The rest of the line, left-aligned: the selector keeps its natural
        // width (220 at least) and ellipsizes only when the line is short.
        Expanded(
          child: Row(
            children: [
              if (canWalk) arrow('model-prev', Icons.chevron_left, -1),
              Flexible(
                child: canWalk
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 220),
                        child: SonicDropdown<int>(
                          value: current,
                          height: SonicMetrics.of(context).editorControlHeight,
                          items: [
                            for (final id in ids)
                              (value: id, label: labelOf(id)),
                          ],
                          sections: sections,
                          isEnabled: isEnabled,
                          onChanged: onPick,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          labelOf(current),
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: AppText.controlLabel.copyWith(
                            color: Palette.textPrimary,
                          ),
                        ),
                      ),
              ),
              if (canWalk) arrow('model-next', Icons.chevron_right, 1),
              if (band case final band?) ...[
                const SizedBox(width: 6),
                DecoratedBox(
                  key: const Key('amp-band'),
                  decoration: BoxDecoration(
                    color: Palette.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      AmpText.current.band(band).toUpperCase(),
                      style: AppText.section.copyWith(color: Palette.primary),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The regular editor's piece box: the prototype's 660x440 scaled to 600x400
/// (same 3:2), so at the iPad's 1180x820 the header, the piece and its value
/// line fit under the pedalboard without scrolling.
const pieceFit = Size(600, 400);

/// The regular editor's big piece (fitted to [pieceFit], scaled down when the
/// editor is narrower) with the value line under it: the last-touched knob's
/// name and value, as KnobControl prints it. Tapping the value types one in.
class _PieceEditor extends HookWidget {
  const _PieceEditor({
    super.key,
    required this.model,
    required this.kind,
    required this.knobs,
    required this.values,
    required this.isOn,
    required this.isEnabled,
    required this.onSet,
    required this.onSwitch,
  });

  final String model;
  final GearKind kind;
  final List<EffectParameter> knobs;
  final Map<int, num> values;
  final bool isOn;
  final bool isEnabled;
  final void Function(EffectParameter p, num value) onSet;
  final VoidCallback onSwitch;

  num _valueOf(EffectParameter p) => values[p.algId] ?? p.defaultValue;

  @override
  Widget build(BuildContext context) {
    final touched = useState(0);
    final isEditing = useState(false);
    final controller = useTextEditingController();
    final metrics = SonicMetrics.of(context);

    // Sends [v] unless the knob already holds it.
    void set(EffectParameter p, num v) {
      if (v != _valueOf(p)) onSet(p, v);
    }

    final p = knobs.isEmpty ? null : knobs[touched.value % knobs.length];

    void commit() {
      if (!isEditing.value || p == null) return;

      isEditing.value = false;

      final v = parseSliderValue(
        controller.text,
        p.min ?? 0,
        p.max ?? 100,
        p.step ?? 1,
      );

      if (v != null) set(p, v);
    }

    Widget line() {
      if (p == null) return const SizedBox.shrink();

      final value = _valueOf(p);
      final valueStyle = metrics.knobValueStyle.copyWith(
        color: Palette.textPrimary,
      );

      return Row(
        key: const Key('piece-value'),
        mainAxisAlignment: .center,
        children: [
          Text(
            p.name,
            style: AppText.section.copyWith(color: Palette.textMuted),
          ),
          const SizedBox(width: 10),
          if (isEditing.value)
            SizedBox(
              width: 120,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): () =>
                      isEditing.value = false,
                },
                child: SonicField(
                  controller: controller,
                  autofocus: true,
                  textAlign: .center,
                  style: valueStyle,
                  isRecessed: false,
                  padding: EdgeInsets.zero,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  selectAllOnFocus: true,
                  onSubmitted: (_) => commit(),
                  onTapOutside: (_) => commit(),
                ),
              ),
            )
          else
            GestureDetector(
              behavior: .opaque,
              onTap: isEnabled
                  ? () {
                      final text = '$value';

                      controller.value = TextEditingValue(
                        text: text,
                        selection: TextSelection.collapsed(offset: text.length),
                      );
                      isEditing.value = true;
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  p.textFor(value) ?? '$value${p.unit ?? ''}',
                  style: valueStyle,
                ),
              ),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: .min,
        children: [
          // Narrower than the piece: it scales down, never overflows.
          Center(
            child: FittedBox(
              fit: .scaleDown,
              child: GearPiece(
                model: model,
                kind: kind,
                fit: pieceFit,
                knobNames: [for (final k in knobs) k.name],
                values: [for (final k in knobs) toPieceValue(k, _valueOf(k))],
                onKnob: isEnabled
                    ? (e) {
                        touched.value = e.$1;
                        set(knobs[e.$1], fromPieceValue(knobs[e.$1], e.$2));
                      }
                    : null,
                onSwitch: isEnabled ? onSwitch : null,
                lit: isOn,
              ),
            ),
          ),
          const SizedBox(height: 8),
          line(),
        ],
      ),
    );
  }
}
