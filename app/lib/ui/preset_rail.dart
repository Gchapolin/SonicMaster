import 'dart:async';

import 'package:flutter/material.dart'; // Icons glyph font only
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/shell_text.dart';
import '../model/command_library.dart';
import '../model/preset_ref.dart';
import '../state/device_providers.dart';
import '../state/layout_providers.dart';
import '../state/names_providers.dart';
import '../state/preset_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'knob_control.dart';
import 'sonic_controls.dart';
import 'sonic_field.dart';
import 'sonic_metrics.dart';
import 'unsaved_changes_dialog.dart';

const railWidth = 244.0;

TextStyle _railStyle(
  double size, {
  FontWeight w = FontWeight.w500,
  Color? color,
  double ls = 0,
}) => AppText.railHeader.copyWith(
  fontSize: size,
  fontWeight: w,
  color: color ?? Palette.railText,
  letterSpacing: ls,
);

/// A compact accent "chip" for a preset slot number (e.g. P01), shown in the
/// top bar and the preset list in place of a "P01:" text prefix.
class PresetSlotChip extends StatelessWidget {
  const PresetSlotChip(this.slot, {super.key});

  final String slot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Palette.primary,
      ),
      child: Text(
        slot,
        style: AppText.railHeader.copyWith(
          color: Palette.onPrimary,
          height: 1.15,
        ),
      ),
    );
  }
}

/// One preset row in the rail's chip list: a [PresetSlotChip] plus the decoded
/// name (if any). Selected → secondaryContainer fill; disabled → dimmed, no tap.
class PresetChip extends StatelessWidget {
  const PresetChip({
    super.key,
    required this.slot,
    this.name,
    required this.isSelected,
    required this.isEnabled,
    this.onTap,
  });

  final String slot;
  final String? name;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final n = name;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.4,
        // Opaque: the whole row takes the tap, rounded corners included.
        child: GestureDetector(
          behavior: .opaque,
          onTap: isEnabled ? onTap : null,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            // The 1-px border stays (in the fill color) so the row keeps
            // its size.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isSelected
                  ? Palette.secondaryContainer
                  : Palette.surfaceContainerLow,
              border: Border.all(
                color: isSelected
                    ? Palette.secondaryContainer
                    : Palette.surfaceContainerLow,
              ),
            ),
            child: Row(
              children: [
                PresetSlotChip(slot),
                if (n != null && n.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      n,
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: _railStyle(14),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A Factory/User tab button; active → secondaryContainer fill.
class RailTab extends StatelessWidget {
  const RailTab({
    super.key,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          // The 2-px bottom edge stays (in the fill color) so the tab keeps
          // its height.
          decoration: BoxDecoration(
            color: isActive ? Palette.secondaryContainer : Palette.surface,
            border: Border(
              bottom: BorderSide(
                color: isActive ? Palette.secondaryContainer : Palette.surface,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: _railStyle(
              11,
              color: isActive
                  ? Palette.onSecondaryContainer
                  : Palette.onSurfaceVariant,
              ls: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-width rail button; primary → primary fill, else tonal.
class RailButton extends StatelessWidget {
  const RailButton({
    super.key,
    required this.label,
    this.isPrimary = false,
    this.isEnabled = true,
    this.onTap,
  });

  final String label;
  final bool isPrimary;
  final bool isEnabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isPrimary ? Palette.primary : Palette.secondaryContainer,
          ),
          child: Text(
            label.toUpperCase(),
            style: _railStyle(
              11,
              w: .w600,
              ls: 0.8,
              color: isPrimary
                  ? Palette.onPrimary
                  : Palette.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// The rail's panel: the app surface with a hairline right edge. The compact
/// preset drawer's panel wears it too.
const railDecoration = BoxDecoration(
  color: Palette.surface,
  border: Border(right: BorderSide(color: Palette.railBorder)),
);

/// Loads [preset] once the unsaved-changes check passes, closing the compact
/// preset drawer on the way (Cancel keeps both the edits and the drawer).
///
/// Pass the PAGE's [context] and [ref]: the rail and the drawer unmount on a
/// layout flip, and [loadPreset] reads its ref after every await, so a pick
/// running on theirs would throw mid-load and leave presetLoadingProvider
/// stuck at true. Master Vol writes run on the page's ref too
/// ([PresetRail.onMasterVolume]): [setGlobalVolume] reads its ref after the
/// send.
Future<void> pickPreset(
  BuildContext context,
  WidgetRef ref,
  PresetRef preset,
) async {
  if (ref.read(presetModifiedProvider) &&
      !await showUnsavedChangesDialog(context)) {
    return; // user cancelled — keep edits
  }

  if (!context.mounted) return;

  ref.read(presetDrawerOpenProvider.notifier).state = false;
  await loadPreset(ref, preset);
}

/// The left sidebar: once connected, the master-volume knob plus the tabbed,
/// searchable preset chip list; the app footer in every state. The connection
/// status and Connect/Disconnect live in the top bar ([ConnectionControls]).
/// The compact layout shows the same pieces in its preset drawer.
class PresetRail extends ConsumerWidget {
  const PresetRail({
    super.key,
    required this.onPick,
    required this.onMasterVolume,
  });

  /// Called with the tapped row's preset; the page runs [pickPreset] on it.
  final ValueChanged<PresetRef> onPick;

  /// Called with each new Master Vol level; the page runs [setGlobalVolume]
  /// on it, on its own ref (see [pickPreset]).
  final ValueChanged<int> onMasterVolume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(connectionStateProvider);

    return Container(
      width: railWidth,
      decoration: railDecoration,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          // Connect/Disconnect now lives in the top bar's device well; the rail
          // shows the master knob + preset browser only when connected.
          if (isConnected) ...[
            RailControls(onMasterVolume: onMasterVolume),
            // chip list
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: ListView(children: [PresetChipColumn(onPick: onPick)]),
              ),
            ),
          ] else
            const Spacer(),
          const RailFooter(),
        ],
      ),
    );
  }
}

/// The rail's fixed controls, top to bottom: the Master Vol knob, a hairline,
/// the Factory/User tabs and the preset search box.
class RailControls extends StatelessWidget {
  const RailControls({
    super.key,
    this.isHoldToTurnOnTouch = false,
    this.searchScrollPadding = const EdgeInsets.all(20),
    required this.onMasterVolume,
  });

  /// Passed to the Master Vol knob: true inside the compact drawer's scroll
  /// list, so a flick that starts on the knob scrolls instead of changing the
  /// live master level.
  final bool isHoldToTurnOnTouch;

  /// The search field's [SonicField.scrollPadding]. The compact drawer gives
  /// it a deep bottom, so revealing the focused field shows the matches too.
  final EdgeInsets searchScrollPadding;

  /// Called with each new Master Vol level ([PresetRail.onMasterVolume]).
  final ValueChanged<int> onMasterVolume;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        _MasterVolume(
          isHoldToTurnOnTouch: isHoldToTurnOnTouch,
          onMasterVolume: onMasterVolume,
        ),
        // thin rail divider — same hairline as the footer's top border,
        // separating the master knob from the bank selector.
        Container(height: 1, color: Palette.railBorder),
        const _BankTabs(),
        // search — a grey recessed well (rail-toned), borderless. Extra top
        // padding gives a harmonious gap below the selector.
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
          child: _PresetSearchField(scrollPadding: searchScrollPadding),
        ),
      ],
    );
  }
}

/// The master-volume knob: the pedal's global output level.
class _MasterVolume extends ConsumerWidget {
  const _MasterVolume({
    required this.isHoldToTurnOnTouch,
    required this.onMasterVolume,
  });

  final bool isHoldToTurnOnTouch;
  final ValueChanged<int> onMasterVolume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalVol = ref.watch(globalVolumeProvider);
    final isLoading = ref.watch(presetLoadingProvider);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: KnobControl(
        value: globalVol,
        min: 0,
        max: 100,
        step: 1,
        label: ShellText.current.masterVol,
        size: SonicMetrics.of(context).panelKnobSize,
        isEnabled: !isLoading,
        isHoldToTurnOnTouch: isHoldToTurnOnTouch,
        onChanged: (v) => onMasterVolume(v.round()),
      ),
    );
  }
}

/// The Factory/User bank selector.
class _BankTabs extends ConsumerWidget {
  const _BankTabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(presetTabProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: SonicSegmented<PresetBank>(
        value: tab,
        isExpanded: true,
        height: 40,
        segments: [
          (value: .factory, label: ShellText.current.factory),
          (value: .user, label: ShellText.current.user),
        ],
        onChanged: (b) => ref.read(presetTabProvider.notifier).state = b,
      ),
    );
  }
}

/// The active bank's preset rows that match the search, in slot order.
/// [currentRowKey] tags the loaded preset's row while it is listed, so the
/// compact drawer can scroll it into view.
class PresetChipColumn extends ConsumerWidget {
  const PresetChipColumn({super.key, required this.onPick, this.currentRowKey});

  /// Called with the tapped row's preset.
  final ValueChanged<PresetRef> onPick;

  /// Given to the loaded preset's row.
  final GlobalKey? currentRowKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(connectionStateProvider);
    final isLoading = ref.watch(presetLoadingProvider);
    final current = ref.watch(currentPresetProvider);
    final names = ref.watch(presetNamesProvider);
    final query = ref.watch(presetSearchProvider);
    final tab = ref.watch(presetTabProvider);
    final chips = PresetRef.all()
        .where((p) => p.bank == tab && presetMatchesQuery(p, query, names))
        .toList();

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        for (final p in chips)
          PresetChip(
            key: p == current ? currentRowKey : null,
            slot: p.label,
            name: names[p],
            isSelected: current == p,
            isEnabled: isConnected && !isLoading,
            onTap: () => onPick(p),
          ),
      ],
    );
  }
}

/// The rail's persistent footer: the app name + version and author credit,
/// pinned to the bottom of the rail in every connection state. Reads the bundle
/// version at runtime, so it tracks the pubspec without a hardcoded string.
class RailFooter extends HookWidget {
  const RailFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final info = useFuture(useMemoized(PackageInfo.fromPlatform));
    final version = info.data?.version ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.railBorder)),
      ),
      child: Column(
        children: [
          Text(
            version.isEmpty ? 'SonicMaster' : 'SonicMaster $version',
            textAlign: .center,
            style: _railStyle(11, w: .w600, ls: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            ShellText.current.byAuthor,
            textAlign: .center,
            style: _railStyle(10, color: Palette.railMuted, ls: 0.5),
          ),
        ],
      ),
    );
  }
}

/// The rail's preset search box: a rail-toned recessed well with a leading
/// search glyph and a [SonicField] that pushes typed text into
/// [presetSearchProvider] (which drives the chip-list filter).
class _PresetSearchField extends HookConsumerWidget {
  const _PresetSearchField({required this.scrollPadding});

  final EdgeInsets scrollPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Seeded from the provider: the filter outlives this field (a mode flip
    // swaps rail and drawer, a reconnect remounts the browser block), and an
    // empty box over a filtered list reads as broken. The field stays the
    // provider's only writer.
    final controller = useTextEditingController(
      text: ref.read(presetSearchProvider),
    );

    return SonicRecess(
      radius: 8,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Palette.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: SonicField(
              controller: controller,
              hintText: ShellText.current.searchPresets,
              style: AppText.input.copyWith(
                color: Palette.railText,
                fontSize: 14,
              ),
              isRecessed: false,
              padding: const EdgeInsets.symmetric(vertical: 11),
              scrollPadding: scrollPadding,
              onChanged: (v) =>
                  ref.read(presetSearchProvider.notifier).state = v,
            ),
          ),
        ],
      ),
    );
  }
}
