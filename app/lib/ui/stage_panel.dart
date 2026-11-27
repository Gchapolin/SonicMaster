import 'package:flutter/material.dart'; // Icons glyph font only
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/connection_text.dart';
import '../l10n/shell_text.dart';
import '../model/command_library.dart';
import '../model/preset_ref.dart';
import '../state/device_providers.dart';
import '../state/names_providers.dart';
import '../state/preset_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'connection_controls.dart';
import 'sonic_controls.dart';

/// Height of one preset row: a comfortable finger target mid-song.
const _rowHeight = 52.0;

/// Stage mode ([isStageViewport]): the narrow Slide Over window a musician
/// pulls over a sheet-music app to switch preset with one tap. The loaded
/// preset, big Previous/Next buttons and the current bank's presets.
///
/// [onPick] is the page's pick (see [pickPreset]): it asks about unsaved edits
/// and loads on the page's ref.
class StagePanel extends HookConsumerWidget {
  const StagePanel({super.key, required this.onPick});

  final ValueChanged<PresetRef> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(connectionStateProvider);
    final deviceName = ref.watch(connectedDeviceNameProvider);
    final current = ref.watch(currentPresetProvider);
    final names = ref.watch(presetNamesProvider);
    final isModified = ref.watch(presetModifiedProvider);
    final isLoading = ref.watch(presetLoadingProvider);
    final PresetBank bank = current?.bank ?? ref.watch(presetTabProvider);
    final isEnabled = isConnected && !isLoading;
    final scroll = useScrollController();

    // Keep the loaded preset's row about a third down the list.
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (current == null || !scroll.hasClients) return;

        final p = scroll.position;
        final offset =
            (current.number - 1) * _rowHeight - p.viewportDimension / 3;

        scroll.jumpTo(offset.clamp(p.minScrollExtent, p.maxScrollExtent));
      });

      return null;
    }, [current]);

    final status = isConnected
        ? (deviceName ?? ConnectionText.current.connected)
        : ConnectionText.current.disconnected;
    final nameStyle = AppText.ui.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w600,
      height: 1.15,
      color: Palette.onSurface,
    );

    return ColoredBox(
      color: Palette.background,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Row(
              spacing: 8,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: .circle,
                    color: isConnected ? Palette.ok : Palette.ledDisconnected,
                  ),
                ),
                Expanded(
                  child: Text(
                    '$status · ${ShellText.current.stageMode}',
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: AppText.ui.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Palette.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!isConnected) ...[
              Text(
                ShellText.current.noDeviceConnected,
                style: AppText.dialogTitle.copyWith(color: Palette.textDim),
              ),
              const SizedBox(height: 16),
              SonicButton(
                label: ConnectionText.current.connect,
                height: 64,
                minWidth: 0,
                isAccent: true,
                onPressed: connectAction(context, ref),
              ),
            ] else if (current != null) ...[
              Text(
                current.label,
                style: AppText.mono.copyWith(
                  fontSize: 14,
                  color: Palette.primary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: .start,
                children: [
                  Flexible(
                    child: Text(
                      names[current] ?? '',
                      maxLines: 2,
                      overflow: .ellipsis,
                      style: nameStyle,
                    ),
                  ),
                  // Unsaved-edits marker, outside the ellipsizing name (as
                  // in the top bar's preset pill).
                  if (isModified) Text(' ✱', style: nameStyle),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                spacing: 10,
                children: [
                  _StageButton(
                    icon: Icons.chevron_left,
                    label: ShellText.current.previous,
                    onTap: isEnabled
                        ? () => onPick(current.neighbour(-1))
                        : null,
                  ),
                  _StageButton(
                    icon: Icons.chevron_right,
                    label: ShellText.current.next,
                    isPrimary: true,
                    onTap: isEnabled
                        ? () => onPick(current.neighbour(1))
                        : null,
                  ),
                ],
              ),
            ] else
              Text(
                ShellText.current.noPresetSelected,
                style: AppText.dialogTitle.copyWith(color: Palette.textDim),
              ),
            const SizedBox(height: 16),
            if (isConnected)
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemExtent: _rowHeight,
                  itemCount: 50,
                  itemBuilder: (_, i) {
                    final p = PresetRef(bank, i + 1);

                    return StagePresetRow(
                      preset: p,
                      name: names[p],
                      isSelected: p == current,
                      isEnabled: isEnabled,
                      onTap: () => onPick(p),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One of the two big stage buttons: Previous (control fill, chevron first)
/// or Next (accent fill, chevron last). Disabled while loading.
class _StageButton extends StatelessWidget {
  const _StageButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final color = isPrimary ? Palette.onPrimary : Palette.onSurface;
    final glyph = Icon(icon, size: 28, color: color);

    return Expanded(
      child: Opacity(
        opacity: onTap != null ? 1 : 0.4,
        child: SonicHitArea(
          onTap: onTap,
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isPrimary
                  ? Palette.primary
                  : Palette.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: .center,
              children: [
                if (!isPrimary) glyph,
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: AppText.ui.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                if (isPrimary) glyph,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A stage preset row: slot code and name; the loaded one raised with an
/// accent border, like the rail's chips.
class StagePresetRow extends StatelessWidget {
  const StagePresetRow({
    super.key,
    required this.preset,
    required this.name,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final PresetRef preset;
  final String? name;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1 : 0.4,
      child: SonicHitArea(
        onTap: isEnabled ? onTap : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isSelected
                ? Palette.surfaceContainerHigh
                : Palette.surfaceContainerLow,
            border: Border.all(
              color: isSelected ? Palette.primary : Palette.transparent,
            ),
          ),
          child: Row(
            spacing: 12,
            children: [
              Text(
                preset.label,
                style: AppText.mono.copyWith(color: Palette.primary),
              ),
              Expanded(
                child: Text(
                  name ?? '',
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: AppText.ui.copyWith(
                    fontSize: 15,
                    color: isSelected
                        ? Palette.onSurface
                        : Palette.onSurfaceVariant,
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
