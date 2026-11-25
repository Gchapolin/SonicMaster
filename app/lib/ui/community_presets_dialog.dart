import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/common_text.dart';
import '../l10n/presets_text.dart';
import '../model/community_catalog.dart';
import '../state/community_presets.dart';
import '../state/device_providers.dart';
import '../state/preset_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'save_preset_dialog.dart';
import 'sonic_controls.dart';

/// The Sonicake CFW community presets, like the CFW app's: Try sends one to
/// the pedal's live state, Save to… does the same and opens Save preset with
/// its name. Presets using a CFW-only model the app cannot select yet say so.
class CommunityPresetsDialog extends HookConsumerWidget {
  const CommunityPresetsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(communityCatalogProvider);
    final isEnabled =
        ref.watch(connectionStateProvider) && !ref.watch(presetLoadingProvider);
    final busy = useState<String?>(null);
    // Per preset id: the outcome of its last Try (null = sent).
    final results = useState<Map<String, String?>>(const {});

    Future<void> run(CommunityPreset p, {required bool save}) async {
      busy.value = p.id;

      final error = await tryCommunityPreset(ref, p);

      if (!context.mounted) return;

      busy.value = null;
      results.value = {...results.value, p.id: error};

      if (error == null && save) {
        await showSavePresetDialog(context, name: p.name);
      }
    }

    Widget card(CommunityPreset p) {
      final isBusy = busy.value == p.id;
      final canRun = isEnabled && busy.value == null;
      final tried = results.value.containsKey(p.id);
      final error = results.value[p.id];
      final byline = [
        ?p.author,
        if (p.genres.isNotEmpty) p.genres.join(', '),
      ].join(' · ');
      final setup = [?p.guitar, ?p.tuning, ?p.controls].join(' · ');

      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SonicSurface(
          radius: 16,
          color: Palette.surfaceContainer,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Text(p.name, style: AppText.moduleTitle),
              if (byline.isNotEmpty) Text(byline, style: AppText.dialogBody),
              if (p.description != null) ...[
                const SizedBox(height: 4),
                Text(p.description!, style: AppText.dialogBody),
              ],
              if (setup.isNotEmpty)
                Text(setup, style: AppText.dialogBody.copyWith(fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  SonicButton(
                    label: PresetsText.current.tryLabel,
                    height: 38,
                    minWidth: 84,
                    isAccent: true,
                    onPressed: canRun ? () => run(p, save: false) : null,
                  ),
                  const SizedBox(width: 8),
                  SonicButton(
                    label: PresetsText.current.saveTo,
                    height: 38,
                    minWidth: 100,
                    onPressed: canRun ? () => run(p, save: true) : null,
                  ),
                  const SizedBox(width: 12),
                  if (isBusy) const SonicSpinner(size: 20),
                  if (!isBusy && tried)
                    Expanded(
                      child: Text(
                        error ?? PresetsText.current.onThePedal,
                        style: AppText.dialogBody.copyWith(
                          fontSize: 12,
                          color: error == null ? null : Palette.error,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return SonicDialog(
      maxWidth: 640,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Text(PresetsText.current.communityTitle, style: AppText.dialogTitle),
          const SizedBox(height: 4),
          Text(PresetsText.current.communityIntro, style: AppText.dialogBody),
          if (!ref.watch(connectionStateProvider))
            Text(PresetsText.current.connectToTry, style: AppText.dialogBody),
          ...catalog.when(
            data: (list) => [for (final p in list) card(p)],
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: SonicSpinner()),
              ),
            ],
            error: (_, _) => [
              const SizedBox(height: 12),
              Text(
                PresetsText.current.catalogueUnreadable,
                style: AppText.dialogBody,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: .centerLeft,
                child: SonicButton(
                  label: CommonText.current.retry,
                  onPressed: () => ref.invalidate(communityCatalogProvider),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: .centerRight,
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
