import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/ui/led_button.dart';

void main() {
  testWidgets('renders the label and fires onTap', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LedButton(isOn: true, label: 'FX1', onTap: () => taps++),
          ),
        ),
      ),
    );
    expect(find.text('FX1'), findsOneWidget);
    await tester.tap(find.text('FX1'));
    expect(taps, 1);
  });

  double opacityOf(WidgetTester tester, String label) => tester
      .widget<Opacity>(
        find.ancestor(of: find.text(label), matching: find.byType(Opacity)),
      )
      .opacity;

  testWidgets('a null onTap does not fire and dims to 0.5', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: LedButton(isOn: false, label: 'NR')),
        ),
      ),
    );
    await tester.tap(find.text('NR'), warnIfMissed: false);
    expect(find.text('NR'), findsOneWidget); // no throw, still there
    expect(opacityOf(tester, 'NR'), 0.5); // disabled -> dimmed
  });

  testWidgets('an enabled button is fully opaque', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LedButton(isOn: true, label: 'ON', onTap: () {}),
          ),
        ),
      ),
    );
    expect(opacityOf(tester, 'ON'), 1);
  });

  testWidgets('builds without error for on and off', (tester) async {
    for (final isOn in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LedButton(isOn: isOn, label: 'X', onTap: () {}),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  Finder dot() => find
      .descendant(
        of: find.byType(LedButton),
        matching: find.byType(CustomPaint),
      )
      .first;

  testWidgets('on: a filled dot in the primary color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LedButton(isOn: true, label: '', onTap: () {}),
          ),
        ),
      ),
    );
    expect(
      dot(),
      paints..circle(color: Palette.primary, style: PaintingStyle.fill),
    );
  });

  testWidgets('off: an outline ring', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LedButton(isOn: false, label: '', onTap: () {}),
          ),
        ),
      ),
    );
    expect(
      dot(),
      paints..circle(color: Palette.outline, style: PaintingStyle.stroke),
    );
  });

  testWidgets('the dot is 60% of the button height, easy to see', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LedButton(isOn: true, label: '', onTap: () {}),
          ),
        ),
      ),
    );
    // Default height 26 -> diameter 15.6 -> radius 7.8.
    expect(dot(), paints..circle(radius: 26 * 0.6 / 2, color: Palette.primary));
  });
}
