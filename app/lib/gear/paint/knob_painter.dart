// Knob caps ported from the prototype's `knobLook` and `knob()` (Peca.dc.html):
// a cap gradient per style, a gloss spot, a dark base ring, shadows, and a
// pointer line (or a chicken-head pointer) rotated by value.
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/rendering.dart';

import '../gear_specs.dart';
import 'surfaces.dart';

class _Look {
  const _Look(this.at, this.colors, this.stops, this.pointer);
  final Offset at;
  final List<Color> colors;
  final List<double> stops;
  final Color pointer;
}

const _c = Offset(0.5, 0.5);

// [gradient centre, colours, stops, pointer colour], straight from knobLook.
const _looks = <KnobStyle, _Look>{
  KnobStyle.boss: _Look(
    Offset(0.5, 0.4),
    [
      Color(0xFFE4E4E4),
      Color(0xFFE4E4E4),
      Color(0xFF2A2A2A),
      Color(0xFF2A2A2A),
    ],
    [0, 0.28, 0.31, 1],
    Color(0xFFFFFFFF),
  ),
  KnobStyle.black: _Look(
    Offset(0.5, 0.35),
    [Color(0xFF45484E), Color(0xFF1C1D20)],
    [0, 0.75],
    Color(0xFFF3EDE2),
  ),
  KnobStyle.mxr: _Look(
    Offset(0.5, 0.35),
    [Color(0xFF3C3C3C), Color(0xFF121212)],
    [0, 0.75],
    Color(0xFFFFFFFF),
  ),
  KnobStyle.chickenBlack: _Look(
    Offset(0.5, 0.35),
    [Color(0xFF3A3A3A), Color(0xFF111111)],
    [0, 0.75],
    Color(0xFFF2F2F2),
  ),
  KnobStyle.chickenCream: _Look(
    Offset(0.5, 0.35),
    [Color(0xFFF7EEDC), Color(0xFFDCCB9F)],
    [0, 0.75],
    Color(0xFF2A1E0A),
  ),
  KnobStyle.chickenBrown: _Look(
    Offset(0.5, 0.35),
    [Color(0xFF7A5233), Color(0xFF4A2F1B)],
    [0, 0.75],
    Color(0xFFF1E3C4),
  ),
  KnobStyle.skirt: _Look(
    _c,
    [
      Color(0xFF1A1A1A),
      Color(0xFF1A1A1A),
      Color(0xFFD6D6D6),
      Color(0xFFD6D6D6),
    ],
    [0, 0.52, 0.55, 1],
    Color(0xFFFFFFFF),
  ),
  KnobStyle.goldcap: _Look(
    _c,
    [
      Color(0xFFDCB75E),
      Color(0xFFDCB75E),
      Color(0xFF151515),
      Color(0xFF151515),
    ],
    [0, 0.38, 0.42, 1],
    Color(0xFF151515),
  ),
  KnobStyle.chrome: _Look(
    Offset(0.42, 0.35),
    [Color(0xFFFFFFFF), Color(0xFFB9B9B9), Color(0xFF6F6F6F)],
    [0, 0.45, 1],
    Color(0xFF1E1E1E),
  ),
  KnobStyle.blackFlat: _Look(
    Offset(0.5, 0.4),
    [Color(0xFF2A2A2A), Color(0xFF151515)],
    [0, 0.8],
    Color(0xFFFFFFFF),
  ),
  KnobStyle.silvercap: _Look(
    _c,
    [
      Color(0xFFD2D2D2),
      Color(0xFFD2D2D2),
      Color(0xFF1A1A1A),
      Color(0xFF1A1A1A),
    ],
    [0, 0.34, 0.37, 1],
    Color(0xFFFFFFFF),
  ),
  KnobStyle.cream: _Look(
    Offset(0.5, 0.35),
    [Color(0xFFF7EEDC), Color(0xFFE1D1AA)],
    [0, 0.75],
    Color(0xFF2A2A2A),
  ),
  KnobStyle.alu: _Look(
    _c,
    [
      Color(0xFFEDEDED),
      Color(0xFFEDEDED),
      Color(0xFFC9C9C9),
      Color(0xFF9E9E9E),
    ],
    [0, 0.52, 0.55, 1],
    Color(0xFFE0302A),
  ),
  KnobStyle.white: _Look(
    Offset(0.5, 0.35),
    [Color(0xFFFFFFFF), Color(0xFFD9D9D9)],
    [0, 0.8],
    Color(0xFF222222),
  ),
};

/// CSS blur radii of the cap shadows (`0 4px 8px`, `0 2px 2px`) and the width
/// of the base ring (`0 0 0 1px`); `_disc` turns blur into sigma.
@visibleForTesting
const knobShadowBlur = (long: 8.0, short: 2.0);
@visibleForTesting
const knobBaseRing = 1.0;

bool _isChicken(KnobStyle s) =>
    s == KnobStyle.chickenBlack ||
    s == KnobStyle.chickenCream ||
    s == KnobStyle.chickenBrown;

/// A knob of [style] at [value] (0..100, clamped), sweeping -135..+135 degrees.
/// Fills the shortest side of its size; a chicken-head pointer pokes out past
/// the cap like the real thing (and like the prototype).
class GearKnobPainter extends CustomPainter {
  GearKnobPainter({required this.style, required double value})
    : value = value.isNaN ? 0.0 : value.clamp(0.0, 100.0).toDouble();

  final KnobStyle style;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final look = _looks[style]!;
    final d = size.shortestSide;
    if (d <= 0) return;
    final c = size.center(Offset.zero);
    final r = d / 2;
    final cap = Rect.fromCircle(center: c, radius: r);

    // Soft long shadow, short firm one, dark base ring.
    _disc(
      canvas,
      c.translate(0, 4),
      r,
      knobShadowBlur.long,
      const Color(0x40000000),
    );
    _disc(
      canvas,
      c.translate(0, 2),
      r,
      knobShadowBlur.short,
      const Color(0x73000000),
    );
    canvas.drawCircle(
      c,
      r + knobBaseRing,
      Paint()..color = const Color(0x73000000),
    );

    canvas.drawCircle(c, r, cssRadial(cap, look.at, look.colors, look.stops));

    canvas.save();
    canvas.clipPath(Path()..addOval(cap));
    // Gloss spot up-left.
    canvas.drawCircle(
      c,
      r,
      cssRadial(
        cap,
        const Offset(0.36, 0.28),
        const [Color(0x8CFFFFFF), Color(0x00FFFFFF)],
        const [0, 0.32],
      ),
    );
    // Inset: shade at the bottom, a lit rim at the top.
    _inset(canvas, cap, const Offset(0, -2), 3, const Color(0x4D000000));
    _inset(canvas, cap, const Offset(0, 1), 1, const Color(0x59FFFFFF));
    canvas.restore();

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate((-135 + 2.7 * value) * math.pi / 180);
    if (_isChicken(style)) {
      _chicken(canvas, d, look);
    } else {
      final w = math.max(2.0, (d * 0.1).roundToDouble());
      final top = math.max(2.0, (d * 0.1).roundToDouble());
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w / 2, -r + top, w, (d * 0.36).roundToDouble()),
          const Radius.circular(1),
        ),
        Paint()..color = look.pointer,
      );
    }
    canvas.restore();
  }

  // Chicken-head: a tapered bar in the cap's material, its tip poking past
  // the rim, a stripe of pointer colour along the top edge.
  void _chicken(Canvas canvas, double d, _Look look) {
    final w = math.max(3.0, (d * 0.22).roundToDouble());
    final h = (d * 0.62).roundToDouble();
    final rect = Rect.fromLTWH(
      -w / 2,
      -d / 2 - (d * 0.18).roundToDouble(),
      w,
      h,
    );
    final body = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.elliptical(w * 0.4, h * 0.4),
      topRight: Radius.elliptical(w * 0.4, h * 0.4),
      bottomLeft: Radius.elliptical(w * 0.2, h * 0.2),
      bottomRight: Radius.elliptical(w * 0.2, h * 0.2),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 1)),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
    );
    canvas.drawRRect(
      body,
      cssRadial(rect, const Offset(0.5, 0.2), look.colors, look.stops),
    );
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, w, 2),
      Paint()..color = look.pointer,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(GearKnobPainter old) =>
      old.style != style || old.value != value;
}

void _disc(Canvas canvas, Offset c, double r, double blur, Color color) =>
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
    );

void _inset(Canvas canvas, Rect cap, Offset o, double blur, Color color) =>
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(cap.inflate(blur * 2 + 4))
        ..addOval(cap.shift(o)),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
    );
