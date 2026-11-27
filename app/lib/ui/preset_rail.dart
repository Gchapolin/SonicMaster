import 'dart:async';

import 'package:flutter/material.dart'; // Icons glyph font only
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
import 'sonic_field.dart';
import 'unsaved_changes_dialog.dart';

/// The regular preset rail (and the bar's logo zone above it): the
/// prototype's 210-px aside (N_Principal.dc.html), so the nine-unit pedalboard
/// fits one row from a 1180-px window (iPad A16 landscape).
const railWidth = 210.0;

/// The compact slide-in preset drawer, unchanged from the old rail width.
const drawerWidth = 244.0;

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
/// name (if any). Selected → raised fill with an accent border; disabled → dimmed, no tap.
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
                  ? Palette.surfaceContainerHigh
                  : Palette.surface,
              border: Border.all(
                color: isSelected ? Palette.primary : Palette.surface,
              ),
            ),
            child: Row(
              children: [
                Text(
                  slot,
                  style: AppText.mono.copyWith(
                    fontSize: 12,
                    color: Palette.primary,
                  ),
                ),
                if (n != null && n.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      n,
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: AppText.ui.copyWith(
                        color: isSelected
                            ? Palette.onSurface
                            : Palette.railText,
                      ),
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
BoxDecoration get railDecoration => BoxDecoration(
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

/// The left sidebar (prototype N_Principal): once connected, the tabbed,
/// searchable preset chip list over the compact master-volume row. The
/// connection status and Connect/Disconnect live in the top bar
/// ([ConnectionControls]); the version and credit in Ajustes. The compact
/// layout shows the same pieces in its preset drawer.
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
            const RailControls(),
            // chip list
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: ListView(children: [PresetChipColumn(onPick: onPick)]),
              ),
            ),
            MasterVolumeRow(onMasterVolume: onMasterVolume),
          ],
        ],
      ),
    );
  }
}

/// The rail's fixed controls, top to bottom: the Fábrica/Usuário segments
/// and the preset search box.
class RailControls extends StatelessWidget {
  const RailControls({
    super.key,
    this.searchScrollPadding = const EdgeInsets.all(20),
  });

  /// The search field's [SonicField.scrollPadding]. The compact drawer gives
  /// it a deep bottom, so revealing the focused field shows the matches too.
  final EdgeInsets searchScrollPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        const _BankTabs(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: _PresetSearchField(scrollPadding: searchScrollPadding),
        ),
      ],
    );
  }
}

/// The rail's bottom row: a small master-volume knob (the pedal's global
/// output level) beside its caption and value, under a hairline.
class MasterVolumeRow extends ConsumerWidget {
  const MasterVolumeRow({
    super.key,
    this.isHoldToTurnOnTouch = false,
    required this.onMasterVolume,
  });

  /// Passed to the knob: true inside the compact drawer's scroll list, so a
  /// flick that starts on the knob scrolls instead of changing the live
  /// master level.
  final bool isHoldToTurnOnTouch;

  /// Called with each new Master Vol level ([PresetRail.onMasterVolume]).
  final ValueChanged<int> onMasterVolume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalVol = ref.watch(globalVolumeProvider);
    final isLoading = ref.watch(presetLoadingProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Palette.railBorder)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: KnobControl(
          value: globalVol,
          min: 0,
          max: 100,
          step: 1,
          label: ShellText.current.masterVol,
          size: 44,
          isEnabled: !isLoading,
          isInline: true,
          isHoldToTurnOnTouch: isHoldToTurnOnTouch,
          onChanged: (v) => onMasterVolume(v.round()),
        ),
      ),
    );
  }
}

/// The Fábrica/Usuário bank selector: the prototype's filled track (3-px
/// inset, 2-px gap) with sentence-case labels. Each segment's tap target
/// takes the track's margins too, so it is 44 tall.
class _BankTabs extends ConsumerWidget {
  const _BankTabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(presetTabProvider);

    Widget segment(PresetBank bank, String label) {
      final isActive = bank == tab;

      return Expanded(
        child: GestureDetector(
          behavior: .opaque,
          onTap: () => ref.read(presetTabProvider.notifier).state = bank,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Container(
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? Palette.secondaryContainer : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                maxLines: 1,
                style: AppText.ui.copyWith(
                  color: isActive
                      ? Palette.onSecondaryContainer
                      : Palette.muted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Stack(
        children: [
          Positioned.fill(
            top: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Row(
              spacing: 2,
              children: [
                segment(.factory, ShellText.current.factory),
                segment(.user, ShellText.current.user),
              ],
            ),
          ),
        ],
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

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Palette.field,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 15, color: Palette.muted),
          const SizedBox(width: 8),
          Expanded(
            child: SonicField(
              controller: controller,
              hintText: ShellText.current.searchPresets,
              style: AppText.ui.copyWith(
                fontWeight: FontWeight.w400,
                color: Palette.railText,
              ),
              isRecessed: false,
              padding: EdgeInsets.zero,
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
