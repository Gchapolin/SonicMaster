import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_specs.dart';
import 'package:sonicmaster/gear/pedal_piece.dart';

const _names = ['125Hz', '400Hz', '800Hz', '1.6kHz', '4kHz', 'Vol'];

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

PedalSpec _spec() {
  final s = pedalSpecs['GT EQ 1']!;
  return PedalSpec(s.family, s.body, s.label, s.knob, _names);
}

void main() {
  testWidgets('the editor shows each band and its value under the slider', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        PedalPiece(
          spec: _spec(),
          model: 'GT EQ 1',
          values: const [47, 38, 42, 50, 58, 50],
          valueTexts: const ['-3', '-12', '-8', '0', '+8', '50'],
        ),
      ),
    );

    for (final t in ['125', '400', '800', '1.6K', '4K', 'VOL']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    for (final t in ['-3', '-12', '-8', '0', '+8', '50']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('without values (catalog) the EQ stays as in the prototype', (
    tester,
  ) async {
    await tester.pumpWidget(_host(PedalPiece(spec: _spec(), model: 'GT EQ 1')));

    expect(find.text('125'), findsNothing);
    expect(find.text('VOL'), findsNothing);
  });

  testWidgets('labels keep the case size', (tester) async {
    final plain = await _size(tester, null);
    final labelled = await _size(tester, const ['0', '0', '0', '0', '0', '50']);

    expect(labelled, plain);
    expect(tester.takeException(), isNull);
  });
}

Future<Size> _size(WidgetTester tester, List<String>? texts) async {
  await tester.pumpWidget(
    _host(PedalPiece(spec: _spec(), model: 'GT EQ 1', valueTexts: texts)),
  );
  return tester.getSize(find.byType(PedalPiece));
}
