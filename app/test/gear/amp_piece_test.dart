import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/amp_piece.dart';
import 'package:sonicmaster/gear/gear_specs.dart';
import 'package:sonicmaster/model/amp_gain.dart';

// The amps in amp_gain.dart order (clean, crunch, rock/lead, high gain, bass).
const _models = [
  'Jazz 120', 'Dark Twin', 'Calif Star CL', 'Bog SV CL', 'Doctor CL', //
  'Superb CL',
  'Voks 30N', 'B-Man N', 'TWD Deluxe', 'B-Man B', 'Voks 30TB', 'Brit 45', //
  'Brit 50', 'Brit 50JP', 'Superb OD', 'Doctor OD',
  'Supero 2 OD', 'Sol 100 OD', 'Brit 800', 'Tanger R100', 'Brit 900', //
  'Bog XT M', 'Flyman B1', 'Calif IIC+',
  'Sol 100 LD', 'Flyman B1+', 'Calif IV LD', 'Bog XT V', 'Calif DualV', //
  'Calif DualM', 'Halen 51', 'Eng 120', 'Eng Power', 'Dizzy VH', 'Dizzy VH+',
  'A BassVT', 'Voks Bass', 'Calif Bass',
];

// flutter_test does not walk fontFamilyFallback, so the bundled Oswald
// stands in for Barlow Condensed (not bundled yet).
Future<void> _loadFont() async {
  for (final family in const ['Oswald', 'Barlow Condensed']) {
    final fl = FontLoader(family)
      ..addFont(rootBundle.load('assets/fonts/Oswald.ttf'));
    await fl.load();
  }
}

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

AmpPiece _amp(
  String m, {
  bool lit = true,
  ValueChanged<(int, double)>? onKnob,
  VoidCallback? onSwitch,
}) => AmpPiece(
  spec: ampSpecs[m]!,
  model: m,
  lit: lit,
  onKnob: onKnob,
  onSwitch: onSwitch,
);

/// Mean red minus mean green over the jewel: high when it glows.
Future<double> _jewelRed(WidgetTester tester) async {
  final box = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('shot')),
  );
  final r = tester.getRect(find.byKey(const Key('jewel')));
  final origin = tester.getTopLeft(find.byKey(const Key('shot')));
  final bytes = (await tester.runAsync(() async {
    final img = await box.toImage();
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = img.width;
    img.dispose();
    return (data!, w);
  }))!;
  var sum = 0.0, n = 0;
  final c = r.center - origin;
  for (var y = c.dy.round() - 3; y <= c.dy.round() + 3; y++) {
    for (var x = c.dx.round() - 3; x <= c.dx.round() + 3; x++) {
      final i = (y * bytes.$2 + x) * 4;
      sum += bytes.$1.getUint8(i) - bytes.$1.getUint8(i + 1);
      n++;
    }
  }
  return sum / n;
}

void main() {
  test('the golden list is every amp in amp_gain order', () {
    expect(_models.length, ampGainBands.values.expand((e) => e).length);
    expect(_models.toSet(), ampSpecs.keys.toSet());
  });

  testWidgets('natural size: head 250x104, combo 230x184', (tester) async {
    await tester.pumpWidget(_host(_amp('Brit 800')));
    expect(tester.getSize(find.byType(AmpPiece)), const Size(250, 104));
    await tester.pumpWidget(_host(_amp('Dark Twin')));
    expect(tester.getSize(find.byType(AmpPiece)), const Size(230, 184));
  });

  testWidgets('every amp lays out without overflow', (tester) async {
    await _loadFont();
    for (final m in _models) {
      for (final lit in const [true, false]) {
        await tester.pumpWidget(_host(_amp(m, lit: lit)));
        expect(tester.takeException(), isNull, reason: m);
        expect(find.text(m.toUpperCase()), findsOneWidget, reason: m);
      }
    }
  });

  testWidgets('the jewel light follows lit', (tester) async {
    Future<double> red(bool lit) async {
      await tester.pumpWidget(
        _host(
          RepaintBoundary(
            key: const Key('shot'),
            child: _amp('Brit 800', lit: lit),
          ),
        ),
      );
      return _jewelRed(tester);
    }

    final on = await red(true);
    final off = await red(false);
    expect(on, greaterThan(off + 60));
  });

  testWidgets('knob drag on a head reports the index', (tester) async {
    final got = <(int, double)>[];
    await tester.pumpWidget(
      _host(
        AmpPiece(
          spec: ampSpecs['Brit 800']!,
          model: 'Brit 800',
          values: const [10, 20, 30, 40, 50, 60],
          onKnob: got.add,
        ),
      ),
    );
    await tester.drag(find.text('BASS'), const Offset(0, -40));
    expect(got, isNotEmpty);
    expect(got.every((e) => e.$1 == 3), true);
    expect(got.last.$2, greaterThan(40));
  });

  testWidgets('tapping the pilot jewel calls onSwitch', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(_amp('Dark Twin', onSwitch: () => taps++)));
    await tester.tap(find.byKey(const Key('jewel')));
    expect(taps, 1);
  });

  testWidgets('the jewel target is about 44pt and ignores the drawing', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_host(_amp('Brit 45', onSwitch: () => taps++)));
    final hit = tester.getRect(find.byKey(const Key('jewel-hit')));
    expect(hit.width, greaterThanOrEqualTo(37));
    expect(hit.height, greaterThanOrEqualTo(40));
    final c = tester.getCenter(find.byKey(const Key('jewel')));
    // 16px left and 17px above the 13px glass: outside it, inside the target.
    await tester.tapAt(c + const Offset(-16, -17));
    expect(taps, 1);
    expect(tester.getSize(find.byKey(const Key('jewel'))), const Size(13, 13));
  });

  testWidgets('head toggles are centred on the panel row', (tester) async {
    await tester.pumpWidget(_host(_amp('Brit 45')));
    final jewel = tester.getCenter(find.byKey(const Key('jewel'))).dy;
    final toggles = find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == 9 && w.height == 9,
    );
    expect(toggles, findsNWidgets(2));
    expect(tester.getCenter(toggles.first).dy, closeTo(jewel, 0.5));
  });

  test('bass panel labels are light on the blue band', () {
    expect(AmpPanel.svt.ink.computeLuminance(), greaterThan(0.5));
  });

  test('tolex and grille kinds come from the prototype tables', () {
    expect(ampSpecs['TWD Deluxe']!.tolex, Tolex.tweed);
    expect(ampSpecs['Superb CL']!.tolex, Tolex.blue);
    expect(ampSpecs['Halen 51']!.grille.lightAmp, false);
    expect(ampSpecs['Voks 30N']!.grille, Grille.diamond);
    expect(cabSpecs.values.every((c) => c.tolex.color.a == 1), true);
    expect(Grille.cream.lightAmp, true);
    expect(Grille.check.goldBadgeCab, true);
    expect(Grille.black.goldBadgeCab, false);
  });

  testWidgets('the badge stays readable on a light grille', (tester) async {
    (Color, Color) badge() {
      final box = tester.widget<Container>(find.byKey(const Key('badge')));
      final plate = (box.decoration! as BoxDecoration).gradient!.colors.first;
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('badge')),
          matching: find.byType(Text),
        ),
      );
      return (plate, text.style!.color!);
    }

    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) /
          (la > lb ? lb + 0.05 : la + 0.05);
    }

    // Light cloth (Jazz 120): black enamel plate, gold lettering.
    await tester.pumpWidget(_host(_amp('Jazz 120')));
    var (plate, text) = badge();
    expect(plate.computeLuminance(), lessThan(0.05));
    expect(text, const Color(0xFFD9B860));
    expect(contrast(plate, text), greaterThan(4.5));
    // Dark cloth (Brit 800): chrome plate, dark lettering.
    await tester.pumpWidget(_host(_amp('Brit 800')));
    (plate, text) = badge();
    expect(plate.computeLuminance(), greaterThan(0.5));
    expect(text, const Color(0xFF1A1A1A));
    expect(contrast(plate, text), greaterThan(4.5));
  });

  testWidgets('amps golden (38 amps, clean to bass)', (tester) async {
    await _loadFont();
    tester.view.physicalSize = const Size(1360, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        RepaintBoundary(
          key: const Key('amps'),
          child: Container(
            width: 1360,
            color: const Color(0xFF4A3530),
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 18,
              runSpacing: 24,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [for (final m in _models) _amp(m)],
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const Key('amps')),
      matchesGoldenFile('goldens/amps.png'),
    );
  });
}
