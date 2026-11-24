import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart'; // Icons glyph font only
import 'package:flutter_hooks/flutter_hooks.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'sonic_metrics.dart';

/// Official UI-kit controls, faithful to `UI Kit (standalone).html`:
/// [SonicToggle] reproduces the BOOST toggle and [SonicDropdown] the MODE
/// dropdown. All boolean toggles and dropdowns in the app use these.

/// A Material 3 style switch: a pill track filled in the primary color with
/// an onPrimary thumb on the right when on; an outlined dark track with a
/// smaller outline thumb on the left when off. Keeps the kit's footprint
/// (track 104x46 scaled by [height]). [onChanged] null -> disabled/dimmed.
class SonicToggle extends StatelessWidget {
  const SonicToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.height = 26,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final h = height;
    final w = h * 104 / 46;
    final thumb = value ? h * 0.75 : h * 0.5;
    final inset = (h - thumb) / 2;
    final isEnabled = onChanged != null;
    const duration = Duration(milliseconds: 160);
    const curve = Cubic(0.4, 0.15, 0.3, 1);

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.4,
        child: GestureDetector(
          behavior: .opaque,
          onTap: isEnabled ? () => onChanged!(!value) : null,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: duration,
                    curve: curve,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(h / 2),
                      color: value
                          ? Palette.primary
                          : Palette.surfaceContainerHighest,
                      border: Border.all(
                        color: value ? Palette.primary : Palette.outline,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: duration,
                  curve: curve,
                  top: inset,
                  left: value ? w - inset - thumb : inset,
                  width: thumb,
                  height: thumb,
                  child: CustomPaint(
                    painter: _ToggleKnobPainter(
                      value ? Palette.onPrimary : Palette.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the switch thumb: a flat disc in [color].
class _ToggleKnobPainter extends CustomPainter {
  const _ToggleKnobPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawCircle(
    size.center(Offset.zero),
    size.shortestSide / 2,
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(_ToggleKnobPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A flat input well (search, value readouts, text fields): a
/// surfaceContainerHigh rounded rect with a hairline outline. [accent]
/// optionally paints a rounded bar down the left edge.
class SonicRecess extends StatelessWidget {
  const SonicRecess({
    super.key,
    required this.child,
    this.radius = 10,
    this.padding = EdgeInsets.zero,
    this.accent,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RecessPainter(radius: radius, accent: accent),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _RecessPainter extends CustomPainter {
  const _RecessPainter({required this.radius, this.accent});

  final double radius;
  final Color? accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    canvas.drawRRect(rrect, Paint()..color = Palette.surfaceContainerHigh);
    // A hairline outline: dialog plates share the well's fill, so without it
    // a field inside a dialog would show no box. Painted only, no layout.
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..color = Palette.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // optional accent bar down the left edge (clipped -> rounded corners)
    if (accent != null) {
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, 3, size.height),
        Paint()..color = accent!,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RecessPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.accent != accent;
}

/// A flat Material 3 pill button: filled in the primary color when [isAccent]
/// (the primary/destructive action), tonal (secondaryContainer) otherwise.
/// [isLit] lights only the label (primary on the tonal fill), for a light
/// indicator such as the tap-tempo beat. A press lays a 10% state layer of
/// the label color over the fill.
/// [onPressed] null → disabled/dimmed.
class SonicButton extends HookWidget {
  const SonicButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 44,
    this.minWidth = 104,
    this.isAccent = false,
    this.isLit = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double minWidth;
  final bool isAccent;
  final bool isLit;

  @override
  Widget build(BuildContext context) {
    final isDown = useState(false);
    final isEnabled = onPressed != null;
    final s = height / 54; // kit's native button height
    final labelColor = isAccent
        ? Palette.onPrimary
        : isLit
        ? Palette.primary
        : Palette.onSecondaryContainer;
    final base = isAccent ? Palette.primary : Palette.secondaryContainer;
    final fill = isDown.value
        ? Color.alphaBlend(labelColor.withValues(alpha: 0.1), base)
        : base;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.4,
        child: GestureDetector(
          behavior: .opaque,
          onTapDown: isEnabled ? (_) => isDown.value = true : null,
          onTapUp: isEnabled
              ? (_) {
                  isDown.value = false;
                  onPressed!();
                }
              : null,
          onTapCancel: isEnabled ? () => isDown.value = false : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minWidth,
              minHeight: height,
              maxHeight: height,
            ),
            child: CustomPaint(
              painter: _SonicButtonPainter(color: fill),
              child: Center(
                widthFactor: 1,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22 * s),
                  child: Text(
                    label,
                    style: AppText.button.copyWith(
                      fontSize: 19 * s,
                      letterSpacing: 19 * s * 0.12,
                      color: labelColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SonicButtonPainter extends CustomPainter {
  const _SonicButtonPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRRect(
    RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    ),
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(_SonicButtonPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A non-knob control (toggle / dropdown / button / readout) laid out to match
/// [KnobControl]'s cell so panels line up: an empty top row the height of the
/// knob's value readout, then a body region the height of the knob with
/// [control] centered (its center on the knob's center), then [label] in the
/// knob's label style. Used by the module editor and the DLY tap-tempo row.
class PanelCell extends StatelessWidget {
  const PanelCell({super.key, required this.control, this.label = ''});

  final Widget control;
  final String label;

  @override
  Widget build(BuildContext context) {
    final metrics = SonicMetrics.of(context);

    return Padding(
      padding: EdgeInsets.all(metrics.knobCellPadding),
      child: Column(
        mainAxisSize: .min,
        children: [
          Text(' ', style: metrics.knobValueStyle), // reserve readout height
          // A Column that fills the knob-body height and centers its single
          // child puts the control's center on the knob's center — while
          // shrink-wrapping width (a bare Center would expand to panel width).
          SizedBox(
            height: metrics.panelKnobSize + 4,
            child: Column(mainAxisAlignment: .center, children: [control]),
          ),
          Text(label.toUpperCase(), style: metrics.knobLabelStyle),
        ],
      ),
    );
  }
}

/// The shared pop-up shell: a [SonicSurface] plate, centred. All dialogs use
/// this so pop-ups share one look.
///
/// Phone heights: [child] scrolls inside the plate when the screen leaves too
/// little height for it ([isScrollable]); content that fits lays out exactly
/// as a plain padded plate, and its scroll view stays inert. In compact the
/// plate also sits in the space above the soft keyboard. Dialogs that pin
/// their own header or actions around a Flexible region pass
/// `isScrollable: false` and get a bounded height instead.
class SonicDialog extends StatelessWidget {
  const SonicDialog({
    super.key,
    required this.child,
    this.maxWidth = 460,
    this.padding,
    this.isScrollable = true,
  });

  final Widget child;
  final double maxWidth;

  /// Inner padding; null takes the layout's [SonicMetrics.dialogPadding].
  final EdgeInsetsGeometry? padding;

  /// Whether [child] scrolls when the plate is shorter than it.
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    final metrics = SonicMetrics.of(context);
    final inner = padding ?? metrics.dialogPadding;
    // Compact: lift the plate above the soft keyboard. A plain (not
    // animated) inset: EditableText reveals its caret one frame after the
    // keyboard metrics change and must see the final layout. Regular never
    // moves (and takes no viewInsets dependency): desktop has no soft
    // keyboard, and tablets keep today's behaviour.
    final keyboardInset = metrics.isCompact
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Center(
        child: Padding(
          padding: metrics.dialogMargin,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SonicSurface(
              radius: 28,
              color: Palette.surfaceContainerHigh,
              padding: EdgeInsets.zero,
              child: isScrollable
                  // Clamping on every platform: no bounce, and the scroll
                  // view stays inert while the content fits.
                  ? SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: inner,
                      child: child,
                    )
                  : Padding(padding: inner, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Presents [builder] as a modal over a dimmed barrier — the Material-free
/// replacement for `showDialog`. Uses `showGeneralDialog` (from the widgets
/// layer), so it needs no `Material` ancestor or `MaterialLocalizations`.
Future<T?> showSonicDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'dismiss',
    barrierColor: Palette.scrim,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// One entry in a [SonicDropdown] / [SonicSegmented].
typedef SonicItem<T> = ({T value, String label});

/// A Material 3 segmented button: an outlined pill of equal segments; the
/// active one is filled (secondaryContainer). [onChanged] null → disabled.
/// [width] fixes the bar width (segments split it equally); null → segments
/// size to their labels.
class SonicSegmented<T> extends StatelessWidget {
  const SonicSegmented({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.height = 34,
    this.width,
    this.isExpanded = false,
    this.disabledValues = const {},
    this.segmentPadding = 16,
  });

  final T value;
  final List<SonicItem<T>> segments;
  final ValueChanged<T>? onChanged;
  final double height;
  final double? width;

  /// Fill the available width (segments split it equally). [width] implies this.
  final bool isExpanded;

  /// Segment values that are individually greyed out and non-tappable while the
  /// bar as a whole stays enabled (e.g. an already-claimed footswitch).
  final Set<T> disabledValues;

  /// Horizontal padding inside each segment, around its label.
  final double segmentPadding;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onChanged != null;
    final isFilled = width != null || isExpanded;
    final segmentWidgets = [
      for (final (i, seg) in segments.indexed)
        _Segment(
          label: seg.label,
          isActive: seg.value == value,
          hasDivider: i > 0,
          isEnabled: isEnabled && !disabledValues.contains(seg.value),
          isDimmed: isEnabled && disabledValues.contains(seg.value),
          padding: segmentPadding,
          onTap: isEnabled && !disabledValues.contains(seg.value)
              ? () => onChanged!(seg.value)
              : null,
        ),
    ];

    final children = isFilled
        ? [for (final s in segmentWidgets) Expanded(child: s)]
        : segmentWidgets;

    final radius = BorderRadius.circular(height / 2);
    Widget bar = ClipRRect(
      borderRadius: radius,
      child: Row(mainAxisSize: isFilled ? .max : .min, children: children),
    );

    if (width != null) bar = SizedBox(width: width, child: bar);

    return Opacity(
      opacity: isEnabled ? 1 : 0.45,
      child: Container(
        height: height,
        // A foreground border: drawn over the segments, so it takes no space
        // and the segments keep their size.
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: Palette.outline),
        ),
        child: bar,
      ),
    );
  }
}

/// One segment of a [SonicSegmented] bar: filled with onSecondaryContainer
/// text when active, plain with onSurface text otherwise.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.isActive,
    required this.hasDivider,
    required this.isEnabled,
    required this.isDimmed,
    required this.padding,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final bool hasDivider;
  final bool isEnabled;
  final bool isDimmed;
  final double padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: .opaque,
        onTap: onTap,
        child: Container(
          height: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: padding),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? Palette.secondaryContainer : null,
            border: hasDivider
                ? const Border(left: BorderSide(color: Palette.outline))
                : null,
          ),
          // scaleDown shrinks a label that would otherwise overflow its (equal)
          // segment slice — e.g. "Pocket Master" against "Auto"/"Smart Box" —
          // instead of clipping it. Labels that already fit are left untouched.
          child: FittedBox(
            fit: .scaleDown,
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              style: AppText.segmentLabel.copyWith(
                color: isDimmed
                    ? Palette.outline
                    : isActive
                    ? Palette.onSecondaryContainer
                    : Palette.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The MODE dropdown: an outlined field that opens a flat menu of options with
/// a selected-highlight. [width] fixes the trigger + menu width; when null the
/// trigger sizes to content and the menu matches its measured width.
class SonicDropdown<T> extends HookWidget {
  const SonicDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width,
    this.isEnabled = true,
    this.height = 40,
  });

  final T? value;
  final List<SonicItem<T>> items;
  final ValueChanged<T> onChanged;
  final double? width;
  final bool isEnabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final controller = useMemoized(() => OverlayPortalController(), const []);
    final link = useMemoized(() => LayerLink(), const []);
    final triggerKey = useMemoized(() => GlobalKey(), const []);
    final isOpen = useState(false);

    final label = items.isEmpty
        ? ''
        : items
              .firstWhere((it) => it.value == value, orElse: () => items.first)
              .label;

    void close() {
      controller.hide();
      isOpen.value = false;
    }

    void toggle() {
      if (!isEnabled) return;

      if (controller.isShowing) {
        controller.hide();
      } else {
        controller.show();
      }

      isOpen.value = controller.isShowing;
    }

    return CompositedTransformTarget(
      link: link,
      child: OverlayPortal(
        controller: controller,
        overlayChildBuilder: (context) => _DropdownMenu<T>(
          link: link,
          triggerKey: triggerKey,
          items: items,
          value: value,
          width: width,
          onSelected: (v) {
            onChanged(v);
            close();
          },
          onDismiss: close,
        ),
        child: _DropdownTrigger(
          triggerKey: triggerKey,
          label: label,
          isOpen: isOpen.value,
          width: width,
          isEnabled: isEnabled,
          height: height,
          onTap: toggle,
        ),
      ),
    );
  }
}

class _DropdownTrigger extends StatelessWidget {
  const _DropdownTrigger({
    required this.triggerKey,
    required this.label,
    required this.isOpen,
    required this.width,
    required this.isEnabled,
    required this.height,
    required this.onTap,
  });

  final GlobalKey triggerKey;
  final String label;
  final bool isOpen;
  final double? width;
  final bool isEnabled;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget trigger = Container(
      key: triggerKey,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      // An outlined field; the border is drawn over the content, so it takes
      // no space.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.outline),
      ),
      child: Row(
        mainAxisSize: width == null ? .min : .max,
        mainAxisAlignment: .spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: .ellipsis,
              style: AppText.controlLabel.copyWith(color: Palette.onSurface),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedRotation(
            turns: isOpen ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(
              Icons.keyboard_arrow_down,
              size: 22,
              color: Palette.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (width != null) {
      trigger = SizedBox(width: width, child: trigger);
    }

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.45,
        // Opaque: the trigger paints no fill now, so its empty space must
        // still take the tap.
        child: GestureDetector(behavior: .opaque, onTap: onTap, child: trigger),
      ),
    );
  }
}

/// Gap between a [SonicDropdown] trigger and its menu.
const double _menuGap = 6;

/// Closest a menu may come to a screen edge or the soft keyboard.
const double _menuMargin = 8;

/// Tallest a menu's list grows before it scrolls.
const double _menuMaxHeight = 300;

/// The menu plate's vertical chrome: [SonicSurface] padding 6 plus a 1-px
/// border, top and bottom.
const double _menuChrome = 14;

/// Where a [SonicDropdown] menu opens: above or below its trigger, how tall its
/// list may grow, and how far it shifts sideways to stay on screen.
typedef DropdownPlacement = ({bool isAbove, double maxHeight, double dx});

/// Places a dropdown menu for a [trigger] (global rect) on a [screen] whose
/// bottom [bottomInset] px the soft keyboard covers. It opens below unless the
/// list doesn't fit there and there is more room above; `maxHeight` caps the
/// list to the chosen side's room and the usual 300 px; `dx` shifts the menu
/// back on screen horizontally. A menu that fits below is placed as before.
DropdownPlacement placeDropdownMenu({
  required Rect trigger,
  required Size screen,
  required double bottomInset,
  required double menuWidth,
  required double contentHeight,
}) {
  final wanted = math.min(contentHeight, _menuMaxHeight) + _menuChrome;
  final spaceBelow =
      screen.height - bottomInset - _menuMargin - _menuGap - trigger.bottom;
  final spaceAbove = trigger.top - _menuGap - _menuMargin;
  final isAbove = spaceBelow < wanted && spaceAbove > spaceBelow;
  final room = isAbove ? spaceAbove : spaceBelow;
  final maxLeft = math.max(_menuMargin, screen.width - _menuMargin - menuWidth);

  return (
    isAbove: isAbove,
    maxHeight: clampDouble(room - _menuChrome, 0, _menuMaxHeight),
    dx: clampDouble(trigger.left, _menuMargin, maxLeft) - trigger.left,
  );
}

class _DropdownMenu<T> extends HookWidget {
  const _DropdownMenu({
    required this.link,
    required this.triggerKey,
    required this.items,
    required this.value,
    required this.width,
    required this.onSelected,
    required this.onDismiss,
  });

  final LayerLink link;
  final GlobalKey triggerKey;
  final List<SonicItem<T>> items;
  final T? value;
  final double? width;
  final ValueChanged<T> onSelected;
  final VoidCallback onDismiss;

  // Widest item label + padding, but never narrower than the trigger — so a
  // content-sized menu never ellipsizes an option (its width previously just
  // tracked the trigger, truncating longer names).
  double _contentWidth(double minWidth) {
    final maxLabel = items.fold(0.0, (widest, it) {
      final tp = TextPainter(
        text: TextSpan(text: it.label, style: AppText.menuItem),
        textDirection: .ltr,
        maxLines: 1,
      )..layout();

      return math.max(widest, tp.width);
    });

    return math.max(minWidth, maxLabel + 32); // 14*2 padding + margin
  }

  // The list's natural height: one row per item, a menu-text line plus the
  // row's 10-px top and bottom padding.
  double _listHeight(TextScaler textScaler) {
    final painter = TextPainter(
      text: const TextSpan(text: 'Ag', style: AppText.menuItem),
      textDirection: .ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();

    final rowHeight = painter.height + 20;

    painter.dispose();

    return items.length * rowHeight;
  }

  // The trigger's rect on screen as last laid out; null before its layout.
  Rect? _triggerRect() {
    final box = triggerKey.currentContext?.findRenderObject() as RenderBox?;

    if (box == null || !box.attached || !box.hasSize) return null;

    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = SonicMetrics.of(context).isCompact;
    final screen = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final trigger = useState(_triggerRect());

    // The follower tracks the trigger's position by itself, but the placement
    // (side, height, shift) was worked out for where the trigger was. After
    // each frame, place the menu again if the trigger moved: the keyboard
    // closed and the dialog re-centred, the phone rotated. The menu stays
    // open; closing it here would kill a menu opened while a field blurs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      final now = _triggerRect();

      if (now != null && now != trigger.value) trigger.value = now;
    });

    final triggerRect = trigger.value;
    final menuWidth = math.min(
      width ?? _contentWidth(triggerRect?.width ?? 220),
      screen.width - 2 * _menuMargin,
    );

    final placement = triggerRect == null
        ? (isAbove: false, maxHeight: _menuMaxHeight, dx: 0.0)
        : placeDropdownMenu(
            trigger: triggerRect,
            screen: screen,
            bottomInset: bottomInset,
            menuWidth: menuWidth,
            contentHeight: _listHeight(MediaQuery.textScalerOf(context)),
          );

    // Compact (phones): system or browser Back closes the open menu instead
    // of popping the dialog or page under it (every pop entry on the route
    // hears it; this one only ever closes). Regular keeps today's behaviour:
    // Back and Escape pop the route, menu and all.
    return PopScope(
      canPop: !isCompact,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onDismiss();
      },
      child: Stack(
        children: [
          // outside-tap barrier
          Positioned.fill(
            child: GestureDetector(behavior: .opaque, onTap: onDismiss),
          ),
          CompositedTransformFollower(
            link: link,
            targetAnchor: placement.isAbove ? .topLeft : .bottomLeft,
            followerAnchor: placement.isAbove ? .bottomLeft : .topLeft,
            offset: Offset(
              placement.dx,
              placement.isAbove ? -_menuGap : _menuGap,
            ),
            // Shrink-wrapped, so a bottom anchor means the menu's own bottom
            // edge (an expanding Align would anchor the screen's).
            child: Align(
              alignment: .topLeft,
              widthFactor: 1,
              heightFactor: 1,
              child: SizedBox(
                width: menuWidth,
                child: SonicSurface(
                  radius: 11,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: placement.maxHeight),
                    child: SingleChildScrollView(
                      // Never the route's PrimaryScrollController: the work
                      // area under the menu already uses it.
                      primary: false,
                      child: Column(
                        mainAxisSize: .min,
                        children: [
                          for (final it in items)
                            _SonicMenuItem(
                              label: it.label,
                              isSelected: it.value == value,
                              onTap: () => onSelected(it.value),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SonicMenuItem extends StatelessWidget {
  const _SonicMenuItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: .opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? Palette.secondaryContainer : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: .ellipsis,
            style: AppText.menuItem.copyWith(
              color: isSelected
                  ? Palette.onSecondaryContainer
                  : Palette.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// The pop-up plate (dropdown menus, dialogs): a flat rounded [color] surface.
/// Its 1-px border is drawn in the plate's own color: it keeps the plate's
/// chrome (and the menu placement math, `_menuChrome`) unchanged while
/// showing no line.
class SonicSurface extends StatelessWidget {
  const SonicSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(6),
    this.radius = 12,
    this.color = Palette.surfaceContainer,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: .antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: color,
        border: Border.all(color: color),
      ),
      child: child,
    );
  }
}

/// A Material-free loading spinner: a rotating accent arc. Replaces
/// `CircularProgressIndicator` / `LinearProgressIndicator` in the kit.
class SonicSpinner extends HookWidget {
  const SonicSpinner({super.key, this.size = 26, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 900),
    );

    useEffect(() {
      controller.repeat();

      return null;
    }, const []);

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => CustomPaint(
          painter: _SpinnerPainter(
            turns: controller.value,
            color: color ?? Palette.accent,
          ),
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter({required this.turns, required this.color});

  final double turns;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.shortestSide * 0.12;

    canvas.drawArc(
      rect.deflate(stroke),
      turns * 2 * math.pi,
      math.pi * 1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) =>
      oldDelegate.turns != turns || oldDelegate.color != color;
}

/// A Material-free icon button: a tappable [Icon] with no ripple. Dims when
/// [onPressed] is null.
class SonicIconButton extends StatelessWidget {
  const SonicIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 22,
    this.color,
    this.padding = const EdgeInsets.all(8),
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: .opaque,
        onTap: onPressed,
        child: Opacity(
          opacity: isEnabled ? 1 : 0.4,
          child: Padding(
            padding: padding,
            child: Icon(
              icon,
              size: size,
              color: color ?? Palette.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Transparent, hit-testable space around [child] that forwards taps to
/// [onTap]: it grows a touch target without changing the look. [child] keeps
/// its own gestures (an inner button still wins its own taps). [padding] must
/// be carved from space the layout already reserves, so nothing moves. A null
/// [onTap] leaves the space inert: taps fall through to whatever lies under
/// it, exactly as before, so a target can grow in one layout only while the
/// tree stays the same in both.
class SonicHitArea extends StatelessWidget {
  const SonicHitArea({
    super.key,
    required this.onTap,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final VoidCallback? onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: onTap != null ? .opaque : .deferToChild,
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A drag-handle grip: an 8×2 array of small tactile dots. Shared by the
/// reorderable module cards and the dev-console resize divider so both read the
/// same. [isVisible] false keeps the footprint but paints no dots (fixed cards).
class DragGrip extends StatelessWidget {
  const DragGrip({super.key, this.isVisible = true});

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    Widget dot() => Container(
      width: 2,
      height: 2,
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: .circle,
        color: isVisible ? Palette.outlineVariant : null,
      ),
    );

    Widget row() =>
        Row(mainAxisSize: .min, children: List.generate(8, (_) => dot()));

    return Column(mainAxisSize: .min, children: [row(), row()]);
  }
}
