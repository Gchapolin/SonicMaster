import 'package:flutter/material.dart' show Icons; // glyph font only
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/common_text.dart';
import '../l10n/presets_text.dart';
import '../model/preset_ref.dart';
import '../state/names_providers.dart';
import '../state/preset_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'sonic_controls.dart';
import 'sonic_field.dart';
import 'sonic_metrics.dart';

/// Presents [SavePresetDialog]. Like every other pop-up in the app it dismisses
/// on an outside tap (the in-flight save is guarded by the dialog's own
/// PopScope, not by a non-dismissible barrier). Resolves to true when the save
/// ACKed, false on Cancel, null when dismissed.
/// [name] replaces the loaded preset's name as the prefill.
Future<bool?> showSavePresetDialog(BuildContext context, {String? name}) {
  return showSonicDialog<bool>(
    context: context,
    builder: (_) => SavePresetDialog(initialName: name),
  );
}

/// Name + target-slot dialog for saving the current edits to flash (`040A`).
class SavePresetDialog extends HookConsumerWidget {
  const SavePresetDialog({super.key, this.initialName});

  /// Prefilled name (cut to the pedal's 10 characters); null takes the loaded
  /// preset's.
  final String? initialName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read once: the dialog seeds its fields from the preset that was loaded
    // when it opened, and must not re-seed them under the user mid-edit.
    final current = useMemoized(() => ref.read(currentPresetProvider));

    // Prefill the loaded preset's decoded *name* so a re-save doesn't force the
    // user to retype it. Never the slot *label* (e.g. "P05"/"F03") — that is not
    // a stored name, and writing it to flash would be misleading. Empty when the
    // name dump hasn't been decoded yet.
    final name = useTextEditingController(
      text: initialName != null
          ? initialName!.substring(0, initialName!.length.clamp(0, 10))
          : current == null
          ? ''
          : ref.read(presetNamesProvider)[current] ?? '',
    );

    final nameText = useValueListenable(name).text;

    final slot = useState(
      (current != null && current.bank == .user) ? current.number : 1,
    );

    final isSaving = useState(false);

    Future<void> save() async {
      isSaving.value = true;

      final ok = await savePreset(ref, slot.value, name.text);

      if (context.mounted) Navigator.pop(context, ok);
    }

    final isSaveEnabled = !isSaving.value && nameText.trim().isNotEmpty;
    final isCompact = SonicMetrics.of(context).isCompact;

    final names = ref.watch(presetNamesProvider);
    final isMenuOpen = useState(false);
    // The two-column list shows all 50 slots without scrolling: the row height
    // follows the window height (the name field and buttons step aside while
    // the list is open).
    final rowHeight = ((MediaQuery.sizeOf(context).height - 300) / 25 - 2)
        .clamp(14.0, 32.0);

    String slotName(int n) => names[PresetRef(.user, n)] ?? '';

    Widget label(String text) => Text(
      text.toUpperCase(),
      style: AppText.section.copyWith(color: Palette.outline),
    );

    Widget slotRow(int n, {required double height}) {
      final isPicked = n == slot.value;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          slot.value = n;
          name.text = slotName(n).characters.take(10).toString();
          isMenuOpen.value = false;
        },
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isPicked ? Palette.secondaryContainer : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(
                _id(n),
                style: AppText.mono.copyWith(
                  color: Palette.primary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  slotName(n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui.copyWith(
                    color: Palette.onSurface,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Block dismissal while a save is in flight, so the WidgetRef passed into
    // savePreset isn't disposed before savePreset's post-await provider writes
    // run. This covers every route out: back button, Escape and outside-taps
    // all go through Navigator.maybePop, which honours canPop.
    return PopScope(
      canPop: !isSaving.value && !isMenuOpen.value,
      // Back (and Escape) first closes the open slot list, then the dialog.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !isSaving.value) isMenuOpen.value = false;
      },
      child: SonicDialog(
        maxWidth: 380,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            Text(
              PresetsText.current.savePresetTitle,
              style: AppText.title.copyWith(
                color: Palette.onSurface,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 18),
            label(PresetsText.current.slot),
            const SizedBox(height: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isSaving.value
                  ? null
                  : () => isMenuOpen.value = !isMenuOpen.value,
              child: Container(
                height: 42,
                padding: const EdgeInsets.only(left: 14, right: 12),
                decoration: BoxDecoration(
                  color: Palette.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(
                      _id(slot.value),
                      style: AppText.mono.copyWith(
                        color: Palette.primary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        slotName(slot.value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui.copyWith(
                          color: Palette.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      isMenuOpen.value ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: Palette.outline,
                    ),
                  ],
                ),
              ),
            ),
            if (isMenuOpen.value) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Palette.field,
                  border: Border.all(color: Palette.line2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: .start,
                  children: [
                    for (final first in const [1, 26])
                      Expanded(
                        child: Column(
                          children: [
                            for (var n = first; n < first + 25; n++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: slotRow(n, height: rowHeight),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 18),
              label(PresetsText.current.presetName),
              const SizedBox(height: 6),
              SonicField(
                controller: name,
                autofocus: true,
                maxLength: 10,
                hintText: PresetsText.current.nameHint,
                style: AppText.input.copyWith(
                  color: Palette.onSurface,
                  fontSize: 15,
                ),
                onSubmitted: (_) {
                  // Compact with the soft keyboard up: Done only closes the
                  // keyboard, revealing the Slot picker; saving stays an
                  // explicit tap on Save. A hardware Enter (no inset) and the
                  // regular layout still save at once.
                  if (isCompact &&
                      MediaQuery.viewInsetsOf(context).bottom > 0) {
                    return;
                  }

                  if (isSaveEnabled) save();
                },
              ),
              const SizedBox(height: 6),
              Text(
                PresetsText.current.maxChars,
                style: AppText.ui.copyWith(
                  color: Palette.outline,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: .end,
                children: [
                  SonicButton(
                    label: CommonText.current.cancel,
                    onPressed: isSaving.value
                        ? null
                        : () => Navigator.pop(context, false),
                  ),
                  const SizedBox(width: 10),
                  SonicButton(
                    label: CommonText.current.save,
                    isAccent: true,
                    onPressed: isSaveEnabled ? save : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _id(int n) => 'P${n.toString().padLeft(2, '0')}';
