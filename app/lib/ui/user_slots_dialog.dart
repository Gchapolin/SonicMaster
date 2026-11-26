import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/common_text.dart';
import '../l10n/slots_text.dart';
import '../protocol/cfw_slot_names_codec.dart';
import '../state/cfw_providers.dart';
import '../state/data_providers.dart';
import '../state/device_providers.dart';
import '../state/names_providers.dart';
import '../state/preset_providers.dart';
import '../gear/gear_piece.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'sonic_controls.dart';
import 'user_ir_actions.dart';
import 'user_profile_actions.dart';

/// Every User IR and User Profile (Clone) slot in one list, each with Load /
/// Name / Clear, like the CFW app's "User IR & Clone slots": a file goes into
/// a slot without switching the preset's cab or amp to it. Ten of each on the
/// CFW, five on the stock firmware.
class UserSlotsDialog extends ConsumerWidget {
  const UserSlotsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dataAssetsProvider).valueOrNull;
    final names = ref.watch(userNamesProvider);
    final count = ref.watch(cfwInfoProvider) == null ? 5 : 10;
    final t = SlotsText.current;
    final isEnabled =
        ref.watch(connectionStateProvider) && !ref.watch(presetLoadingProvider);

    String nameOf(int fxId) =>
        data == null ? '' : effectDisplayName(fxId, data.effects, names);

    Widget row(String id, String name, Widget actions) => Container(
      height: 44,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(
        color: Palette.field,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              id,
              style: AppText.mono.copyWith(
                fontSize: 12,
                color: Palette.primary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              style: AppText.ui.copyWith(color: Palette.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          actions,
        ],
      ),
    );

    Widget group(Widget piece, String title, List<Widget> rows) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Palette.surfaceContainerLow,
          border: Border.all(color: Palette.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  SizedBox(width: 104, child: Center(child: piece)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: .center,
                      crossAxisAlignment: .start,
                      children: [
                        Text(
                          title,
                          style: AppText.uiStrong.copyWith(
                            fontSize: 16,
                            color: Palette.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.slotCount(count).toUpperCase(),
                          style: AppText.section.copyWith(
                            color: Palette.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ...rows,
          ],
        ),
      ),
    );

    return SonicDialog(
      maxWidth: 1040,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Text(
            t.title,
            style: AppText.title.copyWith(color: Palette.onSurface),
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: .stretch,
              children: [
                group(
                  const GearPiece(
                    model: 'User IR 1',
                    kind: GearKind.cab,
                    fit: Size(64, 64),
                  ),
                  t.irSection,
                  [
                    for (var slot = 0; slot < count; slot++)
                      row(
                        'IR ${slot + 1}',
                        nameOf(cfwIrEffectId(slot)),
                        UserIrActions(
                          slot: slot,
                          isEnabled: isEnabled,
                          currentName: nameOf(cfwIrEffectId(slot)),
                          inPanel: false,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                group(
                  const GearPiece(
                    model: 'Brit 800',
                    kind: GearKind.amp,
                    fit: Size(96, 40),
                  ),
                  t.profileSection,
                  [
                    for (var slot = 0; slot < count; slot++)
                      row(
                        'Clone ${slot + 1}',
                        nameOf(cfwProfileEffectId(slot)),
                        UserProfileActions(
                          slot: slot,
                          isEnabled: isEnabled,
                          currentName: nameOf(cfwProfileEffectId(slot)),
                          inPanel: false,
                        ),
                      ),
                  ],
                ),
              ],
            ),
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
