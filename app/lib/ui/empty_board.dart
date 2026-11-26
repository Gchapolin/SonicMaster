import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../l10n/shell_text.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'sonic_controls.dart';

/// The no-pedal screen (N_Inicio.dc.html): nine dashed empty slots in the
/// pedalboard's signal order, then the message and the demo button.
class EmptyBoard extends StatelessWidget {
  const EmptyBoard({super.key, required this.onDemo});

  final VoidCallback onDemo;

  // (tag, width, height) as in the prototype.
  static const _slots = [
    ('NR', 66.0, 114.0),
    ('FX1', 66.0, 114.0),
    ('DRV', 66.0, 114.0),
    ('AMP', 118.0, 76.0),
    ('IR', 88.0, 92.0),
    ('EQ', 66.0, 114.0),
    ('FX2', 66.0, 114.0),
    ('DLY', 66.0, 114.0),
    ('RVB', 66.0, 114.0),
  ];

  @override
  Widget build(BuildContext context) {
    final t = ShellText.current;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        // The prototype's band: the slots centred in a 210-px plate with a
        // hairline under it. Scaled down to fit a narrower work area.
        Container(
          key: const ValueKey('empty-band'),
          height: 210,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Palette.surfaceContainerLow,
            border: Border(bottom: BorderSide(color: Palette.outlineVariant)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: .center,
              children: [
                for (final (i, (tag, w, h)) in _slots.indexed) ...[
                  if (i > 0) const SizedBox(width: 12),
                  _Slot(tag, w, h),
                ],
              ],
            ),
          ),
        ),
        // Scrolls when the work area is too short for the message (phones).
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisSize: .min,
                    children: [
                      Icon(
                        Icons.power_off_outlined,
                        size: 56,
                        color: Palette.outline,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        t.noDeviceConnected,
                        textAlign: .center,
                        style: AppText.title.copyWith(color: Palette.onSurface),
                      ),
                      const SizedBox(height: 18),
                      SonicButton(label: t.tryDemo, onPressed: onDemo),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot(this.tag, this.width, this.height);

  final String tag;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          CustomPaint(
            key: const ValueKey('empty-slot'),
            size: Size(width, height),
            painter: _DashedBox(
              Palette.outlineVariant,
              Palette.surfaceContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(tag, style: AppText.section.copyWith(color: Palette.outline)),
        ],
      ),
    );
  }
}

class _DashedBox extends CustomPainter {
  const _DashedBox(this.line, this.fill);

  final Color line;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(9),
    );

    canvas.drawRRect(box, Paint()..color = fill);

    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final m in (Path()..addRRect(box.deflate(0.75))).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 8) {
        canvas.drawPath(m.extractPath(d, d + 4), stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBox old) => old.line != line || old.fill != fill;
}
