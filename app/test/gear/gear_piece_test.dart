import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/amp_piece.dart';
import 'package:sonicmaster/gear/cab_piece.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
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
}
