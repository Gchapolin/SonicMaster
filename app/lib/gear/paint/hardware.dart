// Small hardware painters ported from the prototype (Peca.dc.html): LED,
// input jack, footswitch (`chrome(s)`: washer, hex nut, cap), pilot jewel and
// a panel screw. Each is drawn centred on [c]; [size] is the diameter.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart';

import 'surfaces.dart';

void _shadow(
  Canvas canvas,
  Offset c,
  double r,
  double dy,
  double blur,
  Color color,
) {
  canvas.drawCircle(
    c.translate(0, dy),
    r,
    Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2 + 0.01),
  );
}

/// `box-shadow: 0 0 4px` -> sigma 2, no spread (the glow is the LED's own shape).
@visibleForTesting
const ledGlowSigma = 2.0;

/// Status LED. On: red dome with a glow. Off: dark #3A1512 with an inner shade.
void paintLed(Canvas canvas, Offset c, double size, bool on) {
  final r = size / 2;
  final box = Rect.fromCircle(center: c, radius: r);
  if (on) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0x99FF3B30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, ledGlowSigma),
    );
    canvas.drawCircle(
      c,
      r,
      cssRadial(
        box,
        const Offset(0.45, 0.40),
        const [Color(0xFFFF8A80), Color(0xFFF0382C)],
        const [0, 0.7],
      ),
    );
  } else {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF3A1512));
    canvas.save();
    canvas.clipPath(Path()..addOval(box));
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(box.inflate(4))
        ..addOval(box.shift(Offset(0, size * 0.14))),
      Paint()
        ..color = const Color(0xCC000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.08),
    );
    canvas.restore();
  }
}

/// Input jack: black hole in a chrome nut.
void paintJack(Canvas canvas, Offset c, double size) {
  final r = size / 2;
  _shadow(canvas, c, r, size * 0.09, size * 0.09, const Color(0x80000000));
  canvas.drawCircle(
    c,
    r,
    cssRadial(
      Rect.fromCircle(center: c, radius: r),
      const Offset(0.5, 0.5),
      const [
        Color(0xFF050505), Color(0xFF050505), //
        Color(0xFFEDEDED), Color(0xFFEDEDED), //
        Color(0xFF8A8A8A), Color(0xFF8A8A8A),
      ],
      // CSS stops are of the farthest-corner radius (r * sqrt2).
      const [0, 0.34, 0.37, 0.52, 0.60, 1],
    ),
  );
}

/// Footswitch from above (prototype `chrome(s)`): light washer (s + 12),
/// hex nut (s + 5), domed chrome cap (s - 2).
void paintFootswitch(Canvas canvas, Offset c, double s) {
  final wr = (s + 12) / 2;
  _shadow(canvas, c, wr, 3, 6, const Color(0x33000000));
  _shadow(canvas, c, wr, 1, 2, const Color(0x73000000));
  canvas.drawCircle(
    c,
    wr,
    cssRadial(
      Rect.fromCircle(center: c, radius: wr),
      const Offset(0.40, 0.35),
      const [Color(0xFFFFFFFF), Color(0xFFDADADA), Color(0xFFA9A9A9)],
      const [0, 0.55, 1],
    ),
  );
  final n = (s + 5);
  final nb = Rect.fromCenter(center: c, width: n, height: n);
  Offset p(double x, double y) =>
      Offset(nb.left + nb.width * x, nb.top + nb.height * y);
  final hex = Path()
    ..moveTo(p(0.25, 0.06).dx, p(0.25, 0.06).dy)
    ..lineTo(p(0.75, 0.06).dx, p(0.75, 0.06).dy)
    ..lineTo(p(1, 0.5).dx, p(1, 0.5).dy)
    ..lineTo(p(0.75, 0.94).dx, p(0.75, 0.94).dy)
    ..lineTo(p(0.25, 0.94).dx, p(0.25, 0.94).dy)
    ..lineTo(p(0, 0.5).dx, p(0, 0.5).dy)
    ..close();
  canvas.drawPath(
    hex,
    Paint()
      ..shader = ui.Gradient.linear(
        nb.topLeft,
        nb.bottomRight,
        const [
          Color(0xFFFAFAFA),
          Color(0xFF9A9A9A),
          Color(0xFFDCDCDC),
          Color(0xFF7E7E7E),
        ],
        const [0, 0.5, 0.7, 1],
      ),
  );
  final cr = (s - 2) / 2;
  _shadow(canvas, c, cr, 1, 2, const Color(0x8C000000));
  canvas.drawCircle(
    c,
    cr,
    cssRadial(
      Rect.fromCircle(center: c, radius: cr),
      const Offset(0.38, 0.30),
      const [
        Color(0xFFFFFFFF),
        Color(0xFFE2E2E2),
        Color(0xFF9C9C9C),
        Color(0xFF6A6A6A),
      ],
      const [0, 0.22, 0.62, 1],
    ),
  );
}

/// Faceted red pilot jewel in a chrome bezel; glows when [on], dark when off.
void paintJewel(Canvas canvas, Offset c, double size, bool on) {
  final r = size / 2;
  if (on) {
    canvas.drawCircle(
      c,
      r + 3,
      Paint()
        ..color = const Color(0xB3FF3B30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }
  canvas.drawCircle(c, r + 3, Paint()..color = const Color(0x80000000));
  canvas.drawCircle(c, r + 2, Paint()..color = const Color(0xFFD2D2D2));
  if (!on) {
    canvas.drawCircle(
      c,
      r,
      cssRadial(
        Rect.fromCircle(center: c, radius: r),
        const Offset(0.4, 0.35),
        const [Color(0xFF5A3532), Color(0xFF2A0D0B)],
        const [0, 1],
      ),
    );
    return;
  }
  // CSS conic starts at 12 o'clock (here "from 10deg"); Flutter's sweep at
  // 3 o'clock, so rotate the canvas instead of the shader.
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(-math.pi / 2 + 10 * math.pi / 180);
  canvas.drawCircle(
    Offset.zero,
    r,
    Paint()
      ..shader = ui.Gradient.sweep(
        Offset.zero,
        const [
          Color(0xFFFF8A80), Color(0xFFA8140C), Color(0xFFFF7065), //
          Color(0xFF8E1009), Color(0xFFFF8A80), Color(0xFFB5160D), //
          Color(0xFFFF6A60), Color(0xFFA8140C), Color(0xFFFF8A80),
        ],
        [for (var i = 0; i < 9; i++) i / 8],
      ),
  );
  canvas.restore();
  canvas.drawCircle(
    c,
    r,
    cssRadial(
      Rect.fromCircle(center: c, radius: r),
      const Offset(0.38, 0.32),
      const [Color(0xCCFFFFFF), Color(0xCCFFFFFF), Color(0x00FFFFFF)],
      const [0, 0.12, 0.30],
    ),
  );
}

/// Flat panel screw: chrome head with a slot at a fixed slant.
void paintScrew(Canvas canvas, Offset c, double size) {
  final r = size / 2;
  _shadow(canvas, c, r, 1, 2, const Color(0x73000000));
  canvas.drawCircle(
    c,
    r,
    cssRadial(
      Rect.fromCircle(center: c, radius: r),
      const Offset(0.38, 0.32),
      const [Color(0xFFF2F2F2), Color(0xFFB0B0B0), Color(0xFF6A6A6A)],
      const [0, 0.45, 1],
    ),
  );
  final d = Offset(math.cos(0.6), math.sin(0.6)) * (r * 0.75);
  canvas.drawLine(
    c - d,
    c + d,
    Paint()
      ..color = const Color(0xFF3A3A3A)
      ..strokeWidth = math.max(1, size * 0.12)
      ..strokeCap = StrokeCap.round,
  );
}
