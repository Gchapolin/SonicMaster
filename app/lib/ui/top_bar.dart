import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart'; // Icons glyph font only
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/appearance_text.dart';
import '../l10n/common_text.dart';
import '../model/preset_ref.dart';
import '../state/cfw_providers.dart';
import '../state/device_providers.dart';
import '../state/layout_providers.dart';
import '../state/names_providers.dart';
import '../state/preset_io.dart';
import '../state/preset_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'appearance_dialog.dart';
import 'bar_preset_fields.dart';
import 'battery_chip.dart';
import 'community_presets_dialog.dart';
import 'connection_controls.dart';
import 'dsp_chip.dart';
import 'fullscreen_button.dart';
import 'global_settings_dialog.dart';
import 'preset_rail.dart';
import 'save_preset_dialog.dart';
import 'sonic_controls.dart';
import 'sonic_metrics.dart';
import 'tuner_dialog.dart';
import 'window_controls.dart';

/// The title bar's flat surface with a hairline divider along the bottom. The
/// compact preset drawer's header wears the same plate, so the open drawer
/// reads as part of the bar. The 1-px top edge stays (in the surface color) so
/// the bar's content keeps its position.
BoxDecoration get topBarDecoration => BoxDecoration(
  color: Palette.surface,
  border: Border(
    top: BorderSide(color: Palette.surface),
    bottom: BorderSide(color: Palette.outlineVariant),
  ),
);

/// Width of the compact title bar's leading slot. The compact preset drawer
/// floats its burger into this slot, above its sliding panel, so the button
/// never moves while the drawer opens or closes.
const drawerButtonSlotWidth = 48.0;

/// The SONICMASTER wordmark in the primary text colour: the regular title
/// bar's logo zone and the compact preset drawer's header.
class SonicLogo extends StatelessWidget {
  const SonicLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final base = AppText.title.copyWith(fontSize: 20, letterSpacing: -0.5);

    return SizedBox(
      height: 40,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            style: base.copyWith(
              color: Palette.textPrimary,
              fontWeight: FontWeight.w400,
            ),
            children: [
              const TextSpan(text: 'sonic'),
              TextSpan(
                text: 'master',
                style: TextStyle(
                  color: Palette.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shared flat title bar spanning the rail and the work area:
/// branding over the rail, then the loaded preset, the actions and the
/// connection well over the work area. On desktop it also drags the window and
/// carries the window controls.
///
/// Compact: 48 px tall, an empty leading slot the preset drawer floats its
/// burger into instead of the logo zone, a preset well that gives way to the
/// actions, no console toggle and a connection well without its label.
///
/// The actions run on this widget's own ref and context, so an import or a
/// connect in flight survives anything that rebuilds the page around the bar.
class TopBar extends ConsumerWidget {
  const TopBar({
    super.key,
    required this.isConsoleOpen,
    required this.onConsoleToggle,
  });

  /// Whether the debug console is docked open (tints its toggle).
  final bool isConsoleOpen;

  /// Opens or closes the debug console (debug builds only).
  final VoidCallback onConsoleToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = SonicMetrics.of(context);
    final isCompact = metrics.isCompact;
    // Regular: the prototype's 40-px icon buttons (20-px glyph), 44 tall for
    // the touch target.
    final iconPadding = isCompact
        ? metrics.topBarIconPadding
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 12);
    final iconSize = isCompact ? 22.0 : 20.0;
    final isConnected = ref.watch(connectionStateProvider);
    final current = ref.watch(currentPresetProvider);
    final isLoading = ref.watch(presetLoadingProvider);
    final state = ref.watch(currentPresetStateProvider);
    final names = ref.watch(presetNamesProvider);
    final isModified = ref.watch(presetModifiedProvider);

    final well = (isConnected && current != null)
        ? _PresetWell(
            slot: current.label,
            name: names[current] ?? '',
            isModified: isModified,
            isCompact: isCompact,
          )
        : null;

    return TopBarDragArea(
      child: SizedBox(
        height: metrics.topBarHeight,
        child: Container(
          decoration: topBarDecoration,
          child: Row(
            children: [
              // Regular: the logo zone over the rail. Compact: an empty slot
              // the preset drawer floats its burger into (the burger has to
              // sit above the drawer's panel, so it can't live in this bar).
              if (isCompact)
                const SizedBox(width: drawerButtonSlotWidth)
              else
                const _LogoZone(),
              // work-area zone — preset name aligned to the rail/work-area
              // divider, inset by the same padding as the bar's right edge;
              // connection cluster + action icons pinned right
              Expanded(
                child: Padding(
                  padding: isCompact
                      ? const EdgeInsets.only(right: 8)
                      : const EdgeInsets.symmetric(horizontal: 16),
                  // ONE flat row in both layouts whose trailing items (the
                  // actions, the gap, the connection well, the window
                  // controls) match from the end: a layout flip updates them
                  // in place, so the connection well keeps its element and
                  // its ref through a connect in flight. Never group them.
                  child: Row(
                    children: [
                      // The preset (with its arrows) gives way first: its
                      // name ellipsizes before the values or the actions.
                      Expanded(
                        child: Row(
                          children: [
                            if (well != null) ...[
                              Flexible(
                                child: _PresetStepper(
                                  current: current!,
                                  isEnabled: !isLoading,
                                  isCompact: isCompact,
                                  well: well,
                                ),
                              ),
                              SizedBox(width: isCompact ? 8 : 0),
                              const BarPresetFields(),
                            ],
                          ],
                        ),
                      ),
                      if (isCompact) const FullscreenButton(),
                      const DspChip(),
                      const BatteryChip(),
                      // The pedal's tuner, mirrored (CFW only).
                      if (isConnected && ref.watch(cfwInfoProvider) != null)
                        SonicIconButton(
                          icon: Icons.music_note,
                          size: iconSize,
                          padding: iconPadding,
                          onPressed: isLoading
                              ? null
                              : () => showSonicDialog<void>(
                                  context: context,
                                  builder: (_) => const TunerDialog(),
                                ),
                        ),
                      // The CFW community's shared presets (downloaded). Not
                      // on web: their server sends no CORS header, so a
                      // browser may not read it from another site.
                      if (!kIsWeb)
                        SonicIconButton(
                          icon: Icons.public,
                          size: iconSize,
                          padding: iconPadding,
                          onPressed: () => showSonicDialog<void>(
                            context: context,
                            builder: (_) => const CommunityPresetsDialog(),
                          ),
                        ),
                      // Phones have no room (14 px short at 568x320): they reach
                      // Appearance from the preset drawer instead.
                      if (!isCompact || MediaQuery.sizeOf(context).width >= 700)
                        Semantics(
                          label: AppearanceText.current.title,
                          button: true,
                          excludeSemantics: true,
                          child: SonicIconButton(
                            icon: Icons.palette,
                            size: iconSize,
                            padding: iconPadding,
                            onPressed: () => showAppearanceDialog(context),
                          ),
                        ),
                      SonicIconButton(
                        icon: Icons.tune,
                        size: iconSize,
                        padding: iconPadding,
                        onPressed: (isConnected && !isLoading)
                            ? () {
                                refreshGlobalSettings(ref);
                                refreshGlobalEq(ref);
                                showSonicDialog<void>(
                                  context: context,
                                  builder: (_) => const GlobalSettingsDialog(),
                                );
                              }
                            : null,
                      ),
                      // Export writes the preset out to a file on disk (arrow
                      // down, "save"); import reads a file in and pushes it to
                      // the pedal (arrow up).
                      SonicIconButton(
                        icon: Icons.file_download,
                        size: iconSize,
                        padding: iconPadding,
                        onPressed: (isConnected && state != null)
                            ? () => exportPreset(ref)
                            : null,
                      ),
                      SonicIconButton(
                        icon: Icons.file_upload,
                        size: iconSize,
                        padding: iconPadding,
                        onPressed: (isConnected && !isLoading)
                            ? () => importPreset(ref)
                            : null,
                      ),
                      _SaveButton(
                        isCompact: isCompact,
                        onPressed:
                            (isConnected && !isLoading && current != null)
                            ? () => showSavePresetDialog(context)
                            : null,
                      ),
                      // Developer/protocol-RE console — debug builds only. It
                      // streams raw MIDI and writes a capture log to disk, so it
                      // must never ship in a release build. The compact page
                      // has no room to dock it.
                      if (kDebugMode && !isCompact)
                        SonicIconButton(
                          icon: Icons.terminal,
                          size: iconSize,
                          padding: iconPadding,
                          color: isConsoleOpen ? Palette.accent : null,
                          onPressed: onConsoleToggle,
                        ),
                      SizedBox(width: isCompact ? 8 : 6),
                      // Connection status, pinned to the right edge.
                      // Regular: the prototype's dot + device name after a
                      // hairline; the whole status (the bar's height) opens
                      // the Desconectar menu, or connects while disconnected.
                      // Compact: the recessed well, stretched to the bar's
                      // height, connects while disconnected (the 26-px button
                      // alone is small for a finger); Disconnect stays on its
                      // button. The same widgets in every layout and state,
                      // so ConnectionControls keeps its element and its ref
                      // through connects, disconnects and mode flips.
                      SonicHitArea(
                        onTap: isCompact
                            ? connectAction(context, ref)
                            : deviceStatusAction(context, ref),
                        child: SizedBox(
                          height: double.infinity,
                          child: Center(
                            widthFactor: 1,
                            child: Container(
                              padding: isCompact
                                  ? const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    )
                                  : const EdgeInsets.only(left: 12),
                              decoration: isCompact
                                  ? BoxDecoration(
                                      color: Palette.surfaceContainerHigh,
                                      border: Border.all(
                                        color: Palette.outline,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : BoxDecoration(
                                      border: Border(
                                        left: BorderSide(
                                          color: Palette.outlineVariant,
                                        ),
                                      ),
                                    ),
                              child: ConnectionControls(
                                hasStatusLabel: !isCompact,
                                isStatusOnly: !isCompact,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isDesktopWindow) const SizedBox(width: 8),
                      if (isDesktopWindow) const WindowControls(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The regular bar's branding zone: the logo at its own width, as in the
/// prototype (its 16-px inset, then a 20-px gap to the preset arrows).
class _LogoZone extends StatelessWidget {
  const _LogoZone();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 4),
      alignment: Alignment.centerLeft,
      child: const SonicLogo(),
    );
  }
}

/// The phone's quick preset selector: the loaded preset between a previous
/// and a next arrow. The arrows load the neighbour in the same bank (wrapping
/// at the ends, after the unsaved-changes question); tapping the preset opens
/// the preset list.
class _PresetStepper extends ConsumerWidget {
  const _PresetStepper({
    required this.current,
    required this.isEnabled,
    required this.isCompact,
    required this.well,
  });

  final PresetRef current;
  final bool isEnabled;
  final bool isCompact;
  final Widget well;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Regular: the prototype's 36-px filled buttons, inside 44-pt targets.
    Widget arrow(IconData icon, int by) {
      final onPressed = isEnabled
          ? () => pickPreset(context, ref, current.neighbour(by))
          : null;

      if (isCompact) {
        return SonicIconButton(
          icon: icon,
          size: 20,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
          onPressed: onPressed,
        );
      }

      return SonicHitArea(
        onTap: onPressed,
        padding: const EdgeInsets.all(4),
        child: Opacity(
          opacity: isEnabled ? 1 : 0.4,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Palette.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Palette.onSurfaceVariant),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: .min,
      children: [
        arrow(Icons.chevron_left, -1),
        SizedBox(width: isCompact ? 0 : 6),
        Flexible(
          child: SonicHitArea(
            onTap: () =>
                ref.read(presetDrawerOpenProvider.notifier).state = true,
            child: well,
          ),
        ),
        SizedBox(width: isCompact ? 0 : 6),
        arrow(Icons.chevron_right, 1),
      ],
    );
  }
}

/// The loaded preset in the prototype's pill: a 36-px filled control (230
/// wide in regular) with the slot code in mono accent, the decoded name (if
/// any) and the unsaved-edits marker.
class _PresetWell extends StatelessWidget {
  const _PresetWell({
    required this.slot,
    required this.name,
    required this.isModified,
    required this.isCompact,
  });

  static const pillKey = ValueKey('preset-pill');

  final String slot;
  final String name;
  final bool isModified;

  /// Compact: the pill takes its natural width; regular is 230 wide.
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final nameStyle = AppText.uiStrong.copyWith(color: Palette.textPrimary);

    return Container(
      key: pillKey,
      width: isCompact ? null : 230,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Palette.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          Text(slot, style: AppText.mono.copyWith(color: Palette.primary)),
          if (name.isNotEmpty) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: .ellipsis,
                style: nameStyle,
              ),
            ),
          ],
          // Unsaved-edits marker, kept outside the ellipsizing name so a long
          // name can't truncate it. "✱" is not in Inter: the forced strut
          // keeps its fallback face's taller line from growing the pill.
          if (isModified) ...[
            const SizedBox(width: 6),
            Text(
              '✱',
              strutStyle: StrutStyle.fromTextStyle(
                nameStyle,
                forceStrutHeight: true,
              ),
              style: nameStyle,
            ),
          ],
        ],
      ),
    );
  }
}

/// The primary Save button: accent fill, on-accent icon and label (the label
/// drops on the compact bar, where only the icon fits).
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.isCompact, required this.onPressed});

  final bool isCompact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 0 : 4),
      child: MouseRegion(
        cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          key: const ValueKey('save-button'),
          behavior: .opaque,
          onTap: onPressed,
          // Compact: the 38x46 touch target the bar's icons share.
          child: SizedBox(
            width: isCompact ? 38 : null,
            height: isCompact ? 46 : null,
            child: Center(
              child: Opacity(
                opacity: isEnabled ? 1 : 0.4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Palette.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 8 : 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: .min,
                      children: [
                        Icon(Icons.save, size: 18, color: Palette.onPrimary),
                        if (!isCompact) ...[
                          const SizedBox(width: 6),
                          Text(
                            CommonText.current.save,
                            style: AppText.ui.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Palette.onPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
