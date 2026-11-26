import 'dart:convert';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../gear/gear_piece.dart';
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

/// The amp model a community preset file uses (its AMP effect, or the Clone
/// one in clone mode), for the card thumbnail; null when it has none or the
/// file cannot be read. ponytail: one extra download per card, shown only
/// once it arrives; a catalogue field would save them.
final _communityAmpProvider = FutureProvider.family<String?, String>((
  ref,
  file,
) async {
  try {
    final text = await ref.watch(communityFetchProvider)(
      Uri.parse(communityBaseUrl).resolve(file),
    );
    final json = jsonDecode(text) as Map;
    final modules = json['modules'] as Map?;
    final key = json['ampMode'] == 'Clone' ? 'Clone' : 'AMP';
    final effect = (modules?[key] as Map?)?['effect'];

    return effect is String && effect.isNotEmpty ? effect : null;
  } catch (_) {
    return null;
  }
});

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
    // The preset last sent to the pedal (the one the status line follows).
    final live = useState<String?>(null);
    final results = useState<Map<String, String?>>(const {});

    Future<void> run(CommunityPreset p, {required bool save}) async {
      busy.value = p.id;

      final error = await tryCommunityPreset(ref, p);

      if (!context.mounted) return;

      busy.value = null;
      results.value = {...results.value, p.id: error};
      if (error == null) live.value = p.id;

      if (error == null && save) {
        await showSavePresetDialog(context, name: p.name);
      }
    }

    Widget card(CommunityPreset p) {
      final isBusy = busy.value == p.id;
      final canRun = isEnabled && busy.value == null;
      final isLive = live.value == p.id;
      final error = results.value[p.id];
      final amp = ref.watch(_communityAmpProvider(p.file)).valueOrNull;
      final byline = [
        ?p.author,
        if (p.genres.isNotEmpty) p.genres.join(', '),
      ].join(' · ');
      final setup = [?p.guitar, ?p.tuning, ?p.controls].join(' · ');
      final text2 = AppText.ui.copyWith(color: Palette.onSurfaceVariant);

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Palette.surfaceContainer,
          border: Border.all(color: Palette.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: .start,
          children: [
            if (amp != null) ...[
              SizedBox(
                width: 120,
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Palette.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: GearPiece(
                        model: amp,
                        kind: GearKind.amp,
                        fit: const Size(96, 44),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      amp,
                      style: AppText.ui.copyWith(
                        fontSize: 11,
                        color: Palette.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    p.name,
                    style: AppText.title.copyWith(
                      fontSize: 17,
                      color: Palette.onSurface,
                    ),
                  ),
                  if (byline.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(byline, style: text2),
                  ],
                  if (p.description != null) ...[
                    const SizedBox(height: 6),
                    Text(p.description!, style: text2.copyWith(height: 1.45)),
                  ],
                  if (setup.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      setup,
                      style: AppText.ui.copyWith(
                        fontSize: 12,
                        height: 1.45,
                        color: Palette.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  SonicButton(
                    label: PresetsText.current.tryLabel,
                    height: 38,
                    isAccent: true,
                    onPressed: canRun ? () => run(p, save: false) : null,
                  ),
                  const SizedBox(height: 8),
                  SonicButton(
                    label: PresetsText.current.saveTo,
                    height: 38,
                    onPressed: canRun ? () => run(p, save: true) : null,
                  ),
                  const SizedBox(height: 8),
                  if (isBusy)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: SonicSpinner(size: 20),
                    )
                  else if (isLive)
                    Row(
                      crossAxisAlignment: .start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Palette.ok,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            PresetsText.current.onThePedal,
                            style: text2.copyWith(fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    )
                  else if (error != null)
                    Text(
                      error,
                      style: text2.copyWith(
                        fontSize: 12,
                        height: 1.4,
                        color: Palette.error,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SonicDialog(
      maxWidth: 940,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Row(
            crossAxisAlignment: .start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Palette.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.public, size: 18, color: Palette.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      PresetsText.current.communityTitle,
                      style: AppText.title.copyWith(color: Palette.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      PresetsText.current.communityIntro,
                      style: AppText.ui.copyWith(
                        height: 1.45,
                        color: Palette.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!ref.watch(connectionStateProvider)) ...[
            const SizedBox(height: 12),
            Text(
              PresetsText.current.connectToTry,
              style: AppText.ui.copyWith(color: Palette.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          ...catalog.when(
            data: (list) => [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                card(list[i]),
              ],
            ],
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
                style: AppText.ui.copyWith(color: Palette.onSurfaceVariant),
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
