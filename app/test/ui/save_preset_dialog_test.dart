import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/data_assets.dart';
import 'package:sonicmaster/model/preset_ref.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/names_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/ui/save_preset_dialog.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

import '../support/sonic_host.dart';
import '../support/view_helpers.dart';

/// Pumped in a bare [WidgetsApp] — the app is Material-free, so the dialog must
/// open without a Material ancestor or MaterialLocalizations.
void main() {
  // Opens SavePresetDialog exactly as the preset browser does, over a device
  // sitting on [current] with [names] already decoded.
  Future<void> open(
    WidgetTester tester, {
    PresetRef? current,
    Map<PresetRef, String> names = const {},
  }) async {
    late BuildContext ctx;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentPresetProvider.overrideWith((_) => current),
          presetNamesProvider.overrideWith((_) => names),
        ],
        child: WidgetsApp(
          color: const Color(0xFF000000),
          debugShowCheckedModeBanner: false,
          pageRouteBuilder:
              <T>(RouteSettings settings, WidgetBuilder builder) =>
                  PageRouteBuilder<T>(
                    settings: settings,
                    pageBuilder: (context, _, _) => builder(context),
                  ),
          home: Builder(
            builder: (context) {
              ctx = context;

              return const SizedBox();
            },
          ),
        ),
      ),
    );

    showSavePresetDialog(ctx); // the same entry point the preset browser uses
    await tester.pumpAndSettle();

    expect(find.text('Save preset'), findsOneWidget);
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  testWidgets('prefills the current preset\'s decoded name', (tester) async {
    const current = PresetRef(.user, 5);

    await open(tester, current: current, names: {current: 'MyPatch'});

    expect(fieldText(tester), 'MyPatch');
    expect(find.text('P05'), findsOneWidget); // slot defaults to the loaded one
  });

  testWidgets('prefills a Factory preset\'s name, not its label', (
    tester,
  ) async {
    const current = PresetRef(.factory, 3);

    await open(tester, current: current, names: {current: 'Crunch'});

    expect(fieldText(tester), 'Crunch');
    expect(find.text('P01'), findsOneWidget); // no User slot loaded -> P01
  });

  testWidgets('stays empty when the name dump has not been decoded', (
    tester,
  ) async {
    await open(tester, current: const PresetRef(.user, 5));

    expect(fieldText(tester), '');
  });

  testWidgets('outside-tap dismisses the dialog', (tester) async {
    const current = PresetRef(.user, 5);

    await open(tester, current: current, names: {current: 'MyPatch'});

    await tester.tapAt(const Offset(5, 5)); // barrier
    await tester.pumpAndSettle();

    expect(find.text('Save preset'), findsNothing);
  });

  group('slot menu', () {
    const current = PresetRef(.user, 5);
    final names = {
      for (var n = 1; n <= 50; n++)
        PresetRef(.user, n): 'Name${n.toString().padLeft(2, '0')}',
    };

    Future<void> openMenu(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1180, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, current: current, names: names);
      await tester.tap(find.text('P05'));
      await tester.pumpAndSettle();
    }

    testWidgets('the slot menu lists all user slots in two columns without '
        'scrolling', (tester) async {
      await openMenu(tester);

      for (var n = 1; n <= 50; n++) {
        final id = 'P${n.toString().padLeft(2, '0')}';
        // P05 also shows on the closed selector.
        expect(find.text(id), n == 5 ? findsNWidgets(2) : findsOneWidget);
        expect(
          tester.getRect(find.text(id).last).bottom,
          lessThanOrEqualTo(820),
        );
      }
      expect(
        tester.getTopLeft(find.text('P26').last).dx,
        greaterThan(tester.getTopLeft(find.text('P01')).dx + 100),
      );
      expect(
        tester.getTopLeft(find.text('P26').last).dy,
        tester.getTopLeft(find.text('P01')).dy,
      );
    });

    testWidgets('picking a slot fills the name', (tester) async {
      await openMenu(tester);
      await tester.tap(find.text('P12'));
      await tester.pumpAndSettle();

      expect(fieldText(tester), 'Name12');
      expect(find.text('P12'), findsOneWidget);
    });

    testWidgets('name limited to 10 chars', (tester) async {
      await open(tester, current: current, names: names);
      await tester.enterText(find.byType(EditableText), '12345678901234');

      expect(fieldText(tester), '1234567890');
    });
  });

  group('back and Escape with the slot list open', () {
    const current = PresetRef(.user, 5);

    Future<void> openSave(
      WidgetTester tester, {
      required Size size,
      double keyboard = 0,
    }) async {
      final context = await pumpSonicHost(
        tester,
        size: size,
        keyboard: keyboard,
        overrides: [
          currentPresetProvider.overrideWith((_) => current),
          presetNamesProvider.overrideWith((_) => {current: 'MyPatch'}),
          dataAssetsProvider.overrideWith(
            (_) => Completer<DataAssets>().future,
          ),
        ],
      );

      unawaited(showSavePresetDialog(context));
      await tester.pumpAndSettle();
      await tester.tap(find.text('P05'));
      await tester.pumpAndSettle();
    }

    testWidgets('compact: Back closes the menu, then the dialog', (
      tester,
    ) async {
      await openSave(tester, size: const Size(852, 393));
      await simulateSystemBack(tester);
      await tester.pumpAndSettle();

      expect(find.text('P06'), findsNothing); // the menu closed
      expect(find.text('Save preset'), findsOneWidget); // the dialog stayed

      await simulateSystemBack(tester);
      await tester.pumpAndSettle();

      expect(find.text('Save preset'), findsNothing);
    });

    testWidgets('regular: Escape closes the menu, then the dialog', (
      tester,
    ) async {
      await openSave(tester, size: const Size(1280, 800));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('P06'), findsNothing);
      expect(find.text('Save preset'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Save preset'), findsNothing);
    });

    testWidgets('iPad portrait (compact): rows are at least 32px, tappable, '
        'nothing overflows', (tester) async {
      final names = {
        for (var n = 1; n <= 50; n++)
          PresetRef(.user, n): 'Name${n.toString().padLeft(2, '0')}',
      };
      final context = await pumpSonicHost(
        tester,
        size: const Size(820, 1180),
        overrides: [
          currentPresetProvider.overrideWith((_) => current),
          presetNamesProvider.overrideWith((_) => names),
          dataAssetsProvider.overrideWith(
            (_) => Completer<DataAssets>().future,
          ),
        ],
      );

      unawaited(showSavePresetDialog(context));
      await tester.pumpAndSettle();
      await tester.tap(find.text('P05'));
      await tester.pumpAndSettle();

      for (var n = 1; n <= 50; n++) {
        final id = 'P${n.toString().padLeft(2, '0')}';
        final row = find
            .ancestor(of: find.text(id).last, matching: find.byType(Container))
            .first;

        expect(
          tester.getSize(row).height,
          greaterThanOrEqualTo(32),
          reason: id,
        );
      }

      await tester.tap(find.text('P30'));
      await tester.pumpAndSettle();

      expect(fieldText(tester), 'Name30');
      expect(tester.takeException(), isNull);
    });
  });

  group('Done / Enter in the real app shell', () {
    // Opens the dialog in SonicMasterApp at [size] (compact below 960x600)
    // with a soft keyboard [keyboard] px tall. The device tables never load,
    // so a save gives up at once and pops: a closed dialog means "saved".
    Future<void> openInShell(
      WidgetTester tester, {
      required Size size,
      double keyboard = 0,
    }) async {
      const current = PresetRef(.user, 5);

      final context = await pumpSonicHost(
        tester,
        size: size,
        keyboard: keyboard,
        overrides: [
          currentPresetProvider.overrideWith((_) => current),
          presetNamesProvider.overrideWith((_) => {current: 'MyPatch'}),
          dataAssetsProvider.overrideWith(
            (_) => Completer<DataAssets>().future,
          ),
        ],
      );

      unawaited(showSavePresetDialog(context));
      await tester.pumpAndSettle();
    }

    testWidgets('compact, keyboard up: Done closes it and saves nothing', (
      tester,
    ) async {
      await openInShell(tester, size: const Size(852, 393), keyboard: 180);
      await tester.testTextInput.receiveAction(.done);
      await tester.pump();

      expect(find.text('Save preset'), findsOneWidget); // still open
      expect(tester.testTextInput.isVisible, isFalse); // keyboard dismissed

      // The browser drops the inset once the keyboard is gone: the Slot
      // picker is in view and Save is still one tap away.
      await setKeyboard(tester, 0);
      await tester.pumpAndSettle();

      expectWithin(
        tester.getRect(find.text('P05')),
        const Rect.fromLTWH(0, 0, 852, 393),
        'the Slot picker',
      );
      expect(
        tester
            .widget<SonicButton>(find.widgetWithText(SonicButton, 'Save'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('compact, no soft keyboard: Enter still saves', (tester) async {
      // A phone or tablet with a hardware keyboard: nothing to dismiss.
      await openInShell(tester, size: const Size(852, 393));
      await tester.testTextInput.receiveAction(.done);
      await tester.pumpAndSettle();

      expect(find.text('Save preset'), findsNothing);
    });

    testWidgets('regular: Done saves, keyboard or not (unchanged)', (
      tester,
    ) async {
      await openInShell(tester, size: const Size(1280, 800), keyboard: 300);
      await tester.testTextInput.receiveAction(.done);
      await tester.pumpAndSettle();

      expect(find.text('Save preset'), findsNothing);
    });
  });
}
