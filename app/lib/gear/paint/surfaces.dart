// Surface painters ported from the prototype (docs/design/prototipo/Peca.dc.html):
// glossy enamel (`paint`), wear (`wearLayers`), tolex (`tol`) and grille cloth
// (`cloth`). Not a pixel copy of the CSS, the same look at the same size.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../gear_specs.dart' show Grille, Tolex;

/// Port of the prototype's `shade(hex, amt)`: amt < 0 darkens towards black,
/// amt > 0 lightens towards white.
Color shadeColor(Color c, double amt) {
  double f(double x) => amt < 0 ? x * (1 + amt) : x + (1 - x) * amt;
  return Color.from(alpha: c.a, red: f(c.r), green: f(c.g), blue: f(c.b));
}

/// A CSS `radial-gradient(circle at fx fy, ...)` over [r]: the radius is the
/// distance from the centre to the farthest corner, [stops] are fractions of
/// it. Repeat a colour at two stops for a hard-edged band.
Paint cssRadial(Rect r, Offset at, List<Color> colors, List<double> stops) {
  final c = Offset(r.left + r.width * at.dx, r.top + r.height * at.dy);
  double d(Offset p) => (p - c).distance;
  final radius = [
    r.topLeft,
    r.topRight,
    r.bottomLeft,
    r.bottomRight,
  ].map(d).reduce(math.max);
  return Paint()..shader = ui.Gradient.radial(c, radius, colors, stops);
}

/// CSS `repeating-linear-gradient(angle, color 0 lineW, transparent lineW period)`:
/// thin parallel lines, angle in CSS degrees (0 = up, clockwise).
void paintHatch(
  Canvas canvas,
  Rect r,
  double cssDeg,
  Color color,
  double lineW,
  double period, {
  double phase = 0,
}) {
  if (period <= 0 || !period.isFinite) return;
  canvas.save();
  canvas.clipRect(r);
  canvas.translate(r.center.dx, r.center.dy);
  canvas.rotate(cssDeg * math.pi / 180);
  final half = r.longestSide;
  final p = Paint()
    ..color = color
    ..strokeWidth = lineW;
  for (double y = -half + phase; y <= half; y += period) {
    canvas.drawLine(Offset(-half, y), Offset(half, y), p);
  }
  canvas.restore();
}

/// Glossy enamel over a thick rounded edge (prototype `paint`): highlight
/// up-left, faint one low-right, lit top edge, shaded bottom and sides, and a
/// contact plus a soft drop shadow.
void paintEnamel(Canvas canvas, Rect r, Color color, {double radius = 6}) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
  canvas.drawRRect(
    rr.shift(const Offset(0, 12)),
    Paint()
      ..color = const Color(0x52000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
  );
  canvas.drawRRect(
    rr.shift(const Offset(0, 2)),
    Paint()
      ..color = const Color(0x8C000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
  );
  canvas.save();
  canvas.clipRRect(rr);
  canvas.drawRect(
    r,
    Paint()
      ..shader = ui.Gradient.linear(
        r.topCenter,
        r.bottomCenter,
        [shadeColor(color, 0.12), color, shadeColor(color, -0.2)],
        [0, 0.45, 1],
      ),
  );
  _ellipseGlow(
    canvas,
    Offset(r.left + r.width * 0.30, r.top + r.height * 0.16),
    r.width * 0.75,
    r.height * 0.38,
    const Color(0x4DFFFFFF),
  );
  _ellipseGlow(
    canvas,
    Offset(r.left + r.width * 0.72, r.top + r.height * 0.88),
    r.width * 0.55,
    r.height * 0.26,
    const Color(0x1AFFFFFF),
  );
  // Edges: inset light top / left, inset shade bottom / right.
  _insetEdge(canvas, rr, const Offset(0, 2), 1, const Color(0x61FFFFFF));
  _insetEdge(canvas, rr, const Offset(0, 4), 6, const Color(0x1AFFFFFF));
  _insetEdge(canvas, rr, const Offset(0, -4), 6, const Color(0x61000000));
  _insetEdge(canvas, rr, const Offset(4, 0), 6, const Color(0x14FFFFFF));
  _insetEdge(canvas, rr, const Offset(-4, 0), 6, const Color(0x33000000));
  canvas.restore();
}

/// CSS inset box-shadow: a frame around [rr] shifted by [o], blurred, drawn
/// inside the current clip (the caller clips to [rr]).
void _insetEdge(Canvas canvas, RRect rr, Offset o, double blur, Color color) {
  final path = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(rr.outerRect.inflate(blur * 2 + 10))
    ..addRRect(rr.shift(o));
  canvas.drawPath(
    path,
    Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2 + 0.01),
  );
}

/// CSS `radial-gradient(ellipse rx ry at c, color, transparent 70%)`.
void _ellipseGlow(Canvas canvas, Offset c, double rx, double ry, Color color) {
  if (rx <= 0 || ry <= 0) return;
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(rx, ry);
  canvas.drawCircle(
    Offset.zero,
    1,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1,
        [color, color.withValues(alpha: 0)],
        [0, 0.7],
      ),
  );
  canvas.restore();
}

/// Port of `wearLayers`: grey veil, rubbed corners, fine scratches. [amount]
/// 0..1 (0 = mint). Clipped to [r]; clip to a rounded body before calling.
void paintWear(Canvas canvas, Rect r, double amount) {
  if (amount.isNaN) return;
  final w = amount.clamp(0.0, 1.0);
  if (w == 0) return;
  Color g(double a) => Color.fromRGBO(205, 205, 200, a * w);
  canvas.save();
  canvas.clipRect(r);
  canvas.drawRect(r, Paint()..color = g(0.18));
  paintHatch(canvas, r, 23, Color.fromRGBO(0, 0, 0, 0.07 * w), 1, 13);
  paintHatch(canvas, r, 112, Color.fromRGBO(255, 255, 255, 0.06 * w), 1, 9);
  _ellipseGlow(canvas, r.topLeft, r.width * 0.34, r.height * 0.20, g(0.55));
  _ellipseGlow(canvas, r.topRight, r.width * 0.34, r.height * 0.20, g(0.5));
  _ellipseGlow(canvas, r.bottomLeft, r.width * 0.34, r.height * 0.18, g(0.5));
  _ellipseGlow(canvas, r.bottomRight, r.width * 0.34, r.height * 0.18, g(0.55));
  canvas.restore();
}

/// Port of `tol()`: 45 degree vinyl weave in [color], grain dots and a top
/// light falling to a shaded bottom.
///
/// With [kind] the weave is the prototype's TOLEX entry (tweed: three stripes
/// and an orange cast; blue: grain dots, no stripes); without it, a 45 degree
/// hatch at [color] shaded 25%.
void paintTolex(Canvas canvas, Rect r, Color color, {Tolex? kind}) {
  canvas.save();
  canvas.clipRect(r);
  canvas.drawRect(r, Paint()..color = color);
  switch (kind) {
    case null:
      paintHatch(canvas, r, 45, shadeColor(color, -0.25), 2, 4);
    case Tolex.black:
      paintHatch(canvas, r, 45, const Color(0xFF151515), 2, 4, phase: 2);
    case Tolex.blonde:
      paintHatch(canvas, r, 45, const Color(0xFFDCCCAA), 2, 4, phase: 2);
    case Tolex.orange:
      paintHatch(canvas, r, 45, const Color(0xFFD4661A), 2, 4, phase: 2);
    case Tolex.grey:
      paintHatch(canvas, r, 45, const Color(0xFF33363A), 2, 4, phase: 2);
    case Tolex.tweed:
      paintHatch(canvas, r, 45, const Color(0xFFA9864C), 2, 6, phase: 2);
      paintHatch(canvas, r, 45, const Color(0xFFC8A663), 2, 6, phase: 4);
      canvas.drawRect(r, Paint()..color = const Color(0x38BE781E));
    case Tolex.blue:
      _dots(canvas, r, 5, const Offset(1.5, 2), 1, const Color(0x1AFFFFFF));
  }
  _dots(canvas, r, 3, const Offset(0.75, 0.9), 0.5, const Color(0x0FFFFFFF));
  _dots(canvas, r, 4, const Offset(2.8, 2.8), 0.6, const Color(0x47000000));
  canvas.drawRect(
    r,
    Paint()
      ..shader = ui.Gradient.linear(
        r.topCenter,
        r.bottomCenter,
        const [
          Color(0x1AFFFFFF),
          Color(0x00FFFFFF),
          Color(0x00000000),
          Color(0x47000000),
        ],
        const [0, 0.28, 0.72, 1],
      ),
  );
  canvas.restore();
}

/// A grid of tiny dots, one per [cell] px tile at [at] within the tile.
void _dots(
  Canvas canvas,
  Rect r,
  double cell,
  Offset at,
  double radius,
  Color color,
) {
  final pts = <Offset>[];
  for (double y = r.top + at.dy; y < r.bottom; y += cell) {
    for (double x = r.left + at.dx; x < r.right; x += cell) {
      pts.add(Offset(x, y));
    }
  }
  canvas.drawPoints(
    ui.PointMode.points,
    pts,
    Paint()
      ..color = color
      ..strokeWidth = radius * 2
      ..strokeCap = StrokeCap.round,
  );
}

/// Port of `cloth()` + `clothEdge`: grille cloth in [color] with a woven
/// texture, a vignette (cloth stretched over the baffle) and a recessed edge.
/// [lightGrille] for pale cloths (cream, silver, tan): darker threads and a
/// softer vignette so the weave still reads. [piping]: the cream cord around
/// the cloth (`clothEdge(true)`). [kind] draws the prototype's GRILLE weave
/// under the common weave and vignette.
void paintGrille(
  Canvas canvas,
  Rect r,
  Color color, {
  bool lightGrille = false,
  bool piping = false,
  Grille? kind,
}) {
  canvas.save();
  canvas.clipRect(r);
  _cloth(canvas, r, color, kind);
  paintHatch(
    canvas,
    r,
    0,
    Color.fromRGBO(0, 0, 0, lightGrille ? 0.16 : 0.12),
    1,
    2,
  );
  paintHatch(
    canvas,
    r,
    90,
    lightGrille
        ? const Color.fromRGBO(0, 0, 0, 0.08)
        : const Color.fromRGBO(255, 255, 255, 0.05),
    1,
    2,
  );
  canvas.save();
  canvas.translate(r.left + r.width * 0.5, r.top + r.height * 0.42);
  canvas.scale(r.width * 0.85, r.height * 0.75);
  canvas.drawRect(
    Rect.fromCircle(center: Offset.zero, radius: 4),
    Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1,
        [
          const Color(0x12FFFFFF),
          Color.fromRGBO(0, 0, 0, lightGrille ? 0.24 : 0.38),
        ],
        const [0, 1],
      ),
  );
  canvas.restore();
  final rr = RRect.fromRectAndRadius(r, Radius.zero);
  if (piping) {
    // clothEdge(true), painted bottom layer first.
    _insetEdge(canvas, rr, const Offset(0, 7), 10, const Color(0x59000000));
    _ring(canvas, r, 4, const Color(0x80000000));
    _ring(canvas, r, 3, const Color(0x99FFFFFF), dy: 1);
    _ring(canvas, r, 3, const Color(0xFFECE5CF));
    _ring(canvas, r, 1, const Color(0x99000000));
  } else {
    canvas.drawRect(
      r.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x99000000),
    );
    _insetEdge(canvas, rr, const Offset(0, 7), 10, const Color(0x61000000));
  }
  canvas.restore();
}

/// CSS `inset 0 dy 0 <inset>px color`: a frame [inset] wide inside [r].
void _ring(Canvas canvas, Rect r, double inset, Color color, {double dy = 0}) =>
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(r)
        ..addRect(r.deflate(inset).shift(Offset(0, dy))),
      Paint()..color = color,
    );

/// The base of `cloth()`: the GRILLE[name] weave (flat [color] when no kind).
void _cloth(Canvas canvas, Rect r, Color color, Grille? kind) {
  Paint flat(Color c) => Paint()..color = c;
  void stripes(double deg, Color a, Color b, double wa, double wb) {
    // `repeating-linear-gradient(deg, a 0 wa, b wa wa+wb)`.
    canvas.drawRect(r, flat(b));
    paintHatch(canvas, r, deg, a, wa, wa + wb, phase: wa / 2);
  }

  void vertical(Color top, Color bottom) => canvas.drawRect(
    r,
    Paint()
      ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [top, bottom]),
  );

  void dots(Color c, double radius, double cell, Offset at) =>
      _dots(canvas, r, cell, at, radius, c);

  switch (kind) {
    case null:
      canvas.drawRect(r, flat(color));
    case Grille.silver:
      vertical(const Color(0xFFA9ABAE), const Color(0xFF8E9094));
      dots(const Color(0xFFD9D9D9), 0.6, 3, const Offset(1.5, 1.5));
    case Grille.oxblood:
      stripes(90, const Color(0xFF6A2E24), const Color(0xFF4F2018), 2, 2);
    case Grille.diamond:
      canvas.drawRect(r, flat(const Color(0xFF2A1D13)));
      const gold = Color.fromRGBO(214, 180, 110, 0.55);
      paintHatch(canvas, r, 45, gold, 1, 11);
      paintHatch(canvas, r, -45, gold, 1, 11);
    case Grille.saltpepper:
      canvas.drawRect(r, flat(const Color(0xFF5C5C5C)));
      dots(const Color(0xFFA8A8A8), 0.6, 3, const Offset(1.5, 1.5));
      dots(const Color(0xFF2A2A2A), 0.6, 3, const Offset(3, 3));
    case Grille.black:
      stripes(45, const Color(0xFF222222), const Color(0xFF161616), 1, 2);
    case Grille.jc:
      stripes(0, const Color(0xFFB9BBBE), const Color(0xFF1E1E1E), 7, 2);
    case Grille.tan:
      stripes(0, const Color(0xFFB59B74), const Color(0xFF9E8560), 2, 2);
    case Grille.cream:
      stripes(90, const Color(0xFFE3D9C2), const Color(0xFFCFC3A8), 2, 2);
    case Grille.basket:
      stripes(0, const Color(0xFFCDB88E), const Color(0xFFB29D73), 3, 3);
    case Grille.plate:
      vertical(const Color(0xFFA2A6AC), const Color(0xFF6F747A));
      const white = Color.fromRGBO(255, 255, 255, 0.35);
      paintHatch(canvas, r, 60, white, 2, 9);
      paintHatch(canvas, r, -60, white, 2, 9);
    case Grille.metal:
      canvas.drawRect(r, flat(const Color(0xFF2E2F31)));
      dots(const Color(0xFF0A0A0A), 1.2, 5, const Offset(2.5, 2.5));
    case Grille.check:
      // 8px tiles, 4px squares: top-right and bottom-left dark.
      canvas.drawRect(r, flat(const Color(0xFF33415E)));
      final dark = Path();
      for (var y = r.top; y < r.bottom; y += 8) {
        for (var x = r.left; x < r.right; x += 8) {
          dark
            ..addRect(Rect.fromLTWH(x + 4, y, 4, 4))
            ..addRect(Rect.fromLTWH(x, y + 4, 4, 4));
        }
      }
      canvas.drawPath(dark, flat(const Color(0xFF1E2638)));
  }
}
