// Amps, ported from the prototype's isHead / isCombo branches
// (docs/design/prototipo/Peca.dc.html): tolex box with depth, grille cloth
// (with piping), control panel (jacks, knobs, head toggles, pilot jewel),
// leather handle and the model name on a metal badge. Sizes in logical px.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'gear_specs.dart';
import 'paint/hardware.dart';
import 'paint/knob_painter.dart';
import 'paint/surfaces.dart';
import 'pedal_piece.dart' show KnobDrag, PaintBox;

// The prototype's `vals`: knob positions when no value is given.
const _defaultVals = <double>[62, 45, 70, 38, 55, 66, 48, 58];

// Combos with more than one speaker (the prototype's `spk`).
const _speakers = {
  'Dark Twin': 2,
  'Jazz 120': 2,
  'Voks 30N': 2,
  'Voks 30TB': 2,
  'B-Man N': 4,
  'B-Man B': 4,
};

TextStyle _font(
  double size,
  Color color, {
  double spacing = 0.5,
  List<Shadow>? shadows,
}) => TextStyle(
  fontFamily: 'Barlow Condensed',
  fontFamilyFallback: const ['Oswald'],
  fontSize: size,
  fontWeight: FontWeight.w700,
  letterSpacing: spacing,
  height: 1.2,
  color: color,
  shadows: shadows,
);

/// An amp for [model], drawn from [spec]: a head (250x104) or a combo
/// (230x184). [values] are 0..100 per knob (null = the prototype's defaults);
/// dragging a knob up raises it and reports `(index, value)` to [onKnob].
/// Tapping the pilot jewel calls [onSwitch]; [lit] lights it.
class AmpPiece extends StatelessWidget {
  const AmpPiece({
    super.key,
    required this.spec,
    required this.model,
    this.values,
    this.onKnob,
    this.onSwitch,
    this.lit = true,
    this.wear = 0.6,
  });

  final AmpSpec spec;
  final String model;
  final List<double?>? values;
  final ValueChanged<(int, double)>? onKnob;
  final VoidCallback? onSwitch;
  final bool lit;
  final double wear;

  // The prototype's lightGrille list (see Grille.lightAmp).
  bool get _lightGrille => spec.grille.lightAmp;

  double _value(int i) {
    final v = values != null && i < values!.length ? values![i] : null;
    return v ?? _defaultVals[i % _defaultVals.length];
  }

  @override
  Widget build(BuildContext context) {
    final w = spec.isHead ? 250.0 : 230.0;
    final h = spec.isHead ? 104.0 : 184.0;
    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(
        painter: _BoxPainter(spec.tolex, spec.isHead ? 6 : 8),
        child: Padding(
          padding: const EdgeInsets.all(1), // the 1px #050505 border
          child: spec.isHead ? _head() : _combo(),
        ),
      ),
    );
  }

  Widget _head() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(height: 13, child: Center(child: _handle(64))),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: CustomPaint(
            painter: _GrillePainter(spec.grille, _lightGrille, spec.piping, 0),
            child: Center(child: _badge()),
          ),
        ),
      ),
      _panel(radius: 0, toggles: true),
      const SizedBox(height: 8),
    ],
  );

  Widget _combo() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3, bottom: 4),
          child: Center(child: _handle(66)),
        ),
        _panel(radius: 2, toggles: false),
        const SizedBox(height: 6),
        Expanded(
          child: CustomPaint(
            painter: _GrillePainter(
              spec.grille,
              _lightGrille,
              spec.piping,
              _speakers[model] ?? 1,
            ),
            child: Stack(
              children: [Positioned(left: 10, top: 8, child: _badge())],
            ),
          ),
        ),
      ],
    ),
  );

  // Leather strap between chrome end caps.
  Widget _handle(double w) => PaintBox(w, 7, (c, s) {
    final rr = RRect.fromRectAndRadius(
      Offset.zero & s,
      const Radius.circular(4),
    );
    _drop(c, rr, 1, 2, const Color(0x99000000));
    c.save();
    c.clipRRect(rr);
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF2B1F17));
    final cap = Paint()..color = const Color(0xFFC9C9C9);
    c.drawRect(Rect.fromLTWH(0, 0, 9, s.height), cap);
    c.drawRect(Rect.fromLTWH(s.width - 9, 0, 9, s.height), cap);
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height), const [
          Color(0x2EFFFFFF),
          Color(0x40000000),
        ]),
    );
    c.restore();
  });

  // The model name on a metal plate: chrome on a dark cloth, black enamel
  // with gold lettering on a light one.
  Widget _badge() {
    final onLight = _lightGrille;
    return Container(
      key: const Key('badge'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: onLight ? const Color(0xFF8C7334) : const Color(0xFF6E6E6E),
        ),
        gradient: onLight
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
        style: _font(
          13,
          onLight ? const Color(0xFFD9B860) : const Color(0xFF1A1A1A),
          spacing: 1.5,
          shadows: [
            Shadow(
              offset: const Offset(0, 1),
              color: onLight
                  ? const Color(0xCC000000)
                  : const Color(0xB3FFFFFF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _knob(int i) => KnobDrag(
    value: _value(i),
    perPx: 0.5,
    onChanged: onKnob == null ? null : (v) => onKnob!((i, v)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 20,
          child: CustomPaint(
            painter: GearKnobPainter(style: spec.knob, value: _value(i)),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            spec.knobNames[i].toUpperCase(),
            maxLines: 1,
            softWrap: false,
            style: _font(8, spec.panel.ink),
          ),
        ),
      ],
    ),
  );

  Widget _panel({required double radius, required bool toggles}) {
    final jack = PaintBox(
      11,
      11,
      (c, s) => paintJack(c, s.center(Offset.zero), 11),
    );
    final toggle = PaintBox(9, 9, (c, s) => _paintToggle(c));
    return CustomPaint(
      painter: _PanelPainter(spec.panel, radius, wear),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 6, 9, 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              spacing: 4,
              children: [
                jack,
                jack,
                for (var i = 0; i < spec.knobNames.length; i++)
                  Flexible(child: _knob(i)),
                if (toggles) ...[toggle, toggle],
                KeyedSubtree(
                  key: const Key('jewel'),
                  child: PaintBox(
                    13,
                    13,
                    (c, s) => paintJewel(c, s.center(Offset.zero), 13, lit),
                  ),
                ),
              ],
            ),
          ),
          // Transparent switch target over the jewel (centre 15.5px from the
          // panel's right edge): reaches 22px each way, as far left and as
          // tall as the panel allows, drawing and layout untouched.
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 37.5,
            child: GestureDetector(
              key: const Key('jewel-hit'),
              behavior: HitTestBehavior.opaque,
              onTap: onSwitch,
            ),
          ),
        ],
      ),
    );
  }
}

// Chrome bat toggle (power, standby): a 9px ball with the bat sticking up
// 7px above its box (drawn outside it, like the prototype's top: -7px).
void _paintToggle(Canvas c) {
  final ball = Rect.fromLTWH(0, 0, 9, 9);
  c.drawCircle(
    ball.center.translate(0, 1),
    4.5,
    Paint()
      ..color = const Color(0x80000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5),
  );
  c.drawCircle(
    ball.center,
    4.5,
    cssRadial(
      ball,
      const Offset(0.4, 0.35),
      const [Color(0xFFFFFFFF), Color(0xFFA9A9A9), Color(0xFFA9A9A9)],
      const [0, 0.7, 1],
    ),
  );
  final bat = RRect.fromRectAndRadius(
    const Rect.fromLTWH(2.5, -7, 4, 9),
    const Radius.circular(2),
  );
  _drop(c, bat, 1, 1, const Color(0x80000000));
  c.drawRRect(
    bat,
    Paint()
      ..shader = ui.Gradient.linear(
        bat.outerRect.centerLeft,
        bat.outerRect.centerRight,
        const [Color(0xFF8E8E8E), Color(0xFFFFFFFF), Color(0xFF9A9A9A)],
        const [0, 0.45, 1],
      ),
  );
}

void _drop(Canvas c, RRect rr, double dy, double blur, Color color) =>
    c.drawRRect(
      rr.shift(Offset(0, dy)),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2 + 0.01),
    );

// CSS `inset ox oy blur color`, drawn inside the current clip.
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

/// The cabinet: tolex with grain and top light (`tol()`), its thickness
/// (`boxDepth`) and the 1px near-black border.
class _BoxPainter extends CustomPainter {
  _BoxPainter(this.tolex, this.radius);
  final Tolex tolex;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    _drop(canvas, rr, 16, 28, const Color(0x5C000000));
    _drop(canvas, rr, 2, 2, const Color(0x99000000));
    canvas.save();
    canvas.clipRRect(rr);
    paintTolex(canvas, r, tolex.color, kind: tolex);
    _inset(canvas, rr, const Offset(0, 2), 1, const Color(0x29FFFFFF));
    _inset(canvas, rr, const Offset(0, -4), 6, const Color(0x8C000000));
    _inset(canvas, rr, const Offset(4, 0), 5, const Color(0x0DFFFFFF));
    _inset(canvas, rr, const Offset(-4, 0), 5, const Color(0x52000000));
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
  bool shouldRepaint(_BoxPainter old) =>
      old.tolex != tolex || old.radius != radius;
}

/// Grille cloth, cream piping when [piping], and the speakers seen through it
/// (dust cap, cone, surround) laid out like the prototype's space-around row.
class _GrillePainter extends CustomPainter {
  _GrillePainter(this.color, this.light, this.piping, this.speakers);
  final Grille color;
  final bool light;
  final bool piping;
  final int speakers;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    paintGrille(canvas, r, color.color, lightGrille: light, kind: color);
    if (piping) {
      Paint stroke(double w, Color c) => Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = c;
      canvas.drawRect(r.deflate(2), stroke(2, const Color(0xFFECE5CF)));
      canvas.drawRect(
        Rect.fromLTRB(r.left + 1, r.top + 1, r.right - 1, r.top + 2),
        Paint()..color = const Color(0x99FFFFFF),
      );
      canvas.drawRect(r.deflate(3.5), stroke(1, const Color(0x80000000)));
    }
    if (speakers == 0) return;
    // Natural sizes; shrunk to fit like flex items in the 10px-padded row.
    final natural = speakers == 1
        ? 96.0
        : speakers == 2
        ? 78.0
        : 52.0;
    final avail = size.width - 20;
    final d = math.min(natural, avail / speakers);
    final gap = (avail - d * speakers) / speakers;
    for (var i = 0; i < speakers; i++) {
      final c = Offset(10 + gap * (i + 0.5) + d * (i + 0.5), size.height / 2);
      final box = Rect.fromCircle(center: c, radius: d / 2);
      canvas.drawCircle(
        c,
        d / 2,
        cssRadial(
          box,
          const Offset(0.5, 0.5),
          const [
            Color(0x6B000000), Color(0x6B000000), //
            Color(0x29000000), Color(0x29000000), //
            Color(0x1A000000), Color(0x1A000000), //
            Color(0x47000000), Color(0x47000000), //
            Color(0x00000000),
          ],
          const [0, 0.11, 0.13, 0.30, 0.32, 0.60, 0.62, 0.67, 0.69],
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_GrillePainter old) =>
      old.color != color ||
      old.light != light ||
      old.piping != piping ||
      old.speakers != speakers;
}

/// Brushed (or painted) control panel, recessed, with a soft top gloss; the
/// two-tone bass panel gets its lower band, gold and copper their wear.
class _PanelPainter extends CustomPainter {
  _PanelPainter(this.panel, this.radius, this.wear);
  final AmpPanel panel;
  final double radius;
  final double wear;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(rr);
    final band = panel.band;
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          r.topCenter,
          r.bottomCenter,
          band == null
              ? [panel.top, panel.bottom]
              : [panel.top, panel.bottom, band, band],
          band == null ? null : const [0, 0.7, 0.7, 1],
        ),
    );
    paintHatch(canvas, r, 90, const Color(0x0FFFFFFF), 1, 2);
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          r.topCenter,
          r.bottomCenter,
          const [Color(0x33FFFFFF), Color(0x00FFFFFF)],
          const [0, 0.45],
        ),
    );
    if (panel.worn) paintWear(canvas, r, wear);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 1),
      Paint()..color = const Color(0x59FFFFFF),
    );
    _inset(canvas, rr, const Offset(0, -2), 3, const Color(0x59000000));
    canvas.drawRRect(
      rr.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x66000000),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PanelPainter old) =>
      old.panel != panel || old.radius != radius || old.wear != wear;
}
