import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/state/edit_providers.dart';

import '../support/page_harness.dart';

/// A band title in the open menu (knob labels can share its text: BASS; the
/// header's band chip shares its style).
Finder _title(String text) => find.byElementPredicate((e) {
  final w = e.widget;

  if (w is! Text || w.data != text || w.style?.fontSize != 11) return false;

  var isChip = false;

  e.visitAncestorElements((a) {
    isChip = a.widget.key == const Key('amp-band');

    return !isChip;
  });

  return !isChip;
});

void main() {
  tearDown(() => appLang = Lang.en);

  Future<void> openAmpMenu(WidgetTester tester) async {
    await pumpPage(
      tester,
      size: const Size(1180, 820),
      selectedEffects: const {3: 308}, // Brit 800
      parameters: const {},
      overrides: [selectedModuleProvider.overrideWith((_) => 3)],
    );
    await tester.tap(find.text('Brit 800').last);
    await tester.pumpAndSettle();
  }

  testWidgets('the amp list runs clean to high gain under band titles', (
    tester,
  ) async {
    await openAmpMenu(tester);

    for (final title in [
      'CLEAN',
      'CRUNCH',
      'ROCK / LEAD',
      'HIGH GAIN',
      'BASS',
    ]) {
      expect(_title(title), findsOneWidget, reason: title);
    }

    double y(String text) => tester.getTopLeft(find.text(text).last).dy;

    expect(y('CLEAN'), lessThan(y('Jazz 120')));
    expect(y('Jazz 120'), lessThan(y('Voks 30N')));
    expect(y('CRUNCH'), lessThan(y('Voks 30N')));
    expect(y('Halen 51'), lessThan(y('Dizzy VH')));
    expect(y('HIGH GAIN'), lessThan(y('Sol 100 LD')));
    expect(tester.getTopLeft(_title('BASS')).dy, greaterThan(y('Dizzy VH+')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a band title is not an option', (tester) async {
    await openAmpMenu(tester);
    await tester.tap(find.text('CLEAN'));
    await tester.pumpAndSettle();

    // Still open, nothing chosen: the band title is still there.
    expect(find.text('CLEAN'), findsOneWidget);
    expect(find.text('Jazz 120'), findsOneWidget);
  });

  testWidgets('band titles in Portuguese', (tester) async {
    appLang = Lang.pt;
    await openAmpMenu(tester);

    expect(find.text('CRUNCH'), findsOneWidget);
    expect(find.text('HIGH GAIN'), findsOneWidget);
    expect(_title('BAIXO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu is wide enough for its longest name', (tester) async {
    await openAmpMenu(tester);

    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('Calif Star CL'),
    );

    expect(paragraph.didExceedMaxLines, isFalse);
  });
}
