import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/cab_piece.dart';
import 'package:sonicmaster/gear/gear_specs.dart';

// flutter_test does not walk fontFamilyFallback, so the bundled Oswald also
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

Widget _cab(String m) => CabPiece(spec: cabSpecs[m]!, model: m);

Finder _speakers() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('speaker-'),
);

// The 18 prototype cabs plus one User IR (the other nine look the same).
final _golden = [
  ...cabSpecs.keys.where((m) => !m.startsWith('User IR')),
  'User IR 1',
];

void main() {
  test('the golden covers the 18 prototype cabs and one User IR', () {
    expect(_golden.length, 19);
  });

  testWidgets('natural size matches the prototype', (tester) async {
    const sizes = {
      'TWD 1x8': Size(84, 90), // 1 x 54 + 30, 1 x 54 + 36
      'TWD-P 1x10': Size(82, 88),
      'Viblux 1x12': Size(92, 98),
      'TWD 2x12': Size(154, 98),
      'Mark 2x10': Size(82, 140), // 10" 2x: stacked
      'BritGN 4x12': Size(154, 160),
      'Bass 4x10': Size(134, 146), // 10" 4x: 6px taller
      'User IR 1': Size(92, 98),
    };
    for (final e in sizes.entries) {
      await tester.pumpWidget(_host(_cab(e.key)));
      expect(tester.getSize(find.byType(CabPiece)), e.value, reason: e.key);
    }
  });

  testWidgets('speaker count follows the spec', (tester) async {
    for (final (m, n) in const [
      ('Viblux 1x12', 1),
      ('TWD 2x12', 2),
      ('Mark 2x10', 2),
      ('Dual 4x12', 4),
    ]) {
      await tester.pumpWidget(_host(_cab(m)));
      expect(_speakers(), findsNWidgets(n), reason: m);
    }
  });

  testWidgets('the model name is on the badge', (tester) async {
    await tester.pumpWidget(_host(_cab('User IR 3')));
    expect(find.text('USER IR 3'), findsOneWidget);
  });

  testWidgets('the badge plate is text + 12 padding + 2 border, even if long', (
    tester,
  ) async {
    await _loadFont();
    for (final m in const ['Mark 2x10', 'User IR 10']) {
      await tester.pumpWidget(
        _host(CabPiece(spec: cabSpecs[m] ?? cabSpecs['User IR 1']!, model: m)),
      );
      final plate = tester.getRect(find.byKey(const Key('cab-badge')));
      final text = tester.getRect(find.text(m.toUpperCase()));
      expect(plate.width, text.width + 14, reason: m);
      expect(plate.height, text.height + 2, reason: m);
    }
  });

  testWidgets('the badge is painted after the corners', (tester) async {
    await tester.pumpWidget(_host(_cab('Mark 2x10')));
    final stack = tester.widget<Stack>(
      find
          .descendant(of: find.byType(CabPiece), matching: find.byType(Stack))
          .first,
    );
    int at(String k) => stack.children.indexWhere((w) => w.key == Key(k));
    expect(at('cab-badge-pos'), greaterThan(at('cab-corner-3')));
  });

  testWidgets('a slant cab keeps its corners and piping', (tester) async {
    await tester.pumpWidget(
      _host(RepaintBoundary(key: const Key('cab'), child: _cab('BritGN 4x12'))),
    );
    // Not clipped: the grille fills the whole content box (body minus the
    // 1px border and 9/9/18 padding).
    expect(
      tester.getRect(find.byKey(const Key('cab-grille'))),
      const Rect.fromLTWH(10, 10, 134, 131),
    );
    expect(find.byKey(const Key('cab-corner-3')), findsOneWidget);

    final px = await tester.runAsync(() async {
      final ro = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('cab')),
      );
      final img = await ro.toImage();
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = img.width;
      img.dispose();
      return (Offset p) {
        final i = (p.dy.toInt() * w + p.dx.toInt()) * 4;
        return Color.fromARGB(
          255,
          data!.getUint8(i),
          data.getUint8(i + 1),
          data.getUint8(i + 2),
        );
      };
    });
    bool cream(Color c) => c.r > 0.7 && c.g > 0.7 && c.b > 0.6;
    // Cream piping 2px inside the grille, on every side and at the top
    // corners of the leaning baffle (a clipped slant would lose those).
    for (final p in const [
      Offset(12, 80), // left
      Offset(141, 80), // right
      Offset(77, 12), // top
      Offset(77, 138), // bottom
      Offset(16, 12), // top-left, past the chrome corner
      Offset(137, 12), // top-right, past the chrome corner
    ]) {
      expect(cream(px!(p)), true, reason: '$p ${px(p)}');
    }
    // Chrome corner protectors on all four corners.
    for (final p in const [
      Offset(6, 6),
      Offset(144, 6),
      Offset(6, 150),
      Offset(144, 150),
    ]) {
      expect(px!(p).r, greaterThan(0.5), reason: '$p ${px(p)}');
    }
    // The leaning baffle's seam: a dark line just under the middle of the
    // grille, between the left piping and the first speaker.
    final seam = 10 + 131 * 0.4675;
    expect(px!(Offset(16, seam)).r, lessThan(px(Offset(16, seam - 8)).r));
  });

  testWidgets('every cab lays out without overflow', (tester) async {
    await _loadFont();
    for (final m in cabSpecs.keys) {
      await tester.pumpWidget(_host(_cab(m)));
      expect(tester.takeException(), isNull, reason: m);
    }
  });

  testWidgets('cabs golden (18 prototype cabs and a User IR)', (tester) async {
    await _loadFont();
    tester.view.physicalSize = const Size(1100, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        RepaintBoundary(
          key: const Key('cabs'),
          child: Container(
            width: 1100,
            color: const Color(0xFF4A3530),
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 22,
              runSpacing: 28,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [for (final m in _golden) _cab(m)],
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const Key('cabs')),
      matchesGoldenFile('goldens/cabs.png'),
    );
  });
}
