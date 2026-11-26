import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/state/edit_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/ui/knob_control.dart';

import '../support/page_harness.dart';
import '../support/silent_transport.dart';
import '../support/view_helpers.dart';

/// Cabs and wahs draw no knobs on their piece: their knob params must be
/// reachable as knobs in the block panel (regular) or the control row
/// (compact tablet) instead.
void main() {
  Finder knob(String label) =>
      find.byWidgetPredicate((w) => w is KnobControl && w.label == label);

  final cases = <(String, int, int, String, int)>[
    // (name, module, effect, knob label, algId)
    ('IR cab Vol', 4, 401, 'Vol', 0),
    ('C-Wah Q', 1, 122, 'Q', 1),
    ('C-Wah Vol', 1, 122, 'Vol', 2),
  ];

  for (final size in const [Size(1180, 820), Size(820, 1180)]) {
    for (final (name, module, fx, label, algId) in cases) {
      testWidgets('$name is draggable at ${size.width.toInt()}x'
          '${size.height.toInt()}', (tester) async {
        final c = await pumpPage(
          tester,
          size: size,
          selectedEffects: {module: fx},
          parameters: {
            module: {algId: 50},
          },
        );

        c.read(selectedModuleProvider.notifier).state = module;
        await tester.pumpAndSettle();
        expectNoOverflow(tester);

        final target = knob(label);

        expect(target, findsOneWidget);

        final before = c.read(currentParametersProvider)[module]![algId];

        await tester.ensureVisible(target);
        await tester.drag(target, const Offset(0, -60));
        await tester.pump();

        expect(
          c.read(currentParametersProvider)[module]![algId],
          isNot(before),
        );

        await pumpPastAckTimeout(tester);
      });
    }
  }
}
