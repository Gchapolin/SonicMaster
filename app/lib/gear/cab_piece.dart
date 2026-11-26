// The speaker cabinets (and the User IR cab), ported from the prototype's
// isCab branch (docs/design/prototipo/Peca.dc.html): tolex box with depth,
// grille cloth with optional piping, speakers behind the cloth, a slant seam,
// chrome corners and the model badge. Sizes are in logical px.
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';

import 'gear_specs.dart';
import 'paint/surfaces.dart';

/// A speaker cabinet for [model], drawn from [spec]. [wear] 0..1 rubs the
/// tolex (the grille cloth stays clean).
class CabPiece extends StatelessWidget {
  const CabPiece({
    super.key,
    required this.spec,
    required this.model,
    this.wear = 0.6,
  });

  final CabSpec spec;
  final String model;
  final double wear;

  @override
  Widget build(BuildContext context) {
    final n = spec.speakers, inch = spec.inch;
    final unit = inch == 8
        ? 54.0
        : inch == 10
        ? 52.0
        : 62.0;
    var cols = n == 1 ? 1 : 2, rows = n <= 2 ? 1 : 2;
    if (inch == 10 && n == 2) (cols, rows) = (1, 2);
    final w = cols * unit + 30;
    final h = rows * unit + 36 + (inch == 10 && n == 4 ? 6 : 0);
    // Grille: the content box (1px border, padding 9 9 18); speakers sit in a
    // grid inside its 6px padding with 4px gaps, 92% of the cell wide.
    final gw = w - 20, gh = h - 29;
    final d = (gw - 12 - 4 * (cols - 1)) / cols * 0.92;

    final grid = <Widget>[];
    for (var r = 0; r < rows; r++) {
      if (r > 0) grid.add(const SizedBox(height: 4));
      final row = <Widget>[];
      for (var c = 0; c < cols; c++) {
        if (c > 0) row.add(const SizedBox(width: 4));
        final i = r * cols + c;
        row.add(
          Expanded(
            child: Center(
              child: i < n
                  ? SizedBox.square(
                      key: ValueKey('speaker-$i'),
                      dimension: d,
                      child: const CustomPaint(painter: _SpeakerPainter()),
                    )
                  : null,
            ),
          ),
        );
      }
      grid.add(Expanded(child: Row(children: row)));
    }

    final gold = spec.grille.goldBadgeCab;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _BoxPainter(spec.tolex, wear)),
          ),
          Positioned(
            key: const Key('cab-grille'),
            left: 10,
            top: 10,
            width: gw,
            height: gh,
            child: CustomPaint(
              painter: _GrillePainter(spec.grille, spec.slant, spec.piping),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(children: grid),
              ),
            ),
          ),
          if (spec.corners)
            for (final (i, (x, y)) in const [
              (2.0, 2.0),
              (-2.0, 2.0),
              (2.0, -2.0),
              (-2.0, -2.0),
            ].indexed)
              Positioned(
                key: Key('cab-corner-$i'),
                left: x > 0 ? x : null,
                right: x < 0 ? -x : null,
                top: y > 0 ? y : null,
                bottom: y < 0 ? -y : null,
                width: 12,
                height: 12,
                child: const CustomPaint(painter: _CornerPainter()),
              ),
          // After the corners so a long name is never covered by them. The
          // plate sizes to its text (`white-space: nowrap`), border outside
          // the 6px padding.
          Positioned(
            key: const Key('cab-badge-pos'),
            left: 0,
            right: 0,
            bottom: 4,
            child: Center(
              child: OverflowBox(
                maxWidth: double.infinity,
                fit: OverflowBoxFit.deferToChild,
                child: _badge(gold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // The model name on a metal plate: chrome on a dark cloth, black enamel
  // with gold lettering on a light one.
  Widget _badge(bool gold) => Container(
    key: const Key('cab-badge'),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(3),
      border: Border.all(
        color: gold ? const Color(0xFF8C7334) : const Color(0xFF6E6E6E),
      ),
      gradient: gold
          ? const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A2A2A), Color(0xFF0E0E0E)],
            )
          : const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF7F7F7),
                Color(0xFFC4C4C4),
                Color(0xFFE6E6E6),
                Color(0xFFA9A9A9),
              ],
              stops: [0, 0.48, 0.52, 1],
            ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x8C000000),
          offset: Offset(0, 1),
          blurRadius: 2,
        ),
        BoxShadow(
          color: Color(0x40000000),
          offset: Offset(0, 3),
          blurRadius: 5,
        ),
      ],
    ),
    child: Text(
      model.toUpperCase(),
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontFamily: 'Barlow Condensed',
        fontFamilyFallback: const ['Oswald'],
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        height: 1.2,
        color: gold ? const Color(0xFFD9B860) : const Color(0xFF1A1A1A),
        shadows: [
          Shadow(
            color: gold ? const Color(0xCC000000) : const Color(0xB3FFFFFF),
            offset: const Offset(0, 1),
          ),
        ],
      ),
    ),
  );
}

// CSS `inset dx dy blur color`, drawn inside the current clip.
void _inset(Canvas c, RRect rr, Offset o, double blur, Color color) =>
    c.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rr.outerRect.inflate(blur * 2 + 10))
        ..addRRect(rr.shift(o)),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2 + 0.01),
    );

/// The box (prototype `boxDepth` over `tol()`): drop shadows, tolex, wear,
/// lit top edge, shaded bottom and sides, 1px near-black border.
class _BoxPainter extends CustomPainter {
  const _BoxPainter(this.tolex, this.wear);
  final Tolex tolex;
  final double wear;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(6));
    for (final (dy, blur, a) in const [(16.0, 28.0, 0x5C), (2.0, 2.0, 0x99)]) {
      canvas.drawRRect(
        rr.shift(Offset(0, dy)),
        Paint()
          ..color = Color.fromARGB(a, 0, 0, 0)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
      );
    }
    canvas.save();
    canvas.clipRRect(rr);
    paintTolex(canvas, r, tolex.color, kind: tolex);
    paintWear(canvas, r, wear);
    final inner = rr.deflate(1);
    _inset(canvas, inner, const Offset(0, 2), 1, const Color(0x29FFFFFF));
    _inset(canvas, inner, const Offset(0, -4), 6, const Color(0x8C000000));
    _inset(canvas, inner, const Offset(4, 0), 5, const Color(0x0DFFFFFF));
    _inset(canvas, inner, const Offset(-4, 0), 5, const Color(0x52000000));
    canvas.restore();
    canvas.drawRRect(
      rr.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF050505),
    );
  }

  @override
  bool shouldRepaint(_BoxPainter old) => old.tolex != tolex || old.wear != wear;
}

/// The baffle: cloth (`cloth()` + plain `clothEdge`), the slant seam drawn
/// over the whole rectangle, and the cream piping on top.
class _GrillePainter extends CustomPainter {
  const _GrillePainter(this.cloth, this.slant, this.piping);
  final Grille cloth;
  final bool slant;
  final bool piping;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    paintGrille(
      canvas,
      r,
      cloth.color,
      lightGrille: cloth.lightAmp,
      kind: cloth,
    );
    if (slant) {
      // The upper baffle leans back: it catches more light above a seam just
      // under the middle (dark line, then a thin highlight).
      canvas.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.linear(
            r.topCenter,
            r.bottomCenter,
            const [
              Color(0x1AFFFFFF),
              Color(0x1AFFFFFF),
              Color(0x73000000),
              Color(0x73000000),
              Color(0x0FFFFFFF),
              Color(0x0FFFFFFF),
              Color(0x00000000),
            ],
            const [0, 0.46, 0.46, 0.475, 0.475, 0.485, 0.485],
          ),
      );
    }
    if (piping) {
      Paint ring(Color c, double width) => Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = c;
      canvas.drawRect(r.deflate(3.5), ring(const Color(0x80000000), 1));
      canvas.drawRect(r.deflate(2), ring(const Color(0xFFECE5CF), 2));
      canvas.drawLine(
        Offset(r.left + 3, r.top + 3.5),
        Offset(r.right - 3, r.top + 3.5),
        ring(const Color(0x99FFFFFF), 1),
      );
      canvas.drawRect(r.deflate(0.5), ring(const Color(0x99000000), 1));
    }
  }

  @override
  bool shouldRepaint(_GrillePainter old) =>
      old.cloth != cloth || old.slant != slant || old.piping != piping;
}

/// A speaker behind the cloth (`speakerBg`): dust cap, cone and surround.
class _SpeakerPainter extends CustomPainter {
  const _SpeakerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    Color k(double a) => Color.fromRGBO(0, 0, 0, a);
    canvas.drawOval(
      r,
      cssRadial(
        r,
        const Offset(0.5, 0.5),
        [k(.42), k(.42), k(.16), k(.16), k(.10), k(.10), k(.28), k(.28), k(0)],
        const [0, .11, .13, .30, .32, .60, .62, .67, .69],
      ),
    );
  }

  @override
  bool shouldRepaint(_SpeakerPainter old) => false;
}

/// A chrome corner protector.
class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(3));
    canvas.drawRRect(
      rr.shift(const Offset(0, 1)),
      Paint()
        ..color = const Color(0x99000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    canvas.drawRRect(
      rr,
      cssRadial(
        r,
        const Offset(0.35, 0.30),
        const [
          Color(0xFFFFFFFF),
          Color(0xFFD2D2D2),
          Color(0xFF8C8C8C),
          Color(0xFF5E5E5E),
        ],
        const [0, 0.30, 0.75, 1],
      ),
    );
    canvas.save();
    canvas.clipRRect(rr);
    _inset(canvas, rr, const Offset(0, -1), 1, const Color(0x59000000));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
