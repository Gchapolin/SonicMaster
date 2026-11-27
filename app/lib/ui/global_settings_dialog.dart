import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../device/device_model.dart';
import '../l10n/common_text.dart';
import '../l10n/settings_text.dart';
import '../l10n/shell_text.dart';
import '../model/cfw_eq_models.dart';
import '../model/cfw_info.dart';
import '../model/device_capabilities.dart';
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
///
/// Wide screens (iPad landscape and up) show every section at once in three
/// columns; narrower ones stack them in one column that scrolls with the
/// dialog.
class GlobalSettingsDialog extends ConsumerWidget {
  const GlobalSettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = SettingsText.current;
    final g = ref.watch(globalSettingsProvider);
    final isLoading = ref.watch(presetLoadingProvider);
    final isConnected = ref.watch(connectionStateProvider);
    // Community custom firmware: its settings replace Backlight and the USB
    // Mode, and add the theme, Direct Monitor and the pedal mode.
    final cfw = isConnected ? ref.watch(cfwInfoProvider) : null;
    final isWide =
        !SonicMetrics.of(context).isCompact &&
        MediaQuery.sizeOf(context).width >= 1000;

    Widget body() {
      final g0 = g!;
      final levels = _Section(
        title: t.levels,
        children: [
          Row(
            mainAxisAlignment: .spaceAround,
            children: [
              _LevelKnob(
                label: t.input,
                name: 'inputLevel',
                value: g0.inputLevel,
                isLoading: isLoading,
              ),
              _LevelKnob(
                label: 'FX Rec',
                name: 'fxRecLevel',
                value: g0.fxRecLevel,
                isLoading: isLoading,
              ),
              _LevelKnob(
                label: 'BT Rec',
                name: 'btRecLevel',
                value: g0.btRecLevel,
                isLoading: isLoading,
              ),
              _LevelKnob(
                label: 'Monitor',
                name: 'monitorLevel',
                value: g0.monitorLevel,
                isLoading: isLoading,
              ),
            ],
          ),
          if (cfw == null)
            _SettingRow(
              label: t.mode,
              child: SonicSegmented<int>(
                value: g0.mode,
                width: _controlWidth,
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
              write: (v) => setCfwSetting(ref, CfwInfo.directMonitorKey, v),
            ),
            _SettingRow(
              label: 'USB Rec',
              child: SonicSegmented<int>(
                value: cfw.usbRec,
                width: 220,
                segmentPadding: 6,
                isProportional: true,
                segments: const [
                  (value: 0, label: 'Wet'),
                  (value: 1, label: 'Dry DI'),
                  (value: 2, label: 'DI L + Wet R'),
                ],
                onChanged: (v) => setCfwSetting(ref, CfwInfo.usbRecKey, v),
              ),
            ),
          ],
          _SwitchRow(
            label: 'Re-amp',
            name: 'reamp',
            value: g0.reamp,
            isLoading: isLoading,
          ),
        ],
      );
      final display = _Section(
        title: t.display,
        children: [
          Row(
            spacing: 10,
            children: [
              cfw == null
                  ? KnobControl(
                      value: g0.backlight,
                      min: 0,
                      max: 10,
                      step: 1,
                      label: t.backlight,
                      isEnabled: !isLoading,
                      isHoldToTurnOnTouch: true,
                      size: 40,
                      isDense: true,
                      onChanged: (v) =>
                          setGlobalSetting(ref, 'backlight', v.round()),
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
                      size: 40,
                      isDense: true,
                      onChanged: (v) =>
                          setCfwSetting(ref, CfwInfo.brightnessKey, v.round()),
                    ),
              Expanded(
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .stretch,
                  spacing: 4,
                  children: [
                    if (cfw != null)
                      _SettingRow(
                        label: t.theme,
                        child: SonicDropdown<int>(
                          value: cfw.theme,
                          items: _cfwThemes(t),
                          width: 150,
                          height: _controlHeight,
                          isEnabled: !isLoading,
                          onChanged: (v) =>
                              setCfwSetting(ref, CfwInfo.themeKey, v),
                        ),
                      ),
                    _SwitchRow(
                      label: 'ECO',
                      name: 'eco',
                      value: g0.eco,
                      isLoading: isLoading,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
      final footswitches = _Section(
        title: t.footswitches,
        children: [
          if (cfw != null)
            _SettingRow(
              label: t.pedalMode,
              child: SonicDropdown<int>(
                value: cfw.pedalMode,
                width: _controlWidth,
                height: _controlHeight,
                isEnabled: !isLoading,
                items: [
                  (value: 0, label: 'Preset'),
                  (value: 1, label: 'Stomp'),
                  (value: 2, label: t.scene),
                ],
                onChanged: (v) => setCfwSetting(ref, CfwInfo.pedalModeKey, v),
              ),
            ),
          _SettingRow(
            label: 'EXP/FS',
            child: SonicSegmented<int>(
              value: g0.expFsType,
              width: 200,
              segmentPadding: 6,
              isProportional: true,
              segments: const [
                (value: 0, label: 'EXP'),
                (value: 1, label: 'SingleFS'),
                (value: 2, label: 'DualFS'),
              ],
              onChanged: (v) => setGlobalSetting(ref, 'expFsType', v),
            ),
          ),
          if (g0.expFsType == 0)
            _TargetRow(
              label: t.target,
              labels: _expTargetLabels,
              value: g0.expFsTarget,
              isLoading: isLoading,
            )
          else if (g0.expFsType == 1)
            _TargetRow(
              label: t.target,
              labels: _fsTargetLabels,
              value: g0.expFsTarget,
              isLoading: isLoading,
            )
          else ...[
            _TargetRow(
              label: t.func1,
              labels: _fsTargetLabels,
              value: g0.expFsTarget,
              isLoading: isLoading,
            ),
            _TargetRow(
              label: t.func2,
              labels: _fsTargetLabels,
              value: g0.expFsTarget2,
              isLoading: isLoading,
              isFunc2: true,
            ),
          ],
        ],
      );
      final power = _Section(
        title: t.power,
        children: [
          _SwitchRow(
            label: t.battOnly,
            name: 'battOnly',
            value: g0.battOnly,
            isLoading: isLoading,
          ),
          _SwitchRow(
            label: t.confirm,
            name: 'powerConfirm',
            value: g0.powerConfirm,
            isLoading: isLoading,
          ),
        ],
      );
      final reset = _Section(title: t.reset, children: const [_ResetButton()]);
      final backup = _Section(
        title: t.wholePedal,
        children: const [CfwBackupSection()],
      );
      final columns = [
        [levels, if (cfw != null) const _GlobalEqSection()],
        // The CFW sections split so the tallest state (Custom MIDI map,
        // DualFS) still fits 1180x820; a stock pedal has only Reset left for
        // the third column.
        [display, footswitches, power, if (cfw != null) backup],
        [
          if (cfw != null) ...[
            _MidiSection(cfw: cfw, isLoading: isLoading),
            _Section(
              title: t.presetOrder,
              children: const [PresetOrderSection()],
            ),
          ],
          reset,
        ],
      ];

      if (!isWide) {
        return Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: _gap,
          children: [for (final c in columns) ...c],
        );
      }

      return Row(
        crossAxisAlignment: .start,
        spacing: 14,
        children: [
          for (final c in columns)
            Expanded(
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                spacing: _gap,
                children: c,
              ),
            ),
        ],
      );
    }

    final close = SonicButton(
      label: CommonText.current.close,
      height: isWide ? 36 : 44,
      minWidth: isWide ? 96 : 110,
      onPressed: () => Navigator.pop(context),
    );

    return SonicDialog(
      maxWidth: isWide ? 1100 : 460,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          _Header(
            cfw: cfw,
            isConnected: isConnected,
            close: isWide ? close : null,
          ),
          const SizedBox(height: 16),
          if (g == null)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  t.reading,
                  style: AppText.ui.copyWith(color: Palette.onSurfaceVariant),
                ),
              ),
            )
          else
            body(),
          if (!isWide) ...[
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerRight, child: close),
          ],
          const SizedBox(height: 12),
          const _AppCredit(),
        ],
      ),
    );
  }
}

/// The app's version and the credit to its original author (Skyggedans), in
/// a muted line at the foot of the dialog. Reads the bundle version at
/// runtime, so it tracks the pubspec.
class _AppCredit extends HookWidget {
  const _AppCredit();

  @override
  Widget build(BuildContext context) {
    final info = useFuture(useMemoized(PackageInfo.fromPlatform));
    final version = info.data?.version ?? '';
    final app = version.isEmpty ? 'SonicMaster' : 'SonicMaster $version';

    return Text(
      '$app · ${ShellText.current.byAuthor}',
      textAlign: .center,
      style: AppText.ui.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: Palette.muted,
      ),
    );
  }
}

/// Gap between two sections in a column.
const double _gap = 12;

/// Width of a row's select or two-way segmented control.
const double _controlWidth = 170;

/// Height of a row's select or button.
const double _controlHeight = 34;

/// Icon, title and CFW badge on the left; the connection dot and the device
/// model selector on the right.
class _Header extends StatelessWidget {
  const _Header({required this.cfw, required this.isConnected, this.close});

  final CfwInfo? cfw;
  final bool isConnected;

  /// The Close button, on wide screens only.
  final Widget? close;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        spacing: 12,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox.square(
              dimension: 36,
              child: Icon(Icons.tune, size: 18, color: Palette.primary),
            ),
          ),
          Text(
            SettingsText.current.title,
            style: AppText.title.copyWith(color: Palette.onSurface),
          ),
          if (cfw case final c?) _CfwBadge(c.version),
          Expanded(
            child: Row(
              mainAxisAlignment: .end,
              spacing: 8,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: isConnected ? Palette.ok : Palette.outline,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: 8),
                ),
                const Flexible(child: _DeviceModelSelector()),
                // Wide: Close sits in the header, so the grid gets the
                // footer's height and the tallest CFW state still fits.
                ?close,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled panel of settings rows, e.g. "USB" / "Display".
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: 4,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                title.toUpperCase(),
                style: AppText.section.copyWith(color: Palette.outline),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

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

    return _Section(
      title: t.globalEq,
      children: [
        _SwitchRow(
          label: t.globalEq,
          name: 'globalEq',
          value: eq.isOn ? 1 : 0,
          isLoading: isLoading,
          write: (v) => setGlobalEq(ref, eq.copyWith(isOn: v == 1)),
          leading: model == null
              ? null
              : SonicDropdown<int>(
                  value: model.wireIndex,
                  width: 150,
                  height: _controlHeight,
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
        if (model != null) ...[
          EqCurve(model: model, slots: eq.slots, isOn: eq.isOn, height: 48),
          Wrap(
            alignment: .center,
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
                  size: 44,
                  isDense: true,
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

    return _Section(
      title: 'MIDI',
      children: [
        _SettingRow(
          label: t.midiMap,
          child: SonicDropdown<int>(
            value: cfw.midiMap,
            width: _controlWidth,
            height: _controlHeight,
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
              width: _controlWidth,
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
              width: _controlWidth,
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
              height: _controlHeight,
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
            width: _controlWidth,
            fitLabels: true,
            height: _controlHeight,
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
            width: 220,
            segmentPadding: 6,
            isProportional: true,
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
            width: _controlWidth,
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.secondaryContainer),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          version.replaceFirst('CFW', 'CFW '),
          style: AppText.mono.copyWith(
            fontSize: 12,
            color: Palette.onSurfaceVariant,
          ),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: .ellipsis,
              style: AppText.ui.copyWith(color: Palette.onSurfaceVariant),
            ),
          ),
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
    this.leading,
  });

  final String label;
  final String name;
  final int value;
  final bool isLoading;

  /// Sends the new 0/1 value; null writes the stock setting [name].
  final void Function(int value)? write;

  /// A control shown before the toggle, e.g. the Global EQ model.
  final Widget? leading;

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
        child: Row(
          mainAxisSize: .min,
          spacing: 10,
          children: [
            ?leading,
            SonicToggle(
              value: value == 1,
              onChanged: isLoading ? null : (on) => set(on ? 1 : 0),
            ),
          ],
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
        width: _controlWidth,
        height: _controlHeight,
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
        height: _controlHeight,
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
      size: 40,
      isDense: true,
      onChanged: (v) => setGlobalLevel(ref, name, v.round()),
    );
  }
}

String _detectedName(
  SettingsText t,
  DeviceCapabilities? caps,
  DeviceModel detected,
) {
  if (caps == null) return t.detecting;

  return detected == .unknown ? t.unknownDevice : caps.displayName(detected);
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

    return Semantics(
      label: t.deviceModel,
      child: SonicDropdown<DeviceModel>(
        value: override ?? DeviceModel.unknown,
        height: _controlHeight,
        items: [
          (
            value: DeviceModel.unknown,
            label: '${t.auto} — ${_detectedName(t, caps, detected)}',
          ),
          (value: DeviceModel.pocketMaster, label: 'Pocket Master'),
          (value: DeviceModel.smartBox, label: 'Smart Box'),
        ],
        onChanged: (v) {
          final next = v == .unknown ? null : v;

          ref.read(deviceModelOverrideProvider.notifier).state = next;
          unawaited(ref.read(connectionPrefsProvider).saveModelOverride(next));
        },
      ),
    );
  }
}
