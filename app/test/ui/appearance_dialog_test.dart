import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/state/palette_providers.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/theme/app_palettes.dart';
import 'package:sonicmaster/ui/appearance_dialog.dart';

import '../support/sonic_host.dart';

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

void unawaited(Future<void> f) {}

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
}
