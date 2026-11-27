import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart'; // Icons glyph font only
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/appearance_text.dart';
import '../model/preset_ref.dart';
import '../state/device_providers.dart';
import '../state/layout_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'appearance_dialog.dart';
import 'preset_rail.dart';
import 'sonic_controls.dart';
import 'sonic_metrics.dart';
import 'top_bar.dart';

/// The compact layout's preset browser: the rail as an overlay drawer over the
/// whole app, title bar included, above a dimming scrim. Its only burger
/// floats in the title bar's leading slot above the sliding panel, so the
/// button never moves while the panel and its logo slide in under it.
///
/// It stays mounted for as long as the layout is compact; closed, it sits
/// off-screen and inert. So the slide has a closed state to animate from, the
/// burger always exists, and the list keeps its layout (and its scroll offset)
/// between openings.
class PresetDrawer extends HookConsumerWidget {
  const PresetDrawer({
    super.key,
    required this.onPick,
    required this.onMasterVolume,
  });

  /// Called with the tapped row's preset; the page runs pickPreset on it.
  final ValueChanged<PresetRef> onPick;

  /// Called with each new Master Vol level; the page runs setGlobalVolume on
  /// it, on its own ref.
  final ValueChanged<int> onMasterVolume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = SonicMetrics.of(context);
    final isOpen = ref.watch(presetDrawerOpenProvider);
    final scrollController = useScrollController();
    final currentRowKey = useMemoized(() => GlobalKey(), const []);

    void close() => ref.read(presetDrawerOpenProvider.notifier).state = false;

    // Each opening brings the loaded preset's row to about a third of the
    // list's height, unless it is already in full view or not listed (the
    // other bank, filtered out). Positions come from this frame's layout only.
    useEffect(() {
      if (!isOpen) return null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final row = currentRowKey.currentContext?.findRenderObject();

        if (!context.mounted || row == null || !scrollController.hasClients) {
          return;
        }

        final position = scrollController.position;
        final viewport = RenderAbstractViewport.of(row);
        final isInView =
            position.pixels <= viewport.getOffsetToReveal(row, 0).offset &&
            position.pixels >= viewport.getOffsetToReveal(row, 1).offset;

        if (isInView) return;

        // The list's own position only: Scrollable.ensureVisible would also
        // move the app's sideways scroll view.
        unawaited(position.ensureVisible(row, alignment: 1 / 3));
      });

      return null;
    }, [isOpen]);

    // Back (on web: popstate -> popRoute -> maybePop) closes an open drawer. A
    // dialog above the page is popped first; a closed drawer lets Back through
    // (it leaves the app, as before). The route calls every PopScope on it, so
    // this only ever closes, never toggles.
    return PopScope(
      canPop: !isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: _Scrim(isOpen: isOpen, onTap: close),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: drawerWidth,
            child: _DrawerPanel(
              isOpen: isOpen,
              scrollController: scrollController,
              currentRowKey: currentRowKey,
              onPick: onPick,
              onMasterVolume: onMasterVolume,
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: drawerButtonSlotWidth,
            height: metrics.topBarHeight,
            child: const Center(child: _DrawerButton()),
          ),
        ],
      ),
    );
  }
}

/// The burger: opens and closes the drawer. It wears the title bar's icon
/// padding, a 38x46 target in the 48-px compact bar.
class _DrawerButton extends ConsumerWidget {
  const _DrawerButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Presets',
      child: SonicIconButton(
        icon: Icons.menu,
        padding: SonicMetrics.of(context).topBarIconPadding,
        onPressed: () {
          final drawer = ref.read(presetDrawerOpenProvider.notifier);

          drawer.state = !drawer.state;
        },
      ),
    );
  }
}

/// The dim over the rest of the app while the drawer is open. It swallows
/// every tap and drag on what it covers (title-bar actions included) and
/// closes the drawer on a tap.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.isOpen, required this.onTap});

  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isOpen,
      child: GestureDetector(
        behavior: .opaque,
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: isOpen ? 1 : 0,
          duration: sonicMotionDuration,
          curve: sonicMotionCurve,
          child: const ColoredBox(color: Palette.scrim),
        ),
      ),
    );
  }
}

/// The sliding panel: a title-bar-styled header over the one-scroll body.
/// Closed, it sits one panel width off-screen and ignores pointers, focus and
/// semantics. No drop shadow: closed, it would leak onto the app's left edge.
class _DrawerPanel extends StatelessWidget {
  const _DrawerPanel({
    required this.isOpen,
    required this.scrollController,
    required this.currentRowKey,
    required this.onPick,
    required this.onMasterVolume,
  });

  final bool isOpen;
  final ScrollController scrollController;
  final GlobalKey currentRowKey;
  final ValueChanged<PresetRef> onPick;
  final ValueChanged<int> onMasterVolume;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isOpen,
      // Every close path (burger, scrim, pick, Back, a layout flip) drops the
      // search field's focus, which hides the soft keyboard; closed, the
      // panel stays out of keyboard traversal.
      child: ExcludeFocus(
        excluding: !isOpen,
        child: ExcludeSemantics(
          excluding: !isOpen,
          // Clipped to its slot: closed, the slide would otherwise paint into
          // the left safe-area inset of a notched phone in landscape.
          child: ClipRect(
            child: AnimatedSlide(
              offset: isOpen ? Offset.zero : const Offset(-1, 0),
              duration: sonicMotionDuration,
              curve: sonicMotionCurve,
              child: DecoratedBox(
                decoration: railDecoration,
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    SizedBox(
                      height: SonicMetrics.of(context).topBarHeight,
                      child: const _DrawerHeader(),
                    ),
                    Expanded(
                      child: _DrawerBody(
                        scrollController: scrollController,
                        currentRowKey: currentRowKey,
                        onPick: onPick,
                        onMasterVolume: onMasterVolume,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The panel's header: the title bar's plate with an empty burger slot (the
/// floating burger sits above it) and the logo.
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: topBarDecoration,
      child: Row(
        children: [
          SizedBox(width: drawerButtonSlotWidth),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 4, right: 16),
              child: SonicLogo(),
            ),
          ),
        ],
      ),
    );
  }
}

/// ONE scroll list: the Appearance entry, the rail's Master Vol row, its
/// controls and its preset rows. Master Vol stays in the list (the rail pins
/// it under its own): a phone's soft keyboard leaves no room for a pinned row.
class _DrawerBody extends ConsumerWidget {
  const _DrawerBody({
    required this.scrollController,
    required this.currentRowKey,
    required this.onPick,
    required this.onMasterVolume,
  });

  final ScrollController scrollController;
  final GlobalKey currentRowKey;
  final ValueChanged<PresetRef> onPick;
  final ValueChanged<int> onMasterVolume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(connectionStateProvider);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        controller: scrollController,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: .spaceBetween,
            crossAxisAlignment: .stretch,
            children: [
              Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                children: [
                  _AppearanceEntry(
                    onTap: () {
                      ref.read(presetDrawerOpenProvider.notifier).state = false;
                      unawaited(showAppearanceDialog(context));
                    },
                  ),
                  if (isConnected) ...[
                    MasterVolumeRow(
                      isHoldToTurnOnTouch: true,
                      onMasterVolume: onMasterVolume,
                    ),
                    RailControls(
                      // Revealing the focused search reveals the list's
                      // height below it too (capped so the caret itself stays
                      // revealable): the matches show above the keyboard.
                      searchScrollPadding: EdgeInsets.fromLTRB(
                        20,
                        20,
                        20,
                        math.max(20, constraints.maxHeight - 64),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: PresetChipColumn(
                        onPick: onPick,
                        currentRowKey: currentRowKey,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The drawer's Appearance row: the phone bar has no room for the icon.
class _AppearanceEntry extends StatelessWidget {
  const _AppearanceEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('drawer-appearance'),
      behavior: .opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.palette, size: 20, color: Palette.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(
              AppearanceText.current.title,
              style: AppText.ui.copyWith(color: Palette.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
