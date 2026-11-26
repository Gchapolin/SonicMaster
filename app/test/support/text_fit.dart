import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fails when any text under [scope] was cut to its max lines or by an
/// ellipsis (what a too-narrow field does to its value).
void expectNoTruncatedText(WidgetTester tester, Finder scope) {
  final texts = find.descendant(of: scope, matching: find.byType(RichText));
  expect(texts, findsWidgets);

  for (final e in texts.evaluate()) {
    final p = e.renderObject! as RenderParagraph;

    expect(
      p.didExceedMaxLines,
      false,
      reason: 'truncated: "${p.text.toPlainText()}"',
    );
  }
}

/// [expectNoTruncatedText] for every dropdown (of any value type) under [scope].
void expectDropdownsNotTruncated(WidgetTester tester, Finder scope) {
  final dropdowns = find.descendant(
    of: scope,
    matching: find.byWidgetPredicate(
      (w) => w.runtimeType.toString().startsWith('SonicDropdown'),
    ),
  );
  expect(dropdowns, findsWidgets);

  for (final d in dropdowns.evaluate()) {
    expectNoTruncatedText(tester, find.byWidget(d.widget));
  }
}
