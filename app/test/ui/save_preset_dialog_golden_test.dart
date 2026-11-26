import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/main.dart' show SonicMasterApp;
import 'package:sonicmaster/model/preset_ref.dart';
import 'package:sonicmaster/ui/preset_browser_page.dart';
import 'package:sonicmaster/ui/save_preset_dialog.dart';

import '../support/page_harness.dart';

/// The save dialog over the main screen at 1180x820 (the prototype's frame).
void main() {
  const names = [
    'Clean',
    'CLNGilmour',
    'Lead 800',
    'Tropicana',
    'Djent Bass',
    'Dotted08',
    'DodgeBlues',
    'Queen',
    'JMLeadTone',
    'AcousticSD',
    'Slap Bass',
    'Space Bass',
    'MB-Thall-C',
    'UniDirtDLY',
  ];

  Future<void> open(WidgetTester tester) async {
    // The dialog's prototype faces (Oswald is loaded by pumpPage).
    for (final (family, file) in const [
      ('Inter', 'Inter.ttf'),
      ('JetBrains Mono', 'JetBrainsMono.ttf'),
      ('Space Grotesk', 'SpaceGrotesk.ttf'),
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$file'))).load();
    }
    await pumpPage(
      tester,
      size: const Size(1180, 820),
      current: const PresetRef(.user, 4),
      names: {
        for (var n = 1; n <= 50; n++)
          PresetRef(.user, n): n <= names.length ? names[n - 1] : 'User $n',
      },
    );
    unawaited(
      showSavePresetDialog(tester.element(find.byType(PresetBrowserPage))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('save dialog, closed', (tester) async {
    await open(tester);

    await expectLater(
      find.byType(SonicMasterApp),
      matchesGoldenFile('goldens/save_preset_dialog_1180x820.png'),
    );
  });

  testWidgets('save dialog, slot list open', (tester) async {
    await open(tester);
    await tester.tap(
      find
          .descendant(
            of: find.byType(SavePresetDialog),
            matching: find.text('Tropicana'),
          )
          .first,
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SonicMasterApp),
      matchesGoldenFile('goldens/save_preset_dialog_slots_1180x820.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
