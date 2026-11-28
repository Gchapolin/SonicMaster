import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/shell_text.dart';
import 'package:sonicmaster/ui/chain_view.dart';

import '../support/page_harness.dart';

/// Right after a connect the app knows the sound playing on the pedal (its
/// edit buffer) but not which slot it is: the page shows the board anyway.
void main() {
  testWidgets('connected with the pedal sound but no preset picked', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1180, 820), current: null);

    expect(find.byType(ChainView), findsOneWidget);
    expect(find.text(ShellText.current.noPresetSelected), findsNothing);
  });
}
