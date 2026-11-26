import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/state/edit_providers.dart';
import 'package:sonicmaster/ui/preset_browser_page.dart';

import '../support/page_harness.dart';

/// The compact iPad portrait page with an amp selected: the pieces on the
/// chain cards and the editor's piece. Regenerate only for an intended change.
void main() {
  testWidgets('compact tablet layout, amp selected', (tester) async {
    final c = await pumpPage(
      tester,
      size: const Size(820, 1180),
      selectedEffects: fullPresetEffects,
    );

    c.read(selectedModuleProvider.notifier).state = 3;
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PresetBrowserPage),
      matchesGoldenFile('goldens/page_compact_820x1180_amp.png'),
    );
  });
}
