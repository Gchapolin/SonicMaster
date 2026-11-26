import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_specs.dart';
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

// flutter_test does not walk fontFamilyFallback, so the bundled Oswald also
// stands in for Barlow Condensed and Share Tech Mono (not bundled yet).
Future<void> _loadFont() async {
  for (final family in const [
    'Oswald',
    'Barlow Condensed',
    'Share Tech Mono',
  ]) {
    final fl = FontLoader(family)
      ..addFont(rootBundle.load('assets/fonts/Oswald.ttf'));
    await fl.load();
  }
}

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

  testWidgets('the model name is printed on the pedal', (tester) async {
    await tester.pumpWidget(
      _host(PedalPiece(spec: pedalSpecs['Phaser M']!, model: 'Phaser M')),
    );
    // mxr keeps the case (no uppercase transform).
    expect(find.text('Phaser M'), findsOneWidget);
  });

  testWidgets('eight knobs fit without overflow', (tester) async {
    await _loadFont();
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
    await _loadFont();
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
    await _loadFont();
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
