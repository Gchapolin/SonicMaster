import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../model/cfw_eq_models.dart';
import '../model/eq_curve.dart';
import '../theme/app_colors.dart';

/// The Global EQ's response curve: 20 Hz to 20 kHz on a log axis, ±15 dB,
/// with grid lines at 100 Hz, 1 kHz, 10 kHz and 0 dB. An approximation (see
/// eqCurveDb); dimmed while the EQ is off.
class EqCurve extends StatelessWidget {
  const EqCurve({
    super.key,
    required this.model,
    required this.slots,
    this.isOn = true,
    this.height = 96,
  });

  final CfwEqModel model;
  final List<int> slots;
  final bool isOn;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _EqCurvePainter(model: model, slots: slots, isOn: isOn),
      ),
    );
  }
}

class _EqCurvePainter extends CustomPainter {
  _EqCurvePainter({
    required this.model,
    required this.slots,
    required this.isOn,
  });

  final CfwEqModel model;
  final List<int> slots;
  final bool isOn;

  static const _fMin = 20.0;
  static const _fMax = 20000.0;
  static const _dbRange = 15.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plate = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );

    canvas.drawRRect(plate, Paint()..color = Palette.surfaceContainerLow);
    canvas.save();
    canvas.clipRRect(plate);

    double x(double f) =>
        size.width * math.log(f / _fMin) / math.log(_fMax / _fMin);
    double y(double db) =>
        size.height / 2 -
        db.clamp(-_dbRange, _dbRange) / _dbRange * (size.height / 2 - 6);

    final grid = Paint()
      ..color = Palette.outlineVariant
      ..strokeWidth = 1;

    for (final f in const [100.0, 1000.0, 10000.0]) {
      canvas.drawLine(Offset(x(f), 0), Offset(x(f), size.height), grid);
    }
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), grid);

    final curve = Path();
    const steps = 96;

    for (var i = 0; i <= steps; i++) {
      final f = _fMin * math.pow(_fMax / _fMin, i / steps);
      final point = Offset(x(f), y(eqCurveDb(model, slots, f)));

      i == 0
          ? curve.moveTo(point.dx, point.dy)
          : curve.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(
      curve,
      Paint()
        ..color = isOn ? Palette.primary : Palette.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EqCurvePainter old) =>
      old.model != model || old.isOn != isOn || !_same(old.slots, slots);

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }
}
