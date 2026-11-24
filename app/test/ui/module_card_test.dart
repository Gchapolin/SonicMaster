import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/ui/chain_view.dart';
import 'package:sonicmaster/ui/led_button.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('renders name + effect and fires onSelect on body tap', (
    tester,
  ) async {
    var selects = 0;

    await tester.pumpWidget(
      host(
        ModuleCard(
          iconId: 0,
          name: 'NR',
          effect: 'Gate',
          isOn: true,
          isSelected: false,
          isEnabled: true,
          onSelect: () => selects++,
          onToggle: () {},
        ),
      ),
    );
    expect(find.text('NR'), findsOneWidget);
    expect(find.text('Gate'), findsOneWidget);
    await tester.tap(find.text('NR'));
    expect(selects, 1);
  });

  testWidgets('the LedButton reflects on and fires onToggle', (tester) async {
    var toggles = 0;

    await tester.pumpWidget(
      host(
        ModuleCard(
          iconId: 1,
          name: 'FX1',
          effect: 'Comp',
          isOn: true,
          isSelected: false,
          isEnabled: true,
          onSelect: () {},
          onToggle: () => toggles++,
        ),
      ),
    );
    final led = tester.widget<LedButton>(find.byType(LedButton));

    expect(led.isOn, isTrue);
    await tester.tap(find.byType(LedButton));
    expect(toggles, 1);
  });

  testWidgets('off card dims the display but not the LedButton', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ModuleCard(
          iconId: 2,
          name: 'DRV',
          effect: 'TS808',
          isOn: false,
          isSelected: false,
          isEnabled: true,
          onSelect: () {},
          onToggle: () {},
        ),
      ),
    );
    // The name sits under a 0.4 Opacity; the LedButton does not.
    final dimmed = tester.widget<Opacity>(
      find.ancestor(of: find.text('DRV'), matching: find.byType(Opacity)),
    );

    expect(dimmed.opacity, 0.4);
    expect(
      find.ancestor(of: find.byType(LedButton), matching: find.byType(Opacity)),
      findsNothing,
    );
  });

  testWidgets('disabled gives the LedButton a null onTap', (tester) async {
    await tester.pumpWidget(
      host(
        const ModuleCard(
          iconId: 3,
          name: 'AMP',
          effect: null,
          isOn: true,
          isSelected: false,
          isEnabled: false,
        ),
      ),
    );
    expect(tester.widget<LedButton>(find.byType(LedButton)).onTap, isNull);
  });

  Color? cardFill(WidgetTester tester) {
    final box = tester.widget<Container>(
      find
          .ancestor(of: find.text('AMP'), matching: find.byType(Container))
          .last,
    );

    return (box.decoration as BoxDecoration?)?.color;
  }

  ModuleCard amp({required bool isSelected}) => ModuleCard(
    iconId: 3,
    name: 'AMP',
    effect: 'Doctor CL',
    isOn: true,
    isSelected: isSelected,
    isEnabled: true,
    onSelect: () {},
    onToggle: () {},
  );

  testWidgets('a selected card is filled with secondaryContainer', (
    tester,
  ) async {
    await tester.pumpWidget(host(amp(isSelected: true)));
    expect(cardFill(tester), Palette.secondaryContainer);
  });

  testWidgets('an unselected card is filled with surfaceContainerLow', (
    tester,
  ) async {
    await tester.pumpWidget(host(amp(isSelected: false)));
    expect(cardFill(tester), Palette.surfaceContainerLow);
  });

  testWidgets('the card keeps its module icon', (tester) async {
    await tester.pumpWidget(host(amp(isSelected: false)));
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  Color? nameColor(WidgetTester tester) =>
      tester.widget<Text>(find.text('AMP')).style?.color;

  testWidgets('a selected card names its module in onSecondaryContainer '
      '(7:1 on its fill)', (tester) async {
    await tester.pumpWidget(host(amp(isSelected: true)));
    expect(nameColor(tester), Palette.onSecondaryContainer);
  });

  testWidgets('a tap in the rounded corner still selects the card', (
    tester,
  ) async {
    var selects = 0;

    await tester.pumpWidget(
      host(
        ModuleCard(
          iconId: 3,
          name: 'AMP',
          isOn: true,
          isSelected: false,
          isEnabled: true,
          onSelect: () => selects++,
          onToggle: () {},
        ),
      ),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byType(ModuleCard)) + const Offset(1, 1),
    );
    expect(selects, 1);
  });
}
