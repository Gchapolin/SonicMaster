import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

void main() {
  Future<void> pump(WidgetTester tester, SonicButton button) =>
      tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: button),
        ),
      );

  Finder plate() => find
      .descendant(
        of: find.byType(SonicButton),
        matching: find.byType(CustomPaint),
      )
      .first;

  Color? labelColor(WidgetTester tester) =>
      tester.widget<Text>(find.text('TAP')).style?.color;

  testWidgets('lit: only the label lights up, the fill stays tonal', (
    tester,
  ) async {
    await pump(
      tester,
      SonicButton(label: 'TAP', isLit: true, onPressed: () {}),
    );

    expect(labelColor(tester), Palette.primary);
    expect(plate(), paints..rrect(color: Palette.secondaryContainer));
  });

  testWidgets('accent: the whole button fills with the primary color', (
    tester,
  ) async {
    await pump(
      tester,
      SonicButton(label: 'TAP', isAccent: true, onPressed: () {}),
    );

    expect(labelColor(tester), Palette.onPrimary);
    expect(plate(), paints..rrect(color: Palette.primary));
  });
}
