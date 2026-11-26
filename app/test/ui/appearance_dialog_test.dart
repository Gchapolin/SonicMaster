import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/main.dart';
import 'package:sonicmaster/state/palette_providers.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/theme/app_palettes.dart';
import 'package:sonicmaster/ui/appearance_dialog.dart';
import 'package:sonicmaster/ui/preset_browser_page.dart';

import '../support/page_harness.dart';
import '../support/sonic_host.dart';
import '../support/text_fit.dart';

Future<ProviderContainer> _open(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final context = await pumpSonicHost(
    tester,
    size: const Size(1180, 820),
    overrides: [paletteStoreProvider.overrideWithValue(prefs)],
  );
  unawaited(showAppearanceDialog(context));
  await tester.pumpAndSettle();

  return ProviderScope.containerOf(context);
}

void main() {
  setUp(() => appLang = Lang.pt);
  tearDown(() {
    Palette.current = appPalettes.first;
    appLang = Lang.en;
  });

  testWidgets('shows the 18 palettes with their five swatches in three '
      'columns', (tester) async {
    await _open(tester);

    expect(find.text('Aparência'), findsOneWidget);
    expect(find.text('COR DO APP'), findsOneWidget);
    expect(find.text('Fechar'), findsOneWidget);
    expect(find.byKey(const ValueKey('swatch')), findsNWidgets(18 * 5));

    final first = tester.getTopLeft(find.text(appPalettes[0].name).first).dx;
    final second = tester.getTopLeft(find.text(appPalettes[1].name).first).dx;
    final third = tester.getTopLeft(find.text(appPalettes[2].name).first).dx;
    final fourth = tester.getTopLeft(find.text(appPalettes[3].name).first).dx;

    expect(second, greaterThan(first));
    expect(third, greaterThan(second));
    expect(fourth, first);
  });

  testWidgets('every palette name is shown in full inside its chip', (
    tester,
  ) async {
    await _open(tester);

    for (final p in appPalettes) {
      expectNoTruncatedText(tester, find.byKey(ValueKey('chip-${p.id}')));
      final text = tester.getRect(find.text(p.name).first);
      final chip = tester.getRect(
        find
            .ancestor(
              of: find.text(p.name).first,
              matching: find.byType(Container),
            )
            .first,
      );

      expect(
        text.right,
        lessThanOrEqualTo(chip.right - 12 + 0.5),
        reason: p.name,
      );
      expect(text.height, greaterThanOrEqualTo(11), reason: p.name);
    }
    // The two look-alikes are told apart by their last word.
    expect(find.text('Vintage Neutral - Muted 2'), findsOneWidget);
  });

  testWidgets('picking a palette recolours the app at once and saves it', (
    tester,
  ) async {
    final c = await _open(tester);
    final p = appPalettes[4];
    await tester.tap(find.text(p.name));
    await tester.pumpAndSettle();

    expect(c.read(paletteIdProvider), p.id);
    expect(Palette.current.id, p.id);
    expect((await SharedPreferences.getInstance()).getString(paletteKey), p.id);
  });

  testWidgets('the footer names the chosen palette', (tester) async {
    await _open(tester);
    final p = appPalettes[3];
    await tester.tap(find.text(p.name));
    await tester.pumpAndSettle();

    // chip label plus footer
    expect(find.text(p.name), findsNWidgets(2));
  });

  Future<BuildContext> openOverPage(WidgetTester tester) async {
    await pumpPage(tester, size: const Size(1180, 820), isConnected: false);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(PresetBrowserPage));
    unawaited(showAppearanceDialog(context));
    await tester.pumpAndSettle();

    return context;
  }

  Set<Color> pageColours(WidgetTester tester) => {
    for (final w in tester.widgetList<ColoredBox>(
      find.descendant(
        of: find.byType(PresetBrowserPage),
        matching: find.byType(ColoredBox),
      ),
    ))
      w.color,
  };

  testWidgets('tapping a palette recolours the main screen behind the dialog', (
    tester,
  ) async {
    await openOverPage(tester);
    final before = pageColours(tester);
    await tester.tap(find.text(appPalettes[5].name));
    await tester.pumpAndSettle();

    expect(pageColours(tester), isNot(before));
  });

  testWidgets('golden: the dialog over the main screen', (tester) async {
    await openOverPage(tester);

    await expectLater(
      find.byType(SonicMasterApp),
      matchesGoldenFile('goldens/appearance_dialog_1180x820.png'),
    );
  });
}
