import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device/device_model.dart';
import '../l10n/common_text.dart';
import '../l10n/settings_text.dart';
import '../model/cfw_eq_models.dart';
import '../model/cfw_info.dart';
import '../state/cfw_providers.dart';
import '../state/connection_prefs.dart';
import '../state/data_providers.dart';
import '../state/device_providers.dart';
import '../state/preset_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'cfw_backup_section.dart';
import 'eq_curve_view.dart';
import 'knob_control.dart';
import 'midi_map_dialog.dart';
import 'preset_order_section.dart';
import 'sonic_controls.dart';
import 'sonic_metrics.dart';

/// EXP/FS Target labels, indexed by wire value. EXP mode uses [_expTargetLabels]
/// (reg 0x17); SingleFS and DualFS use [_fsTargetLabels] (reg 0x16).
const _expTargetLabels = <String>[
  'VOL',
  'FX1',
  'DRV',
  'AMP',
  'IR',
  'FX2',
  'DLY',
  'RVB',
];

List<String> get _fsTargetLabels => [
  // Only Tuner reads differently in Portuguese; the rest are the
  // pedal's own names.
  'Preset-',
  'Preset+',
  'Tap Tempo',
  'NR',
  'FX1',
  'DRV',
  'AMP',
  'IR',
  'EQ',
  'FX2',
  'DLY',
  'RVB',
  'CTRL 1',
  'CTRL 2',
  'Drum',
  'REC/Play',
  'Loop Stop',
  SettingsText.current.tuner,
];

/// Device-global settings, mirroring the Android app's Settings screen: the four
/// dB level knobs plus Mode / Re-amp / EXP-FS Type / Backlight / ECO / Power, and
/// the app-side device-model selector. All device writes are synthesized frames.
class GlobalSettingsDialog extends ConsumerWidget {
  const GlobalSettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = SettingsText.current;
    final g = ref.watch(globalSettingsProvider);
    final isLoading = ref.watch(presetLoadingProvider);
    // Community custom firmware: its settings replace Backlight and the USB
    // Mode, and add the theme, Direct Monitor and the pedal mode.
    final cfw = ref.watch(connectionStateProvider)
        ? ref.watch(cfwInfoProvider)
        : null;

    return SonicDialog(
      maxWidth: 440,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.title, style: AppText.dialogTitle)),
              if (cfw != null) _CfwBadge(cfw.version),
            ],
          ),
          const SizedBox(height: 8),
          if (g == null)
            SizedBox(
              height: 120,
              child: Center(child: Text(t.reading, style: AppText.dialogBody)),
            )
          else
            // Regular: the list scrolls under a 62% cap and Close stays
            // pinned below it (the desktop look). Compact (phones): no cap,
            // so this scroll view is a passthrough and SonicDialog's own
            // scroll carries title, settings and Close as one list at any
            // height. Only the cap differs, so a flip never remounts it.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: SonicMetrics.of(context).isCompact
                    ? double.infinity
                    : MediaQuery.sizeOf(context).height * 0.62,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .stretch,
                  children: [
                    _SectionHeader(t.levels),
                    Row(
                      mainAxisAlignment: .spaceBetween,
                      children: [
                        _LevelKnob(
                          label: t.input,
                          name: 'inputLevel',
                          value: g.inputLevel,
                          isLoading: isLoading,
                        ),
                        _LevelKnob(
                          label: 'FX Rec',
                          name: 'fxRecLevel',
                          value: g.fxRecLevel,
                          isLoading: isLoading,
                        ),
                        _LevelKnob(
                          label: 'BT Rec',
                          name: 'btRecLevel',
                          value: g.btRecLevel,
                          isLoading: isLoading,
                        ),
                        _LevelKnob(
                          label: 'Monitor',
                          name: 'monitorLevel',
                          value: g.monitorLevel,
                          isLoading: isLoading,
                        ),
                      ],
                    ),
                    const _SectionHeader('USB'),
                    if (cfw == null)
                      _SettingRow(
                        label: t.mode,
                        child: SonicSegmented<int>(
                          value: g.mode,
                          segments: const [
                            (value: 0, label: 'Dry'),
                            (value: 1, label: 'Wet'),
                          ],
                          onChanged: (v) => setGlobalSetting(ref, 'mode', v),
                        ),
                      )
                    else ...[
                      _SwitchRow(
                        label: t.directMonitor,
                        name: 'directMonitor',
                        value: cfw.directMonitor ? 1 : 0,
                        isLoading: isLoading,
                        write: (v) =>
                            setCfwSetting(ref, CfwInfo.directMonitorKey, v),
                      ),
                      _SettingRow(
                        label: 'USB Rec',
                        child: SonicSegmented<int>(
                          value: cfw.usbRec,
                          segments: const [
                            (value: 0, label: 'Wet'),
                            (value: 1, label: 'Dry DI'),
                            (value: 2, label: 'DI L + Wet R'),
                          ],
                          onChanged: (v) =>
                              setCfwSetting(ref, CfwInfo.usbRecKey, v),
                        ),
                      ),
                    ],
                    _SwitchRow(
                      label: 'Re-amp',
                      name: 'reamp',
                      value: g.reamp,
                      isLoading: isLoading,
                    ),
                    const _SectionHeader('EXP/FS'),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: .stretch,
                        mainAxisSize: .min,
                        children: [
                          Text(t.type, style: AppText.dialogBody),
                          const SizedBox(height: 6),
                          SonicSegmented<int>(
                            value: g.expFsType,
                            isExpanded: true,
                            segments: const [
                              (value: 0, label: 'EXP'),
                              (value: 1, label: 'SingleFS'),
                              (value: 2, label: 'DualFS'),
                            ],
                            onChanged: (v) =>
                                setGlobalSetting(ref, 'expFsType', v),
                          ),
                        ],
                      ),
                    ),
                    if (g.expFsType == 0)
                      _TargetRow(
                        label: t.target,
                        labels: _expTargetLabels,
                        value: g.expFsTarget,
                        isLoading: isLoading,
                      )
                    else if (g.expFsType == 1)
                      _TargetRow(
                        label: t.target,
                        labels: _fsTargetLabels,
                        value: g.expFsTarget,
                        isLoading: isLoading,
                      )
                    else ...[
                      _TargetRow(
                        label: t.func1,
                        labels: _fsTargetLabels,
                        value: g.expFsTarget,
                        isLoading: isLoading,
                      ),
                      _TargetRow(
                        label: t.func2,
                        labels: _fsTargetLabels,
                        value: g.expFsTarget2,
                        isLoading: isLoading,
                        isFunc2: true,
                      ),
                    ],
                    if (cfw != null) const _GlobalEqSection(),
                    _SectionHeader(t.display),
                    if (cfw != null)
                      _SettingRow(
                        label: t.theme,
                        child: SonicDropdown<int>(
                          value: cfw.theme,
                          items: _cfwThemes(t),
                          isEnabled: !isLoading,
                          onChanged: (v) =>
                              setCfwSetting(ref, CfwInfo.themeKey, v),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Align(
                        alignment: .centerLeft,
                        child: cfw == null
                            ? KnobControl(
                                value: g.backlight,
                                min: 0,
                                max: 10,
                                step: 1,
                                label: t.backlight,
                                isEnabled: !isLoading,
                                isHoldToTurnOnTouch: true,
                                size: 60,
                                onChanged: (v) => setGlobalSetting(
                                  ref,
                                  'backlight',
                                  v.round(),
                                ),
                              )
                            : KnobControl(
                                value: cfw.brightness.clamp(10, 100),
                                min: 10,
                                max: 100,
                                step: 1,
                                unit: '%',
                                label: t.brightness,
                                isEnabled: !isLoading,
                                isHoldToTurnOnTouch: true,
                                size: 60,
                                onChanged: (v) => setCfwSetting(
                                  ref,
                                  CfwInfo.brightnessKey,
                                  v.round(),
                                ),
                              ),
                      ),
                    ),
                    _SwitchRow(
                      label: 'ECO',
                      name: 'eco',
                      value: g.eco,
                      isLoading: isLoading,
                    ),
                    if (cfw != null)
                      _MidiSection(cfw: cfw, isLoading: isLoading),
                    if (cfw != null) ...[
                      _SectionHeader(t.footswitches),
                      _SettingRow(
                        label: t.pedalMode,
                        child: SonicSegmented<int>(
                          value: cfw.pedalMode,
                          segments: [
                            (value: 0, label: 'Preset'),
                            (value: 1, label: 'Stomp'),
                            (value: 2, label: t.scene),
                          ],
                          onChanged: (v) =>
                              setCfwSetting(ref, CfwInfo.pedalModeKey, v),
                        ),
                      ),
                    ],
                    if (cfw != null) ...[
                      _SectionHeader(t.presetOrder),
                      const PresetOrderSection(),
                      _SectionHeader(t.wholePedal),
                      const CfwBackupSection(),
                    ],
                    _SectionHeader(t.power),
                    _SwitchRow(
                      label: t.confirm,
                      name: 'powerConfirm',
                      value: g.powerConfirm,
                      isLoading: isLoading,
                    ),
                    _SwitchRow(
                      label: t.battOnly,
                      name: 'battOnly',
                      value: g.battOnly,
                      isLoading: isLoading,
                    ),
                    _SectionHeader(t.reset),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: _ResetButton(),
                    ),
                    const SizedBox(height: 16),
                    const _DeviceModelSelector(),
                  ],
                ),
              ),
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

/// A small uppercase group header, e.g. "USB" / "Display".
/// The CFW Global EQ: one EQ after the whole chain, for every preset. Shows
/// the switch, the model and the model's knobs; a model this app has no data
/// for shows only the switch.
class _GlobalEqSection extends ConsumerWidget {
  const _GlobalEqSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = SettingsText.current;
    final eq = ref.watch(globalEqProvider);
    final models = ref.watch(cfwEqModelsProvider).valueOrNull ?? const [];
    final isLoading = ref.watch(presetLoadingProvider);

    if (eq == null) return const SizedBox.shrink();

    final model = models
        .where((m) => m.wireIndex == eq.model)
        .cast<CfwEqModel?>()
        .firstWhere((_) => true, orElse: () => null);

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        _SectionHeader(t.globalEq),
        _SwitchRow(
          label: t.globalEq,
          name: 'globalEq',
          value: eq.isOn ? 1 : 0,
          isLoading: isLoading,
          write: (v) => setGlobalEq(ref, eq.copyWith(isOn: v == 1)),
        ),
        if (model != null) ...[
          _SettingRow(
            label: t.model,
            child: SonicDropdown<int>(
              value: model.wireIndex,
              items: [
                for (final m in models) (value: m.wireIndex, label: m.name),
              ],
              isEnabled: !isLoading,
              onChanged: (v) {
                final next = models.firstWhere((m) => m.wireIndex == v);

                setGlobalEq(
                  ref,
                  eq.copyWith(model: v, slots: next.defaultSlots()),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: EqCurve(model: model, slots: eq.slots, isOn: eq.isOn),
          ),
          Wrap(
            children: [
              for (final p in model.params)
                KnobControl(
                  value: p.fromSlot(eq.slots[p.algId]).clamp(p.min, p.max),
                  min: p.min,
                  max: p.max,
                  step: p.step,
                  label: p.name,
                  valueText: p.textFor(
                    p.fromSlot(eq.slots[p.algId]).clamp(p.min, p.max),
                  ),
                  isEnabled: !isLoading,
                  isHoldToTurnOnTouch: true,
                  size: 60,
                  onChanged: (v) =>
                      setGlobalEq(ref, eq.withSlot(p.algId, p.toSlot(v))),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The CFW MIDI settings: map, channel, what a repeated preset message does,
/// tempo scope and drum sync; the Custom map adds its two options.
class _MidiSection extends ConsumerWidget {
  const _MidiSection({required this.cfw, required this.isLoading});

  final CfwInfo cfw;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = SettingsText.current;
    void set(int key, int value) => setCfwSetting(ref, key, value);
    final options = cfw.customMapOptions;

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        const _SectionHeader('MIDI'),
        _SettingRow(
          label: t.midiMap,
          child: SonicDropdown<int>(
            value: cfw.midiMap,
            items: [
              (value: 0, label: t.mapStock),
              (value: 3, label: 'Chocolate'),
              (value: 2, label: t.mapGeneric),
              (value: 1, label: t.mapCustom),
            ],
            isEnabled: !isLoading,
            onChanged: (v) => set(CfwInfo.midiMapKey, v),
          ),
        ),
        if (cfw.midiMap == CfwInfo.customMap) ...[
          _SettingRow(
            label: t.firstPc,
            child: SonicSegmented<int>(
              value: options & 1,
              segments: const [
                (value: 0, label: 'PC 0'),
                (value: 1, label: 'PC 1'),
              ],
              onChanged: (v) =>
                  set(CfwInfo.customMapOptionsKey, (options & ~1) | v),
            ),
          ),
          _SettingRow(
            label: t.levelCcRange,
            child: SonicSegmented<int>(
              value: options & 2,
              segments: const [
                (value: 0, label: '0..100'),
                (value: 2, label: '0..127'),
              ],
              onChanged: (v) =>
                  set(CfwInfo.customMapOptionsKey, (options & ~2) | v),
            ),
          ),
        ],
        if (cfw.midiMap == CfwInfo.customMap)
          _SettingRow(
            label: t.customMapRows,
            child: SonicButton(
              label: t.editMap,
              onPressed: isLoading
                  ? null
                  : () => showSonicDialog<void>(
                      context: context,
                      builder: (_) => const MidiMapDialog(),
                    ),
            ),
          ),
        _SettingRow(
          label: t.midiChannel,
          child: SonicDropdown<int>(
            value: cfw.midiChannel,
            items: [
              (value: 0, label: t.allChannels),
              for (var ch = 1; ch <= 16; ch++)
                (value: ch, label: t.channel(ch)),
            ],
            isEnabled: !isLoading,
            onChanged: (v) => set(CfwInfo.midiChannelKey, v),
          ),
        ),
        _SettingRow(
          label: t.sameAgain,
          child: SonicSegmented<int>(
            value: cfw.sameAgain,
            segments: [
              (value: 0, label: t.off),
              (value: 1, label: t.cycle),
              (value: 2, label: t.back),
            ],
            onChanged: (v) => set(CfwInfo.sameAgainKey, v),
          ),
        ),
        _SettingRow(
          label: t.tempoScope,
          child: SonicSegmented<int>(
            value: cfw.tempoScope,
            segments: const [
              (value: 0, label: 'Preset'),
              (value: 1, label: 'Global'),
            ],
            onChanged: (v) => set(CfwInfo.tempoScopeKey, v),
          ),
        ),
        _SwitchRow(
          label: t.drumSync,
          name: 'drumSync',
          value: cfw.drumSync ? 1 : 0,
          isLoading: isLoading,
          write: (v) => set(CfwInfo.drumSyncKey, v),
        ),
      ],
    );
  }
}

/// The CFW screen themes, in the pedal's order.
List<SonicItem<int>> _cfwThemes(SettingsText t) => [
  (value: 0, label: t.themeDefault),
  (value: 1, label: 'Amber CRT'),
  (value: 2, label: 'Tube Amp'),
  (value: 3, label: 'Synthwave'),
  (value: 4, label: 'Stage Hi-Contrast'),
  (value: 5, label: 'Game Boy'),
];

/// The firmware version badge (e.g. "CFW 1.0.2") in the dialog title.
class _CfwBadge extends StatelessWidget {
  const _CfwBadge(this.version);

  final String version;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Palette.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          version.replaceFirst('CFW', 'CFW '),
          style: AppText.dialogBody.copyWith(color: Palette.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: AppText.controlLabel.copyWith(
          color: Palette.textDim,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// A label on the left and a trailing [child] control on the right.
class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.dialogBody)),
          child,
        ],
      ),
    );
  }
}

/// A labelled on/off [SonicToggle] wired to [setGlobalSetting] (0/1). Disabled
/// while a device read is in flight.
class _SwitchRow extends ConsumerWidget {
  const _SwitchRow({
    required this.label,
    required this.name,
    required this.value,
    required this.isLoading,
    this.write,
  });

  final String label;
  final String name;
  final int value;
  final bool isLoading;

  /// Sends the new 0/1 value; null writes the stock setting [name].
  final void Function(int value)? write;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void set(int v) =>
        write != null ? write!(v) : setGlobalSetting(ref, name, v);
    void flip() => set(value == 1 ? 0 : 1);

    // Compact (touch): the whole row, label included, flips the switch; the
    // 26-px toggle alone is a small target for a finger. Regular leaves the
    // row inert, so only the toggle reacts, as before.
    return SonicHitArea(
      onTap: SonicMetrics.of(context).isCompact && !isLoading ? flip : null,
      child: _SettingRow(
        label: label,
        child: SonicToggle(
          value: value == 1,
          onChanged: isLoading ? null : (on) => set(on ? 1 : 0),
        ),
      ),
    );
  }
}

/// An EXP/FS Target dropdown wired to [setExpFsTarget]. [labels] indexes the wire
/// value; [isFunc2] selects the DualFS second slot.
class _TargetRow extends ConsumerWidget {
  const _TargetRow({
    required this.label,
    required this.labels,
    required this.value,
    required this.isLoading,
    this.isFunc2 = false,
  });

  final String label;
  final List<String> labels;
  final int value;
  final bool isLoading;
  final bool isFunc2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      for (final (i, name) in labels.indexed) (value: i, label: name),
    ];

    return _SettingRow(
      label: label,
      child: SonicDropdown<int>(
        value: value.clamp(0, labels.length - 1),
        items: items,
        width: 156,
        isEnabled: !isLoading,
        onChanged: (v) => setExpFsTarget(ref, v, isFunc2: isFunc2),
      ),
    );
  }
}

/// "Reset to factory settings" button, gated behind a confirmation dialog so it
/// can't be triggered by accident. Sends the reset command, after which the pedal
/// reboots and disconnects.
class _ResetButton extends ConsumerWidget {
  const _ResetButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: .centerLeft,
      child: SonicButton(
        label: SettingsText.current.resetButton,
        onPressed: () => _confirm(context, ref),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final t = SettingsText.current;
    final isConfirmed = await showSonicDialog<bool>(
      context: context,
      builder: (dialogContext) => SonicDialog(
        maxWidth: 360,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            Text(t.resetTitle, style: AppText.dialogTitle),
            const SizedBox(height: 12),
            Text(t.resetBody, style: AppText.dialogBody),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: .end,
              children: [
                SonicButton(
                  label: CommonText.current.cancel,
                  onPressed: () => Navigator.pop(dialogContext, false),
                ),
                const SizedBox(width: 10),
                SonicButton(
                  label: t.resetConfirm,
                  isAccent: true,
                  onPressed: () => Navigator.pop(dialogContext, true),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (isConfirmed == true) await factoryReset(ref);
  }
}

/// One −20..20 dB rotary level knob wired to [setGlobalLevel].
class _LevelKnob extends ConsumerWidget {
  const _LevelKnob({
    required this.label,
    required this.name,
    required this.value,
    required this.isLoading,
  });

  final String label;
  final String name;
  final int value;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KnobControl(
      value: value,
      min: -20,
      max: 20,
      step: 1,
      label: label,
      unit: ' dB',
      isEnabled: !isLoading,
      isHoldToTurnOnTouch: true,
      size: 72,
      onChanged: (v) => setGlobalLevel(ref, name, v.round()),
    );
  }
}

/// Auto / Pocket Master / Smart Box model selector. "Auto" (null override)
/// follows detection and shows the detected model; picking a model manually
/// overrides detection and persists across launches.
class _DeviceModelSelector extends ConsumerWidget {
  const _DeviceModelSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = SettingsText.current;
    final override = ref.watch(deviceModelOverrideProvider);
    final detected = ref.watch(detectedDeviceModelProvider);
    final caps = ref.watch(dataAssetsProvider).valueOrNull?.capabilities;
    final hint = override == null
        ? 'Auto — ${caps?.displayName(detected) ?? t.detecting}'
        : t.manual;

    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      children: [
        Row(
          children: [
            Text(t.deviceModel, style: AppText.dialogBody),
            const Spacer(),
            Text(
              hint,
              style: AppText.dialogBody.copyWith(color: Palette.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SonicSegmented<DeviceModel>(
          value: override ?? DeviceModel.unknown,
          isExpanded: true,
          segments: const [
            (value: DeviceModel.unknown, label: 'Auto'),
            (value: DeviceModel.pocketMaster, label: 'Pocket Master'),
            (value: DeviceModel.smartBox, label: 'Smart Box'),
          ],
          onChanged: (v) {
            final next = v == .unknown ? null : v;

            ref.read(deviceModelOverrideProvider.notifier).state = next;
            unawaited(
              ref.read(connectionPrefsProvider).saveModelOverride(next),
            );
          },
        ),
      ],
    );
  }
}
