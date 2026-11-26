import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/amp_piece.dart';
import 'package:sonicmaster/gear/cab_piece.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
import 'package:sonicmaster/gear/paint/knob_painter.dart';
import 'package:sonicmaster/gear/pedal_piece.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

const _sizes = [Size(66, 114), Size(118, 76), Size(88, 92), Size(660, 440)];
const _models = [
  ('Studio Delay', GearKind.pedal),
  ('Dark Twin', GearKind.amp),
  ('User IR 1', GearKind.cab),
];

void main() {
  testWidgets('the piece never leaves its box', (tester) async {
    for (final (m, k) in _models) {
      for (final s in _sizes) {
        await tester.pumpWidget(_host(GearPiece(model: m, kind: k, fit: s)));
        final got = tester.getSize(find.byType(GearPiece));
        expect(got.width, lessThanOrEqualTo(s.width + 0.01), reason: '$m $s');
        expect(got.height, lessThanOrEqualTo(s.height + 0.01), reason: '$m $s');
        // The painted piece, not just the box, stays inside [fit].
        final inner = tester
            .getRect(
              find
                  .byWidgetPredicate(
                    (w) =>
                        w is PedalPiece ||
                        w is AmpPiece ||
                        w is CabPiece ||
                        w is GenericPiece,
                  )
                  .first,
            )
            .size;
        expect(inner.width, lessThanOrEqualTo(s.width + 0.01), reason: '$m $s');
        expect(
          inner.height,
          lessThanOrEqualTo(s.height + 0.01),
          reason: '$m $s',
        );
      }
    }
  });

  testWidgets('known models draw their own piece', (tester) async {
    const fit = Size(660, 440);
    await tester.pumpWidget(
      _host(
        const GearPiece(model: 'Studio Delay', kind: GearKind.pedal, fit: fit),
      ),
    );
    expect(find.byType(PedalPiece), findsOneWidget);
    await tester.pumpWidget(
      _host(const GearPiece(model: 'Dark Twin', kind: GearKind.amp, fit: fit)),
    );
    expect(find.byType(AmpPiece), findsOneWidget);
    await tester.pumpWidget(
      _host(const GearPiece(model: 'User IR 1', kind: GearKind.cab, fit: fit)),
    );
    expect(find.byType(CabPiece), findsOneWidget);
  });

  testWidgets('GenericSpec draws the generic piece', (tester) async {
    for (final k in GearKind.values) {
      await tester.pumpWidget(
        _host(
          GearPiece(model: 'No Such Model', kind: k, fit: const Size(300, 300)),
        ),
      );
      expect(find.byType(GenericPiece), findsOneWidget, reason: '$k');
    }
  });

  testWidgets('knobNames overrides the spec names', (tester) async {
    await tester.pumpWidget(
      _host(
        const GearPiece(
          model: 'Studio Delay',
          kind: GearKind.pedal,
          fit: Size(660, 440),
          knobNames: ['A', 'B'],
        ),
      ),
    );
    expect(find.byType(PedalPiece), findsOneWidget);
    expect(tester.widget<PedalPiece>(find.byType(PedalPiece)).spec.knobNames, [
      'A',
      'B',
    ]);
  });

  // Pass-through: a known pedal, a known amp and a generic pedal.
  const cases = [
    ('B-Chorus', GearKind.pedal, null, 'footswitch'),
    ('Dark Twin', GearKind.amp, null, 'jewel'),
    ('No Such Pedal', GearKind.pedal, ['Aaa', 'Bbb', 'Ccc'], 'footswitch'),
  ];
  for (final (m, k, names, sw) in cases) {
    testWidgets('$m ($k): knob drag, switch tap and lit pass through', (
      tester,
    ) async {
      final got = <(int, double)>[];
      var taps = 0;
      Widget build({bool lit = true}) => _host(
        GearPiece(
          model: m,
          kind: k,
          fit: const Size(660, 440),
          values: const [10, 40, 90, 50, 50, 50, 50, 50],
          onKnob: got.add,
          onSwitch: () => taps++,
          lit: lit,
          knobNames: names,
        ),
      );
      await tester.pumpWidget(build());
      await tester.drag(
        find
            .byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is GearKnobPainter,
            )
            .first,
        const Offset(0, -60),
      );
      expect(got, isNotEmpty);
      await tester.tap(find.byKey(Key(sw)));
      expect(taps, 1);
      final inner = tester.widget<Widget>(
        find.byWidgetPredicate((w) => w is PedalPiece || w is AmpPiece),
      );
      expect((inner is PedalPiece ? inner.lit : (inner as AmpPiece).lit), true);
      await tester.pumpWidget(build(lit: false));
      final off = tester.widget<Widget>(
        find.byWidgetPredicate((w) => w is PedalPiece || w is AmpPiece),
      );
      expect((off is PedalPiece ? off.lit : (off as AmpPiece).lit), false);
    });
  }

  testWidgets('generic knobNames set the knob count and labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const GearPiece(
          model: 'No Such Pedal',
          kind: GearKind.pedal,
          fit: Size(660, 440),
          knobNames: ['Aaa', 'Bbb', 'Ccc', 'Ddd', 'Eee'],
        ),
      ),
    );
    expect(find.text('DDD'), findsOneWidget);
    expect(find.text('EEE'), findsOneWidget);
  });

  testWidgets('values shorter or longer than knobNames render', (tester) async {
    for (final vals in [
      <double?>[10],
      <double?>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    ]) {
      for (final (m, k) in _models) {
        await tester.pumpWidget(
          _host(
            GearPiece(
              model: m,
              kind: k,
              fit: const Size(660, 440),
              values: vals,
              knobNames: k == GearKind.cab ? null : ['A', 'B', 'C'],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('empty knobNames fall back to the spec', (tester) async {
    for (final (m, k) in [..._models, ('No Such Pedal', GearKind.pedal)]) {
      await tester.pumpWidget(
        _host(
          GearPiece(
            model: m,
            kind: k,
            fit: const Size(660, 440),
            knobNames: const [],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
