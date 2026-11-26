import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/state/edit_providers.dart';
import 'package:sonicmaster/state/layout_providers.dart';
import 'package:sonicmaster/theme/app_text.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

import '../support/page_harness.dart';
import '../support/sonic_host.dart';
import '../support/view_helpers.dart';

void main() {
  group('placeDropdownMenu', () {
    test('opens below with the 300-px cap when there is room', () {
      final placement = placeDropdownMenu(
        trigger: const Rect.fromLTWH(100, 100, 110, 40),
        screen: const Size(1280, 800),
        bottomInset: 0,
        menuWidth: 110,
        contentHeight: 2000,
      );

      expect(placement, (isAbove: false, maxHeight: 300.0, dx: 0.0));
    });

    test('a short list that fits below keeps today\'s placement', () {
      final placement = placeDropdownMenu(
        trigger: const Rect.fromLTWH(100, 200, 110, 40),
        screen: const Size(568, 320),
        bottomInset: 0,
        menuWidth: 110,
        contentHeight: 40,
      );

      // 320 - 8 - 6 - 240 = 66 below; 66 - 14 = 52 >= 40, so the list fits.
      expect(placement, (isAbove: false, maxHeight: 52.0, dx: 0.0));
    });

    test('flips above when the space below is short', () {
      final placement = placeDropdownMenu(
        trigger: const Rect.fromLTWH(100, 260, 110, 40),
        screen: const Size(568, 320),
        bottomInset: 0,
        menuWidth: 110,
        contentHeight: 2000,
      );

      expect(placement.isAbove, isTrue);
      expect(placement.maxHeight, 260 - 6 - 8 - 14);
    });

    test('caps the list to the room left above the soft keyboard', () {
      final placement = placeDropdownMenu(
        trigger: const Rect.fromLTWH(100, 80, 110, 40),
        screen: const Size(852, 393),
        bottomInset: 180,
        menuWidth: 110,
        contentHeight: 2000,
      );

      expect(placement.isAbove, isFalse); // 79 px below beats 66 above
      expect(placement.maxHeight, 393 - 180 - 8 - 6 - 120 - 14);
    });

    test('shifts left to stay on screen', () {
      final placement = placeDropdownMenu(
        trigger: const Rect.fromLTWH(500, 100, 60, 40),
        screen: const Size(568, 320),
        bottomInset: 0,
        menuWidth: 200,
        contentHeight: 100,
      );

      expect(placement.dx, 568 - 8 - 200 - 500);
    });

    test('shifts right off the left edge', () {
      final placement = placeDropdownMenu(
        trigger: const Rect.fromLTWH(2, 100, 60, 40),
        screen: const Size(568, 320),
        bottomInset: 0,
        menuWidth: 100,
        contentHeight: 100,
      );

      expect(placement.dx, 6);
    });
  });

  // The module editor's effect dropdown (FX1 holds COMP 1) as a real
  // SonicDropdown host; its menu lists COMP 2 among others.
  group('a SonicDropdown in the module editor', () {
    Future<void> openEffects(WidgetTester tester, {required Size size}) async {
      await pumpPage(
        tester,
        size: size,
        selectedEffects: const {1: 101},
        parameters: const {1: {}},
        overrides: [selectedModuleProvider.overrideWith((_) => 1)],
      );
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
    }

    Rect trigger(WidgetTester tester) => tester.getRect(_trigger);

    // The menu's plate: the SonicSurface closest around a menu row.
    Rect menu(WidgetTester tester) => tester.getRect(
      find
          .ancestor(
            of: find.text('COMP 2'),
            matching: find.byType(SonicSurface),
          )
          .first,
    );

    // On screen (above the keyboard) and attached to its trigger: 6 px below
    // it, or 6 px above it.
    void expectPlaced(WidgetTester tester, Rect visible) {
      final (menuRect, triggerRect) = (menu(tester), trigger(tester));

      expectWithin(menuRect, visible, 'the menu');
      expect(
        (menuRect.top - triggerRect.bottom - 6).abs() < 0.01 ||
            (triggerRect.top - menuRect.bottom - 6).abs() < 0.01,
        isTrue,
        reason: 'menu $menuRect is not attached to its trigger $triggerRect',
      );
    }

    testWidgets('568x320: it opens upward, fully on screen', (tester) async {
      await openEffects(tester, size: const Size(568, 320));

      expect(menu(tester).bottom, lessThanOrEqualTo(trigger(tester).top));
      expectPlaced(tester, const Rect.fromLTWH(0, 0, 568, 320));
    });

    // The dropdown sits in a SonicDialog, which lifts its plate above the
    // keyboard (compact): closing the keyboard moves the trigger, so the open
    // menu must be placed again for the new spot.
    testWidgets('the keyboard closing under it: it stays open and re-places', (
      tester,
    ) async {
      const size = Size(852, 393);
      final context = await pumpSonicHost(tester, size: size);

      unawaited(
        showSonicDialog<void>(
          context: context,
          builder: (_) => SonicDialog(
            child: SonicDropdown<int>(
              value: 1,
              width: 120,
              items: [
                for (var n = 1; n <= 12; n++) (value: n, label: 'Item $n'),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await setKeyboard(tester, 180);
      await tester.pumpAndSettle();

      final dropdown = find.byType(SonicDropdown<int>);

      await tester.tap(find.text('Item 1'));
      await tester.pumpAndSettle();

      final before = tester.getRect(dropdown);
      final menuRow = find.text('Item 2');

      Rect menu() => tester.getRect(
        find.ancestor(of: menuRow, matching: find.byType(SonicSurface)).first,
      );

      await setKeyboard(tester, 0);
      await tester.pumpAndSettle();

      final trigger = tester.getRect(dropdown);

      expect(trigger, isNot(before)); // the dialog re-centred
      expect(menuRow, findsOneWidget); // still open

      // The list's natural height, as _listHeight works it out: one row of a
      // menu-text line plus 20 px per item.
      final painter = TextPainter(
        text: const TextSpan(text: 'Ag', style: AppText.menuItem),
        textDirection: TextDirection.ltr,
      )..layout();
      final contentHeight = 12 * (painter.height + 20);

      painter.dispose();

      final expected = placeDropdownMenu(
        trigger: trigger,
        screen: size,
        bottomInset: 0,
        menuWidth: 120,
        contentHeight: contentHeight,
      );
      final height =
          math.min(expected.maxHeight, contentHeight) + dropdownMenuChrome;
      final left = trigger.left + expected.dx;
      final rect = menu();

      expect(
        rect,
        expected.isAbove
            ? Rect.fromLTWH(
                left,
                trigger.top - dropdownMenuGap - height,
                120,
                height,
              )
            : Rect.fromLTWH(
                left,
                trigger.bottom + dropdownMenuGap,
                120,
                height,
              ),
      );
      expectWithin(rect, Offset.zero & size, 'the menu');
    });

    // A phone turned to portrait and back while the menu is open: the menu
    // must land on screen again, attached to the trigger, not keep the
    // placement it had for the other orientation.
    testWidgets('turning the phone and back: it stays open and on screen', (
      tester,
    ) async {
      await openEffects(tester, size: const Size(852, 393));

      tester.view.physicalSize = const Size(393, 852);
      await tester.pumpAndSettle();

      expect(find.text('COMP 2'), findsOneWidget);
      expectPlaced(tester, const Rect.fromLTWH(0, 0, 393, 852));

      tester.view.physicalSize = const Size(852, 393);
      await tester.pumpAndSettle();

      expect(find.text('COMP 2'), findsOneWidget);
      expectPlaced(tester, const Rect.fromLTWH(0, 0, 852, 393));
    });
  });

  testWidgets('compact page: Back closes a work-area menu, nothing else', (
    tester,
  ) async {
    final calls = <String>[];

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call.method);

        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    // FX1 holds COMP 1: its effect menu lists COMP 2 among others.
    final container = await pumpPage(
      tester,
      size: const Size(852, 393),
      selectedEffects: const {1: 101},
      parameters: const {1: {}},
      overrides: [selectedModuleProvider.overrideWith((_) => 1)],
    );

    await tester.tap(
      find.descendant(
        of: find.byType(SonicDropdown<int>),
        matching: find.text('COMP 1'),
      ),
    );
    await tester.pump();

    expect(find.text('COMP 2'), findsOneWidget);

    await simulateSystemBack(tester);
    await tester.pump();

    expect(find.text('COMP 2'), findsNothing);
    expect(container.read(presetDrawerOpenProvider), isFalse);
    expect(calls, isNot(contains('SystemNavigator.pop'))); // the app stays
  });
}

final _trigger = find.widgetWithText(SonicDropdown<int>, 'COMP 1').first;
