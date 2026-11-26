import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonicmaster/main.dart';
import 'package:sonicmaster/state/palette_providers.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/theme/app_palettes.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

Future<ProviderContainer> _container(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [paletteStoreProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);

  return c;
}

void main() {
  tearDown(() => Palette.current = appPalettes.first);

  test('starts from the saved palette', () async {
    final c = await _container({'app_palette': 'p13'});

    expect(c.read(paletteIdProvider), 'p13');
    expect(Palette.current.id, 'p13');
  });

  test('an unknown saved id falls back to vintage', () async {
    final c = await _container({'app_palette': 'roxo'});

    expect(c.read(paletteIdProvider), 'vintage');
  });

  test('select saves and applies', () async {
    final c = await _container({});
    await c.read(paletteIdProvider.notifier).select('p4');

    expect(
      (await SharedPreferences.getInstance()).getString('app_palette'),
      'p4',
    );
    expect(Palette.current.id, 'p4');
  });

  testWidgets('switching keeps open dialogs', (tester) async {
    final c = await _container({});
    BuildContext? ctx;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: SonicMasterApp(
          home: Builder(
            builder: (context) {
              ctx = context;

              return const Text("x");
            },
          ),
        ),
      ),
    );
    showSonicDialog<void>(
      context: ctx!,
      builder: (_) => Text('hi', style: TextStyle(color: Palette.onSurface)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('hi')).style!.color,
      appPalettes.first.text,
    );

    await c.read(paletteIdProvider.notifier).select('p13');
    await tester.pumpAndSettle();

    expect(find.text('hi'), findsOneWidget);
    expect(
      DefaultTextStyle.of(tester.element(find.text('hi'))).style.color,
      paletteById('p13').text,
    );
    expect(
      tester.widget<Text>(find.text('hi')).style!.color,
      paletteById('p13').text,
    );
  });
}
