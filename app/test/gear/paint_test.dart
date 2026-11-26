import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_specs.dart';
import 'package:sonicmaster/gear/paint/hardware.dart';
import 'package:sonicmaster/gear/paint/knob_painter.dart';
import 'package:sonicmaster/gear/paint/surfaces.dart';

class _Fn extends CustomPainter {
  _Fn(this.fn);
  final void Function(Canvas, Size) fn;
  @override
  void paint(Canvas canvas, Size size) => fn(canvas, size);
  @override
  bool shouldRepaint(_Fn old) => false;
}

Widget _box(double w, double h, void Function(Canvas, Size) fn) => SizedBox(
  width: w,
  height: h,
  child: CustomPaint(painter: _Fn(fn)),
);

void main() {
  test('value is clamped to 0..100', () {
    expect(GearKnobPainter(style: KnobStyle.boss, value: 150).value, 100);
    expect(GearKnobPainter(style: KnobStyle.boss, value: -20).value, 0);
    expect(GearKnobPainter(style: KnobStyle.boss, value: 42).value, 42);
  });

  test('shouldRepaint only when style or value change', () {
    final a = GearKnobPainter(style: KnobStyle.mxr, value: 10);
    expect(
      a.shouldRepaint(GearKnobPainter(style: KnobStyle.mxr, value: 10)),
      false,
    );
    expect(
      a.shouldRepaint(GearKnobPainter(style: KnobStyle.mxr, value: 11)),
      true,
    );
    expect(
      a.shouldRepaint(GearKnobPainter(style: KnobStyle.alu, value: 10)),
      true,
    );
  });

  // Eyeball goldens: regenerate with --update-goldens when the look changes.
  testWidgets('knob_styles golden (14 styles x 0/50/100)', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: const Key('grid'),
            child: Container(
              color: const Color(0xFF8E9196),
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  for (final s in KnobStyle.values)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final v in const [0.0, 50.0, 100.0])
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: SizedBox.square(
                              dimension: 44,
                              child: CustomPaint(
                                painter: GearKnobPainter(style: s, value: v),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const Key('grid')),
      matchesGoldenFile('goldens/knob_styles.png'),
    );
  });

  testWidgets('hardware_surfaces golden', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: const Key('hw'),
            child: Container(
              color: const Color(0xFF2B2D31),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _box(
                        40,
                        40,
                        (c, s) => paintLed(c, s.center(Offset.zero), 14, true),
                      ),
                      _box(
                        40,
                        40,
                        (c, s) => paintLed(c, s.center(Offset.zero), 14, false),
                      ),
                      _box(
                        40,
                        40,
                        (c, s) => paintJack(c, s.center(Offset.zero), 22),
                      ),
                      _box(
                        40,
                        40,
                        (c, s) =>
                            paintJewel(c, s.center(Offset.zero), 26, true),
                      ),
                      _box(
                        40,
                        40,
                        (c, s) => paintScrew(c, s.center(Offset.zero), 14),
                      ),
                      _box(
                        70,
                        70,
                        (c, s) => paintFootswitch(c, s.center(Offset.zero), 40),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final w in const [0.0, 0.5, 1.0])
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: _box(112, 190, (c, s) {
                            final r = Offset.zero & s;
                            paintEnamel(c, r, const Color(0xFF3E8E4A));
                            c.save();
                            c.clipRRect(
                              RRect.fromRectAndRadius(
                                r,
                                const Radius.circular(6),
                              ),
                            );
                            paintWear(c, r, w);
                            c.restore();
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _box(
                        160,
                        100,
                        (c, s) => paintTolex(
                          c,
                          Offset.zero & s,
                          const Color(0xFF1C1C1C),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _box(
                        160,
                        100,
                        (c, s) => paintTolex(
                          c,
                          Offset.zero & s,
                          const Color(0xFFD2B47A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _box(
                        160,
                        100,
                        (c, s) => paintGrille(
                          c,
                          Offset.zero & s,
                          const Color(0xFF5C5C5C),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _box(
                        160,
                        100,
                        (c, s) => paintGrille(
                          c,
                          Offset.zero & s,
                          const Color(0xFFE3D9C2),
                          lightGrille: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const Key('hw')),
      matchesGoldenFile('goldens/hardware_surfaces.png'),
    );
  });
}
