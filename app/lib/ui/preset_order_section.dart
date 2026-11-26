import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/settings_text.dart';
import '../model/command_library.dart';
import '../model/preset_ref.dart';
import '../state/cfw_providers.dart';
import '../state/names_providers.dart';
import '../state/preset_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'sonic_controls.dart';

/// The CFW's preset order: move one User preset to another position; the
/// presets in between shift by one. The pedal only rewrites its order table
/// (no preset is changed), so MIDI and footswitch preset numbers select the
/// sounds at their new positions.
class PresetOrderSection extends HookConsumerWidget {
  const PresetOrderSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = SettingsText.current;
    final names = ref.watch(presetNamesProvider);
    final isLoading = ref.watch(presetLoadingProvider);
    final loaded = ref.read(currentPresetProvider);
    // Opens on the loaded preset when it is a User one (a Factory preset has
    // no place in the order).
    final from = useState(
      loaded != null && loaded.bank == PresetBank.user ? loaded.number : 1,
    );
    final to = useState(1);
    final isBusy = useState(false);
    final status = useState<String?>(null);

    Future<void> move() async {
      isBusy.value = true;
      status.value = null;

      final isMoved = await moveUserPreset(ref, from.value, to.value);

      if (!context.mounted) return;

      isBusy.value = false;
      status.value = isMoved
          ? t.movedTo(PresetRef(.user, to.value).label)
          : t.orderRefused;
      if (isMoved) from.value = to.value;
    }

    final isEnabled = !isLoading && !isBusy.value;

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 4,
      children: [
        _Row(
          label: t.move,
          child: SonicDropdown<int>(
            value: from.value,
            width: 170,
            height: 34,
            isEnabled: isEnabled,
            items: [
              for (var n = 1; n <= 50; n++)
                (value: n, label: presetChipLabel(PresetRef(.user, n), names)),
            ],
            onChanged: (v) => from.value = v,
          ),
        ),
        _Row(
          label: t.toPosition,
          child: Row(
            mainAxisSize: .min,
            spacing: 6,
            children: [
              SonicDropdown<int>(
                value: to.value,
                width: 96,
                height: 34,
                isEnabled: isEnabled,
                items: [
                  for (var n = 1; n <= 50; n++)
                    (value: n, label: PresetRef(.user, n).label),
                ],
                onChanged: (v) => to.value = v,
              ),
              SonicButton(
                label: t.movePreset,
                height: 34,
                minWidth: 0,
                onPressed: isEnabled && from.value != to.value ? move : null,
              ),
            ],
          ),
        ),
        // The hint until a move reports back; the settings grid keeps it to
        // one line.
        Text(
          status.value ?? t.orderHint,
          maxLines: status.value == null ? 1 : null,
          overflow: status.value == null ? .ellipsis : null,
          style: AppText.ui.copyWith(color: Palette.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// A label on the left and a trailing [child] control on the right.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
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
