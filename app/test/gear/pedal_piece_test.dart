import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_specs.dart';
import 'package:sonicmaster/gear/paint/knob_painter.dart';
import 'package:sonicmaster/gear/pedal_piece.dart';

// One model per family, in PedalFamily order.
const _models = [
  'B-Chorus', // std
  'A-Chorus', // compact
  'Scream', // ts
  'Phaser M', // mxr
  'Jet', // wide
  'Red Fuzz', // round
  'Grey Fuzz', // wedge
  'Dark Mouse', // rat
  'GT EQ 1', // graphic
  'Studio EQ', // studio
  'Analog', // rack
  'Echo', // tape
  'C-Wah', // wah
  'Studio Delay', // modern
];

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

void main() {
  test('the sample models cover every family', () {
    expect(
      _models.map((m) => pedalSpecs[m]!.family).toList(),
      PedalFamily.values,
    );
  });

  testWidgets('natural size per family matches the prototype', (tester) async {
    const sizes = {
      'B-Chorus': Size(112, 190),
      'Bass Drive': Size(124, 196), // std with 4+ knobs
      'A-Chorus': Size(110, 190),
      'Scream': Size(112, 190),
      'Phaser M': Size(92, 160),
      'Jet': Size(180, 160),
      'Red Fuzz': Size(170, 170),
      'Grey Fuzz': Size(120, 190),
      'Dark Mouse': Size(112, 190),
      'GT EQ 1': Size(110, 190),
      'Studio EQ': Size(240, 110),
      'Analog': Size(250, 74),
      'Echo': Size(230, 130),
      'C-Wah': Size(100, 210),
      'Studio Delay': Size(200, 176),
    };
    for (final e in sizes.entries) {
      await tester.pumpWidget(
        _host(PedalPiece(spec: pedalSpecs[e.key]!, model: e.key)),
      );
      expect(tester.getSize(find.byType(PedalPiece)), e.value, reason: e.key);
    }
  });

  testWidgets('dragging a knob reports its index and new value', (
    tester,
  ) async {
    final got = <(int, double)>[];
    await tester.pumpWidget(
      _host(
        PedalPiece(
          spec: pedalSpecs['Scream']!,
          model: 'Scream',
          values: const [10, 40, 90],
          onKnob: got.add,
        ),
      ),
    );
    await tester.drag(find.text('TONE'), const Offset(0, -60));
    expect(got, isNotEmpty);
    expect(got.every((e) => e.$1 == 1), true);
    expect(got.last.$2, greaterThan(40));
    expect(got.last.$2, lessThanOrEqualTo(100));
  });

  testWidgets('tapping the footswitch calls onSwitch', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        PedalPiece(
          spec: pedalSpecs['B-Chorus']!,
          model: 'B-Chorus',
          onSwitch: () => taps++,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('footswitch')));
    expect(taps, 1);
  });

  testWidgets(
    'footswitch hit area is at least 44pt and the natural size holds',
    (tester) async {
      for (final m in _models) {
        var taps = 0;
        await tester.pumpWidget(
          _host(
            PedalPiece(spec: pedalSpecs[m]!, model: m, onSwitch: () => taps++),
          ),
        );
        final f = find.byKey(const Key('footswitch'));
        if (f.evaluate().isEmpty) continue;
        final sz = tester.getSize(f);
        expect(sz.width, greaterThanOrEqualTo(44), reason: m);
        expect(sz.height, greaterThanOrEqualTo(44), reason: m);
        // 20px off centre: outside the old 30-34px box, inside the 44px one.
        await tester.tapAt(tester.getCenter(f) + const Offset(20, 0));
        expect(taps, 1, reason: m);
      }
    },
  );

  testWidgets('a knob drags from just outside the cap, inside its cell', (
    tester,
  ) async {
    final got = <(int, double)>[];
    await tester.pumpWidget(
      _host(
        PedalPiece(
          spec: pedalSpecs['Studio Delay']!,
          model: 'Studio Delay',
          onKnob: got.add,
        ),
      ),
    );
    final cap = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is GearKnobPainter,
    );
    final r = tester.getRect(cap.first);
    await tester.dragFrom(
      Offset(r.right + 6, r.center.dy),
      const Offset(0, -40),
    );
    expect(got, isNotEmpty);
  });

  testWidgets('graphic EQ sliders: 11px pitch, whole column drags', (
    tester,
  ) async {
    final got = <(int, double)>[];
    await tester.pumpWidget(
      _host(
        PedalPiece(
          spec: pedalSpecs['GT EQ 1']!,
          model: 'GT EQ 1',
          onKnob: got.add,
        ),
      ),
    );
    final sl = find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == 11 && w.height == 66,
    );
    expect(sl, findsNWidgets(6));
    final a = tester.getCenter(sl.at(0));
    expect(tester.getCenter(sl.at(1)).dx - a.dx, 11);
    // 5px right of the 3px track, still inside its 11px column.
    await tester.dragFrom(a + const Offset(5, 0), const Offset(0, -30));
    expect(got.every((e) => e.$1 == 0), true);
    expect(got, isNotEmpty);
  });

  testWidgets('no pedal title touches the body edges', (tester) async {
    for (final e in pedalSpecs.entries) {
      await tester.pumpWidget(_host(PedalPiece(spec: e.value, model: e.key)));
      final body = tester.getRect(find.byType(PedalPiece));
      final title = find.text(
        e.value.family == PedalFamily.mxr ? e.key : e.key.toUpperCase(),
      );
      expect(title, findsWidgets, reason: e.key);
      final r = tester.getRect(title.first);

      // Wrap rather than touch: at least 4px of body on each side.
      expect(r.left, greaterThanOrEqualTo(body.left + 4), reason: e.key);
      expect(r.right, lessThanOrEqualTo(body.right - 4), reason: e.key);
    }
  });

  // The prototype's rat title (18px, 3px tracking, no side padding) fits on
  // one line across the 112px body; the app keeps it on one line, scaled to
  // stay 4px off the edges, instead of wrapping it.
  testWidgets('Dark Mouse prints its title on one line', (tester) async {
    await tester.pumpWidget(
      _host(PedalPiece(spec: pedalSpecs['Dark Mouse']!, model: 'Dark Mouse')),
    );
    final r = tester.getRect(find.text('DARK MOUSE'));
    expect(r.height, lessThan(24));
    expect(r.width, greaterThan(96));
  });

  // CSS never breaks inside a word: the rack title keeps PARAMETRIC whole
  // (scaled into its 46px column).
  testWidgets('a rack title never breaks inside a word', (tester) async {
    await tester.pumpWidget(
      _host(
        PedalPiece(spec: pedalSpecs['Parametric 3']!, model: 'Parametric 3'),
      ),
    );
    final t = find.text('PARAMETRIC 3');
    final p = TextPainter(
      text: TextSpan(text: 'PARAMETRIC', style: tester.widget<Text>(t).style),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = tester.renderObject<RenderBox>(t).size;
    expect(box.width, greaterThanOrEqualTo(p.width - 0.01));
    expect(tester.getRect(t).width, lessThanOrEqualTo(46.01));
    p.dispose();
  });

  // The prototype's mxr Phaser M overflows its 160px case (the CSS grid
  // never shrinks): the knobs stay close to 24px, the switch drops into its
  // bottom margin but stays on the case.
  testWidgets('Phaser M keeps its knobs and its footswitch on the case', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(PedalPiece(spec: pedalSpecs['Phaser M']!, model: 'Phaser M')),
    );
    final caps = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is GearKnobPainter,
    );
    expect(caps, findsNWidgets(3));
    expect(tester.getRect(caps.first).width, greaterThan(23));
    final body = tester.getRect(find.byType(PedalPiece));
    final sw = tester.getCenter(find.byKey(const Key('footswitch')));
    // Washer radius (20 + 12) / 2 = 16, at least 4px inside the case.
    expect(sw.dy + 16, lessThanOrEqualTo(body.bottom - 4 + 0.01));
  });

  testWidgets('the model name is printed on the pedal', (tester) async {
    await tester.pumpWidget(
      _host(PedalPiece(spec: pedalSpecs['Phaser M']!, model: 'Phaser M')),
    );
    // mxr keeps the case (no uppercase transform).
    expect(find.text('Phaser M'), findsOneWidget);
  });

  testWidgets('eight knobs fit without overflow', (tester) async {
    final base = pedalSpecs['Studio Delay']!;
    // The app's Studio Delay has 8 parameters (Trail is the 8th).
    final names = [...base.knobNames, 'Trail'];
    final spec = PedalSpec(
      base.family,
      base.body,
      base.label,
      base.knob,
      names,
    );
    await tester.pumpWidget(
      _host(
        PedalPiece(
          spec: spec,
          model: 'Studio Delay',
          values: const [10, 20, 30, 40, 50, 60, 70, 80],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final n in names) {
      expect(find.text(n.toUpperCase()), findsOneWidget, reason: n);
    }
    // Studio EQ: 8 knobs on the studio rack.
    await tester.pumpWidget(
      _host(PedalPiece(spec: pedalSpecs['Studio EQ']!, model: 'Studio EQ')),
    );
    expect(tester.takeException(), isNull);
    for (final n in pedalSpecs['Studio EQ']!.knobNames) {
      expect(find.text(n.toUpperCase()), findsOneWidget, reason: n);
    }
  });

  testWidgets('every pedal model lays out without overflow', (tester) async {
    for (final e in pedalSpecs.entries) {
      for (final lit in const [true, false]) {
        await tester.pumpWidget(
          _host(PedalPiece(spec: e.value, model: e.key, lit: lit)),
        );
        expect(tester.takeException(), isNull, reason: e.key);
      }
    }
  });

  testWidgets('pedal_families golden (14 families, lit and unlit)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        RepaintBoundary(
          key: const Key('families'),
          child: Container(
            width: 1500,
            color: const Color(0xFF4A3530),
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 22,
              runSpacing: 28,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final lit in const [true, false])
                  for (final m in _models)
                    PedalPiece(spec: pedalSpecs[m]!, model: m, lit: lit),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const Key('families')),
      matchesGoldenFile('goldens/pedal_families.png'),
    );
  });
}
