import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/appearance_text.dart';
import '../state/palette_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palettes.dart';
import '../theme/app_text.dart';
import 'sonic_controls.dart';

/// Lets the user pick the app's colour palette.
Future<void> showAppearanceDialog(BuildContext context) =>
    showSonicDialog<void>(
      context: context,
      builder: (_) => const _AppearanceDialog(),
    );

class _AppearanceDialog extends ConsumerWidget {
  const _AppearanceDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppearanceText.current;
    final selected = paletteById(ref.watch(paletteIdProvider));

    return SonicDialog(
      maxWidth: 760,
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          Text(
            t.title,
            style: AppText.title.copyWith(color: Palette.onSurface),
          ),
          const SizedBox(height: 18),
          Text(
            t.appColor.toUpperCase(),
            style: AppText.section.copyWith(color: Palette.outline),
          ),
          const SizedBox(height: 4),
          Text(
            t.appColorHint,
            style: AppText.ui.copyWith(
              fontSize: 12,
              color: Palette.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - 16) / 3;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in appPalettes)
                    SizedBox(
                      width: w,
                      child: _Chip(
                        palette: p,
                        isSelected: p.id == selected.id,
                        onTap: () =>
                            ref.read(paletteIdProvider.notifier).select(p.id),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Text(
                selected.name,
                style: AppText.ui.copyWith(
                  fontSize: 13,
                  color: Palette.onSurfaceVariant,
                ),
              ),
              SonicButton(
                label: t.close,
                isAccent: true,
                height: 40,
                minWidth: 100,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  final AppPalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: palette.name,
      child: GestureDetector(
        key: ValueKey('chip-${palette.id}'),
        behavior: .opaque,
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.only(left: 8, right: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Palette.secondaryContainer
                : Palette.surfaceContainerHighest,
            borderRadius: .circular(18),
            border: Border.all(
              width: 2,
              color: isSelected ? Palette.primary : Palette.transparent,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: .circular(4),
                child: SizedBox(
                  width: 40,
                  height: 16,
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: .circular(4),
                      border: Border.all(color: Palette.scrim),
                    ),
                    child: Row(
                      children: [
                        for (final c in palette.swatches)
                          Expanded(
                            child: DecoratedBox(
                              key: const ValueKey('swatch'),
                              decoration: BoxDecoration(color: c),
                              child: const SizedBox.expand(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // A long name shrinks to fit instead of being cut: two palettes
              // differ only in their last word.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    palette.name,
                    maxLines: 1,
                    softWrap: false,
                    style: AppText.uiStrong.copyWith(
                      fontSize: 13,
                      color: Palette.onSurface,
                    ),
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
