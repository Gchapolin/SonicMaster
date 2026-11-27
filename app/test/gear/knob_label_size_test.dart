import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_lookup.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
import 'package:sonicmaster/gear/gear_specs.dart';

/// The knob labels of one piece share one size: a long name shrinks every
/// label of the piece with it, never just itself (the Analog rack drew
/// "F.BACK" smaller than MIX / TONE / DUCK).
void main() {
  Widget host(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: child),
  );

  // The rendered (transformed) heights of [names]' labels.
  List<double> heights(WidgetTester tester, List<String> names) => [
    for (final n in names) tester.getRect(find.text(n.toUpperCase())).height,
  ];

  Future<void> expectShared(
    WidgetTester tester,
    String model,
    GearKind kind,
    List<String> names,
  ) async {
    await tester.pumpWidget(
      host(
        GearPiece(
          model: model,
          kind: kind,
          fit: const Size(600, 400),
          knobNames: names,
        ),
      ),
    );

    // (Sliders and wahs draw no knob labels.)
    final h = heights(tester, [
      for (final n in names)
        if (find.text(n.toUpperCase()).evaluate().length == 1) n,
    ]);

    for (final x in h) {
      expect(x, moreOrLessEquals(h.first, epsilon: 0.01), reason: '$model $h');
    }
  }

  testWidgets('the Analog rack: F.BACK as big as MIX, TONE, DUCK', (
    tester,
  ) async {
    await expectShared(tester, 'Analog', GearKind.pedal, [
      'Mix',
      'F.Back',
      'Tone',
      'Duck',
    ]);
  });

  testWidgets('every pedal and amp shares one label size', (tester) async {
    for (final e in pedalSpecs.entries) {
      final names = e.value.knobNames
          .where((n) => n.isNotEmpty && n.toUpperCase() != e.key.toUpperCase())
          .toSet();

      // (A piece whose names repeat could not be told apart by text.)
      if (names.length < 2 || names.length != e.value.knobNames.length) {
        continue;
      }

      await expectShared(tester, e.key, GearKind.pedal, names.toList());
    }
    for (final e in ampSpecs.entries) {
      final names = e.value.knobNames.toSet();

      if (names.length < 2 || names.length != e.value.knobNames.length) {
        continue;
      }

      await expectShared(tester, e.key, GearKind.amp, names.toList());
    }
  });
}
