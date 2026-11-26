// The pedal pieces, ported from the prototype's isPedal / isWah / isRack /
// isTape branches (docs/design/prototipo/Peca.dc.html): the same natural size,
// knob grid, label, LED and footswitch per family. Sizes are in logical px.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'gear_specs.dart';
import 'paint/hardware.dart';
import 'paint/knob_painter.dart';
import 'paint/surfaces.dart';

// The prototype's `vals`: knob positions when no value is given.
const _minHit = 44.0;
const _defaultVals = <double>[62, 45, 70, 38, 55, 66, 48, 58];
// Graphic EQ slider positions when no value is given.
const _sliderVals = <double>[60, 40, 55, 70, 45, 50];

TextStyle _font(
  double size,
  Color color, {
  double spacing = 1,
  double height = 1,
  bool italic = false,
  String family = 'Barlow Condensed',
}) => TextStyle(
  fontFamily: family,
  fontFamilyFallback: const ['Oswald'],
  fontSize: size,
  fontWeight: FontWeight.w700,
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  letterSpacing: spacing,
  height: height,
  color: color,
);

/// A pedal (or wah, rack unit, tape echo) for [model], drawn from [spec].
/// [values] are 0..100 per knob (null = the prototype's defaults); dragging a
/// knob up raises it and reports `(index, value)` to [onKnob].
class PedalPiece extends StatelessWidget {
  const PedalPiece({
    super.key,
    required this.spec,
    required this.model,
    this.values,
    this.onKnob,
    this.onSwitch,
    this.lit = true,
    this.wear = 0.6,
  });

  final PedalSpec spec;
  final String model;
  final List<double?>? values;
  final ValueChanged<(int, double)>? onKnob;
  final VoidCallback? onSwitch;
  final bool lit;
  final double wear;

  double _value(int i, [List<double> defaults = _defaultVals]) {
    final v = values != null && i < values!.length ? values![i] : null;
    return v ?? defaults[i % defaults.length];
  }

  ValueChanged<double>? _report(int i) =>
      onKnob == null ? null : (v) => onKnob!((i, v));

  @override
  Widget build(BuildContext context) => switch (spec.family) {
    PedalFamily.wah => _wah(),
    PedalFamily.rack || PedalFamily.studio => _rack(),
    PedalFamily.tape => _tape(),
    _ => _stomp(),
  };

  Widget _body(double w, double h, Widget child) => SizedBox(
    width: w,
    height: h,
    child: CustomPaint(
      painter: _BodyPainter(spec.family, spec.body, wear),
      child: child,
    ),
  );

  TextStyle _labelStyle(double size) =>
      _font(size, spec.label, spacing: 0.5, height: 1.2);

  Widget _knob(int i, double size, double lbl) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.square(
        dimension: size,
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
          style: _labelStyle(lbl),
        ),
      ),
    ],
  );

  /// CSS `grid-template-columns: repeat(cols, minmax(0, 1fr))`. With [avail]
  /// the grid sits centred at its content width (widest knob or label, as in
  /// a centred flex column); without it the columns share the full width.
  Widget _grid(
    double kSize,
    double lbl,
    int cols,
    double hGap,
    double vGap, {
    double? avail,
    double Function(int i)? sizeOf,
  }) {
    final n = spec.knobNames.length;
    double? cellW;
    if (avail != null) {
      var w = kSize;
      for (final name in spec.knobNames) {
        final tp = TextPainter(
          text: TextSpan(text: name.toUpperCase(), style: _labelStyle(lbl)),
          textDirection: TextDirection.ltr,
        )..layout();
        w = math.max(w, tp.width);
        tp.dispose();
      }
      cellW = math.min(w, (avail - hGap * (cols - 1)) / cols);
    }
    final rows = <Widget>[];
    for (var r = 0; r < n; r += cols) {
      final row = <Widget>[];
      for (var c = 0; c < cols; c++) {
        if (c > 0 && cellW == null) row.add(SizedBox(width: hGap));
        final i = r + c;
        final cell = Align(
          alignment: Alignment.topCenter,
          child: i < n ? _knob(i, sizeOf?.call(i) ?? kSize, lbl) : null,
        );
        // The whole grid cell drags, not just the cap. With a fixed cell width
        // the cell also absorbs half of each neighbouring gap (same layout,
        // wider target).
        final left = cellW != null && c > 0 ? hGap / 2 : 0.0;
        final right = cellW != null && c < cols - 1 ? hGap / 2 : 0.0;
        final hit = i < n
            ? KnobDrag(
                value: _value(i),
                perPx: 0.5,
                onChanged: _report(i),
                child: Padding(
                  padding: EdgeInsets.only(left: left, right: right),
                  child: cell,
                ),
              )
            : Padding(
                padding: EdgeInsets.only(left: left, right: right),
                child: cell,
              );
        row.add(
          cellW == null
              ? Expanded(child: hit)
              : SizedBox(width: cellW + left + right, child: hit),
        );
      }
      if (r > 0) rows.add(SizedBox(height: vGap));
      rows.add(
        Row(
          mainAxisSize: cellW == null ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: row,
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _title(
    double size, {
    double spacing = 1,
    bool italic = false,
    bool upper = true,
    TextAlign align = TextAlign.center,
  }) => Padding(
    // Side margin: a long name wraps before it touches the body's edges
    // (the rack's title box is sized to its text and needs none).
    padding: EdgeInsets.symmetric(
      horizontal: switch (spec.family) {
        PedalFamily.rack || PedalFamily.studio || PedalFamily.tape => 0,
        _ => 6,
      },
    ),
    child: Text(
      upper ? model.toUpperCase() : model,
      textAlign: align,
      maxLines: 2,
      style: _font(size, spec.label, spacing: spacing, italic: italic),
    ),
  );

  Widget _led() =>
      PaintBox(7, 7, (c, s) => paintLed(c, s.center(Offset.zero), 7, lit));

  // The drawing keeps its place; the box is padded to the 44pt touch target
  // and the neighbours (_footswitchGrow) give back the extra room.
  double _hitBox(double s) => math.max(_minHit, s + 12);
  double _footswitchGrow(double s) => _hitBox(s) - (s + 12);

  Widget _footswitch(int i, double s) => GestureDetector(
    key: Key(i == 0 ? 'footswitch' : 'footswitch-$i'),
    behavior: HitTestBehavior.opaque,
    onTap: onSwitch,
    child: PaintBox(
      _hitBox(s),
      _hitBox(s),
      (c, z) => paintFootswitch(c, z.center(Offset.zero), s),
    ),
  );

  // Recessed plate under the knobs (compact and graphic families).
  Widget _plate(double w, double? h) {
    final plate = PaintBox(w, h ?? 0, (c, s) {
      final rr = RRect.fromRectAndRadius(
        Offset.zero & s,
        const Radius.circular(4),
      );
      c.drawRRect(
        rr,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            s.bottomLeft(Offset.zero),
            [shadeColor(spec.body, -0.06), shadeColor(spec.body, -0.16)],
          ),
      );
      c.save();
      c.clipRRect(rr);
      c.drawRect(
        Rect.fromLTWH(0, 0, s.width, 2),
        Paint()..color = const Color(0x40000000),
      );
      c.drawRect(
        Rect.fromLTWH(0, s.height - 1, s.width, 1),
        Paint()..color = const Color(0x14FFFFFF),
      );
      c.restore();
    });
    return h == null ? SizedBox(width: w, child: plate) : plate;
  }

  Widget _stomp() {
    final f = spec.family;
    final nk = spec.knobNames.length;
    double w = 112, h = 190, k = 22, lbl = 7.5, hGap = 6, vGap = 6;
    var cols = math.min(nk, 3);
    var pad = const EdgeInsets.fromLTRB(10, 14, 10, 0);
    var switches = <double>[22];
    double swGap = 14, swBottom = 12;
    Widget title = Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: _title(13),
    );
    final below = <Widget>[];
    final tail = <Widget>[];
    Widget? screen;
    Widget? sliders;
    double Function(int)? sizeOf;

    switch (f) {
      case PedalFamily.compact:
        w = 110;
        k = 18;
        cols = math.min(nk, 4);
        pad = const EdgeInsets.fromLTRB(8, 10, 8, 0);
        hGap = vGap = 4;
        lbl = 6.5;
        switches = [];
        title = Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _title(11),
        );
        below.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _plate(92, null),
            ),
          ),
        );
      case PedalFamily.ts:
        k = 24;
        cols = 3;
        sizeOf = (i) => i == 1 ? 16 : 24;
        switches = [];
        tail.addAll([
          PaintBox(86, 62, (c, s) {
            final rr = RRect.fromRectAndRadius(
              Offset.zero & s,
              const Radius.circular(6),
            );
            _shadow(c, rr, 2, 3, const Color(0x80000000));
            c.save();
            c.clipRRect(rr);
            c.drawRect(
              Offset.zero & s,
              Paint()..color = const Color(0xFF2C2C2C),
            );
            paintHatch(c, Offset.zero & s, 0, const Color(0xFF1E1E1E), 3, 5);
            c.restore();
          }),
          const SizedBox(height: 10),
        ]);
      case PedalFamily.mxr:
        w = 92;
        h = 160;
        k = nk == 1 ? 34 : 24;
        cols = math.min(nk, 2);
        switches = [20];
        title = Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _title(14, italic: true, upper: false, spacing: 0),
        );
      case PedalFamily.wide:
        w = 180;
        h = 160;
        k = 30;
        pad = const EdgeInsets.fromLTRB(14, 16, 14, 0);
        title = Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _title(16),
        );
      case PedalFamily.round:
        w = h = 170;
        k = 26;
        cols = 2;
        pad = const EdgeInsets.fromLTRB(40, 26, 40, 0);
        swBottom = 28;
        title = Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _title(16, italic: true),
        );
      case PedalFamily.wedge:
        w = 120;
        k = 24;
        cols = 2;
      case PedalFamily.rat:
        cols = 3;
        title = Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _title(18, spacing: 3),
        );
      case PedalFamily.graphic:
        w = 110;
        switches = [];
        cols = 0;
        sliders = Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < math.min(nk, 6); i++) ...[
                KnobDrag(
                  value: _value(i, _sliderVals),
                  perPx: 100 / 66,
                  onChanged: _report(i),
                  child: _slider(_value(i, _sliderVals)),
                ),
              ],
            ],
          ),
        );
        title = Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _title(11),
        );
        below.addAll([
          const SizedBox(height: 6),
          _plate(92, 54),
          const SizedBox(height: 8),
        ]);
      case PedalFamily.modern:
        w = 200;
        h = 176;
        k = 20;
        cols = 4;
        pad = const EdgeInsets.fromLTRB(12, 6, 12, 0);
        hGap = 6;
        vGap = 4;
        screen = Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0C0E),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            model.toUpperCase(),
            maxLines: 1,
            style: _font(
              11,
              const Color(0xFF9FE3FF),
              spacing: 0,
              height: 1.2,
              family: 'Share Tech Mono',
            ).copyWith(fontWeight: FontWeight.w400),
          ),
        );
        switches = [18, 18];
        swGap = 70;
        swBottom = 10;
        title = Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _title(12),
        );
      default:
        if (nk >= 4) {
          w = 124;
          h = 196;
          k = 20;
          cols = nk == 4 ? 2 : 3;
        }
    }

    final grid = Padding(
      padding: pad,
      child: cols == 0
          ? const SizedBox(width: double.infinity)
          : _grid(
              k,
              lbl,
              cols,
              hGap,
              vGap,
              avail: w - pad.horizontal,
              sizeOf: sizeOf,
            ),
    );
    final top = <Widget>[
      const SizedBox(height: 8),
      _led(),
      ?screen,
      // Too many knobs for the case: the grid shrinks instead of overflowing
      // (the compact family's plate already takes the free space).
      if (f == PedalFamily.compact)
        grid
      else
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(width: w, child: grid),
          ),
        ),
      ?sliders,
      title,
      ...below,
    ];
    if (switches.isNotEmpty) {
      tail.addAll([
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < switches.length; i++) ...[
              if (i > 0) SizedBox(width: swGap - _footswitchGrow(switches[i])),
              _footswitch(i, switches[i]),
            ],
          ],
        ),
        SizedBox(height: swBottom - _footswitchGrow(switches.first) / 2),
      ]);
    }

    return _body(
      w,
      h,
      tail.isEmpty
          ? Column(children: top)
          // CSS `margin-top: auto`: the tail sits at the bottom.
          : Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(mainAxisSize: MainAxisSize.min, children: top),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: tail),
              ],
            ),
    );
  }

  Widget _slider(double p) => PaintBox(11, 66, (c, s) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 0, 3, s.height),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0x8C000000),
    );
    final top = s.height - (p.clamp(0, 100) / 100 * s.height - 3) - 7;
    final thumb = Rect.fromLTWH(0, top, 11, 7);
    c.drawRRect(
      RRect.fromRectAndRadius(thumb, const Radius.circular(1)),
      Paint()
        ..shader = ui.Gradient.linear(
          thumb.topCenter,
          thumb.bottomCenter,
          const [Color(0xFFF2F2F2), Color(0xFF9A9A9A)],
        ),
    );
  });

  Widget _rack() {
    final rack = spec.family == PedalFamily.rack;
    final nk = spec.knobNames.length;
    Widget ear() => PaintBox(14, double.infinity, (c, s) {
      final r = Offset.zero & s;
      c.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.linear(r.centerLeft, r.centerRight, const [
            Color(0x2E000000),
            Color(0x0D000000),
          ]),
      );
      final hole = Paint()..color = const Color(0xFF111111);
      c.drawCircle(Offset(s.width / 2, s.height * 0.22), 2.5, hole);
      c.drawCircle(Offset(s.width / 2, s.height * 0.78), 2.5, hole);
    });
    const gap = SizedBox(width: 8);
    return _body(
      rack ? 250 : 240,
      rack ? 74 : 110,
      Row(
        children: [
          ear(),
          gap,
          SizedBox(width: 46, child: _title(12, align: TextAlign.left)),
          gap,
          if (rack) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0505),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                '500ms',
                style:
                    _font(
                      15,
                      const Color(0xFFFF4A3A),
                      spacing: 0,
                      family: 'Share Tech Mono',
                    ).copyWith(
                      fontWeight: FontWeight.w400,
                      shadows: const [
                        Shadow(color: Color(0x99FF4A3A), blurRadius: 4),
                      ],
                    ),
              ),
            ),
            gap,
          ],
          Expanded(
            child: _grid(rack ? 18 : 20, 7, rack ? nk : (nk / 2).ceil(), 6, 4),
          ),
          gap,
          _led(),
          gap,
          ear(),
        ],
      ),
    );
  }

  Widget _tape() => _body(
    230,
    130,
    Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          PaintBox(120, 96, (c, s) {
            final rr = RRect.fromRectAndRadius(
              Offset.zero & s,
              const Radius.circular(6),
            );
            c.drawRRect(
              rr,
              Paint()
                ..shader = ui.Gradient.linear(
                  Offset.zero,
                  s.bottomLeft(Offset.zero),
                  const [Color(0xD9141414), Color(0xD9282828)],
                ),
            );
            c.save();
            c.clipRRect(rr);
            _insetTop(c, rr, 2, 4, const Color(0xB3000000));
            c.restore();
            final y = s.height / 2;
            c.drawRect(
              Rect.fromLTRB(48, y - 1, s.width - 48, y + 1),
              Paint()..color = const Color(0xFF6B4E2E),
            );
            for (final x in [28.0, s.width - 28]) {
              final rb = Rect.fromCircle(center: Offset(x, y), radius: 20);
              c.drawCircle(
                rb.center,
                20,
                cssRadial(
                  rb,
                  const Offset(0.5, 0.5),
                  const [
                    Color(0xFFCFCFCF), Color(0xFFCFCFCF), //
                    Color(0xFF3A3A3A), Color(0xFF3A3A3A), //
                    Color(0xFF6B4E2E), Color(0xFF6B4E2E), //
                    Color(0xFF2A2A2A), Color(0xFF2A2A2A),
                  ],
                  // CSS circle stops are of the farthest corner (r * sqrt2).
                  [
                    for (final p in const [0, .14, .16, .30, .32, .92, .94, 1])
                      p / math.sqrt2,
                  ],
                ),
              );
            }
          }),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _title(13),
                const SizedBox(height: 6),
                _grid(18, 7, 3, 4, 2, avail: 80),
                const SizedBox(height: 6),
                _led(),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _wah() => _body(
    100,
    210,
    Column(
      children: [
        const SizedBox(height: 10),
        PaintBox(78, 128, (c, s) {
          final rr = RRect.fromRectAndCorners(
            Offset.zero & s,
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(10),
            bottomLeft: const Radius.circular(4),
            bottomRight: const Radius.circular(4),
          );
          _shadow(c, rr, 2, 3, const Color(0x99000000));
          c.save();
          c.clipRRect(rr);
          c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF2E2E2E));
          paintHatch(c, Offset.zero & s, 0, const Color(0xFF1A1A1A), 4, 6);
          c.restore();
        }),
        Padding(padding: const EdgeInsets.only(top: 8), child: _title(12)),
        const Spacer(),
        PaintBox(78, 26, (c, s) {
          final r = Offset.zero & s;
          c.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(4)),
            Paint()
              ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, const [
                Color(0xFFD9D9D9),
                Color(0xFF8E8E8E),
              ]),
          );
        }),
        const SizedBox(height: 8),
      ],
    ),
  );
}

/// Vertical drag on a knob or slider: up raises the value, [perPx] per pixel.
class KnobDrag extends StatefulWidget {
  const KnobDrag({
    super.key,
    required this.value,
    required this.perPx,
    required this.onChanged,
    required this.child,
  });

  final double value;
  final double perPx;
  final ValueChanged<double>? onChanged;
  final Widget child;

  @override
  State<KnobDrag> createState() => _KnobDragState();
}

class _KnobDragState extends State<KnobDrag> {
  double _v = 0;

  @override
  Widget build(BuildContext context) {
    final on = widget.onChanged;
    if (on == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _v = widget.value,
      onVerticalDragUpdate: (d) {
        _v = (_v - d.delta.dy * widget.perPx).clamp(0.0, 100.0);
        on(_v);
      },
      child: widget.child,
    );
  }
}

/// A fixed-size box drawn by [fn].
class PaintBox extends StatelessWidget {
  const PaintBox(this.w, this.h, this.fn, {super.key});
  final double w;
  final double h;
  final void Function(Canvas, Size) fn;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: w,
    height: h,
    child: CustomPaint(painter: _Fn(fn)),
  );
}

class _Fn extends CustomPainter {
  _Fn(this.fn);
  final void Function(Canvas, Size) fn;
  @override
  void paint(Canvas canvas, Size size) => fn(canvas, size);
  // The closures capture the piece's values; a rebuilt piece repaints.
  @override
  bool shouldRepaint(_Fn old) => true;
}

void _shadow(Canvas c, RRect rr, double dy, double blur, Color color) =>
    c.drawRRect(
      rr.shift(Offset(0, dy)),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2 + 0.01),
    );

// CSS `inset 0 dy blur color`, drawn inside the current clip.
void _insetTop(Canvas c, RRect rr, double dy, double blur, Color color) =>
    c.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rr.outerRect.inflate(blur * 2 + 10))
        ..addRRect(rr.shift(Offset(0, dy))),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2 + 0.01),
    );

/// The pedal's case: enamel (most families), speckled two-tone (wedge),
/// black plastic (wah) or grey tolex (tape), with wear on top.
class _BodyPainter extends CustomPainter {
  _BodyPainter(this.family, this.color, this.wear);
  final PedalFamily family;
  final Color color;
  final double wear;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final RRect rr;
    switch (family) {
      case PedalFamily.wah:
        rr = RRect.fromRectAndCorners(
          r,
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: const Radius.circular(8),
          bottomRight: const Radius.circular(8),
        );
        _drops(canvas, rr);
        canvas.drawRRect(
          rr,
          Paint()
            ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, const [
              Color(0xFF2A2A2A),
              Color(0xFF151515),
            ]),
        );
      case PedalFamily.tape:
        rr = RRect.fromRectAndRadius(r, const Radius.circular(8));
        _drops(canvas, rr);
        canvas.save();
        canvas.clipRRect(rr);
        paintTolex(canvas, r, const Color(0xFF3A3D42));
        canvas.restore();
        canvas.drawRRect(
          rr.deflate(0.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFF050505),
        );
        return; // The prototype puts no wear on the tape unit.
      case PedalFamily.wedge:
        rr = RRect.fromRectAndRadius(r, const Radius.circular(9));
        _drops(canvas, rr);
        canvas.save();
        canvas.clipRRect(rr);
        canvas.drawRect(
          r,
          Paint()
            ..shader = ui.Gradient.linear(
              r.topCenter,
              r.bottomCenter,
              [
                shadeColor(color, -0.18),
                shadeColor(color, -0.18),
                shadeColor(color, 0.06),
                shadeColor(color, 0.06),
              ],
              const [0, 0.30, 0.31, 1],
            ),
        );
        // Hammertone speckle: a light dot every 3 px.
        canvas.drawPoints(
          ui.PointMode.points,
          [
            for (double y = 1.5; y < size.height; y += 3)
              for (double x = 1.5; x < size.width; x += 3) Offset(x, y),
          ],
          Paint()
            ..color = const Color(0x1FFFFFFF)
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, 1),
          Paint()..color = const Color(0x24FFFFFF),
        );
        canvas.restore();
      default:
        final radius = switch (family) {
          PedalFamily.round => size.shortestSide / 2,
          // ponytail: the prototype's ts is 16/16/10/10; paintEnamel takes one radius.
          PedalFamily.ts => 16.0,
          PedalFamily.rack || PedalFamily.studio => 3.0,
          _ => 9.0,
        };
        rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
        paintEnamel(canvas, r, color, radius: radius);
    }
    canvas.save();
    canvas.clipRRect(rr);
    paintWear(canvas, r, wear);
    canvas.restore();
  }

  // `0 1px 3px rgba(0,0,0,.45), 0 8px 18px rgba(0,0,0,.25)`.
  void _drops(Canvas canvas, RRect rr) {
    _shadow(canvas, rr, 8, 18, const Color(0x40000000));
    _shadow(canvas, rr, 1, 3, const Color(0x73000000));
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.family != family || old.color != color || old.wear != wear;
}
