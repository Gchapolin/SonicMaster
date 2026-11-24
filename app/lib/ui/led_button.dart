import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// A module on/off control drawn as a flat Material status dot: filled in the
/// primary color when [isOn], an outline ring when off. Carries an optional
/// short [label] beside the dot; [onTap] toggles (a null [onTap] disables +
/// dims it). It keeps the old lit button's box (height, min width), so the
/// layouts around it do not move.
class LedButton extends StatelessWidget {
  const LedButton({
    super.key,
    required this.isOn,
    required this.label,
    this.onTap,
    this.height = 26,
  });

  final bool isOn;
  final String label;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dotSize = height * 0.4;

    return MouseRegion(
      cursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: height,
            constraints: BoxConstraints(minWidth: height * 1.6),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: Size.square(dotSize),
                  painter: _DotPainter(isOn: isOn),
                ),
                if (label.isNotEmpty) ...[
                  SizedBox(width: height * 0.25),
                  Text(
                    label,
                    style: AppText.ledLabel.copyWith(
                      color: isOn
                          ? Palette.onSurface
                          : Palette.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter({required this.isOn});

  final bool isOn;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    const ring = 1.5;

    canvas.drawCircle(
      size.center(Offset.zero),
      isOn ? r : r - ring / 2,
      isOn
          ? (Paint()..color = Palette.primary)
          : (Paint()
              ..color = Palette.outline
              ..style = PaintingStyle.stroke
              ..strokeWidth = ring),
    );
  }

  @override
  bool shouldRepaint(_DotPainter old) => old.isOn != isOn;
}
