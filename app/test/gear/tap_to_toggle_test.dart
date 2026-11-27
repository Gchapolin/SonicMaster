import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
import 'package:sonicmaster/gear/pedal_piece.dart';

/// Like a real stompbox: a tap anywhere on the piece switches the block,
/// a tap on a knob or slider doesn't.
void main() {
  var taps = 0;
  void sw() => taps++;

  Future<void> pump(WidgetTester tester, String model) async {
    taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: GearPiece(
            model: model,
            kind: GearKind.pedal,
            fit: const Size(300, 400),
            onKnob: (_) {},
            onSwitch: sw,
          ),
        ),
      ),
    );
  }

  testWidgets('a tap on a pedal with no footswitch (EQ) switches it', (
    tester,
  ) async {
    await pump(tester, 'GT EQ 1');
    final r = tester.getRect(find.byType(PedalPiece));

    // The plate, under the sliders and the title.
    await tester.tapAt(Offset(r.center.dx, r.top + r.height * 0.85));
    expect(taps, 1);
  });

  testWidgets('a tap on the body of a stompbox switches it', (tester) async {
    await pump(tester, 'Pure');
    final r = tester.getRect(find.byType(PedalPiece));

    await tester.tapAt(Offset(r.left + 6, r.center.dy));
    expect(taps, 1);
  });

  testWidgets('a tap on a knob or a slider does not switch', (tester) async {
    for (final m in ['Pure', 'GT EQ 1', 'Studio EQ']) {
      await pump(tester, m);
      await tester.tap(find.byType(KnobDrag).first);
      expect(taps, 0, reason: m);
    }
  });

  testWidgets('the footswitch switches once, not twice', (tester) async {
    await pump(tester, 'Slap');
    await tester.tap(find.byKey(const Key('footswitch')));
    expect(taps, 1);
  });
}
