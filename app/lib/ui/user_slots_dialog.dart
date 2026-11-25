import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../protocol/cfw_slot_names_codec.dart';
import '../state/cfw_providers.dart';
import '../state/data_providers.dart';
import '../state/device_providers.dart';
import '../state/names_providers.dart';
import '../state/preset_providers.dart';
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
    final isEnabled =
        ref.watch(connectionStateProvider) && !ref.watch(presetLoadingProvider);

    String nameOf(int fxId) =>
        data == null ? '' : effectDisplayName(fxId, data.effects, names);

    Widget row(String label, Widget actions) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.dialogBody,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          actions,
        ],
      ),
    );

    return SonicDialog(
      maxWidth: 560,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          const Text('User IR & Clone slots', style: AppText.dialogTitle),
          const SizedBox(height: 12),
          const Text('User IR (cab)', style: AppText.dialogBody),
          for (var slot = 0; slot < count; slot++)
            row(
              'IR ${slot + 1} · ${nameOf(cfwIrEffectId(slot))}',
              UserIrActions(
                slot: slot,
                isEnabled: isEnabled,
                currentName: nameOf(cfwIrEffectId(slot)),
                inPanel: false,
              ),
            ),
          const SizedBox(height: 16),
          const Text('User Profile (Clone)', style: AppText.dialogBody),
          for (var slot = 0; slot < count; slot++)
            row(
              'Clone ${slot + 1} · ${nameOf(cfwProfileEffectId(slot))}',
              UserProfileActions(
                slot: slot,
                isEnabled: isEnabled,
                currentName: nameOf(cfwProfileEffectId(slot)),
                inPanel: false,
              ),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: .centerRight,
            child: SonicButton(
              label: 'Close',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
