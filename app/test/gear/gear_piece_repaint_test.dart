import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_piece.dart';

void main() {
  testWidgets('a GearPiece paints in its own layer', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: GearPiece(
          model: 'Gate',
          kind: GearKind.pedal,
          fit: Size(200, 150),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(GearPiece),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
    // The outermost widget under GearPiece is the boundary itself.
    expect(
      tester.widget(
        find
            .descendant(
              of: find.byType(GearPiece),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      ),
      isA<RepaintBoundary>(),
    );
  });
}
