import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/edit_providers.dart';
import 'package:sonicmaster/ui/module_editor.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';
import '../support/test_assets.dart';

/// Every effect of every module on the compact iPad portrait pages (820x1180
/// and 834x1194), stock firmware and CFW base: the piece, its value line and
/// the control row all sit inside the viewport (the editor never overflows
/// its width) with nothing thrown. The worst case is printed.
void main() {
  final assets = loadTestDataAssets();
  final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;
  var worstBottom = 0.0;
  var worstPageExtent = 0.0;

  tearDownAll(
    () => debugPrint(
      'compact fit: worst editor bottom $worstBottom, '
      'worst page scroll extent $worstPageExtent',
    ),
  );

  final byModule = <int, List<int>>{};

  for (final id in assets.effects.effects.keys) {
    byModule.putIfAbsent(id ~/ 100, () => []).add(id);
  }

  for (final size in const [Size(820, 1180), Size(834, 1194)]) {
    for (final isCfw in const [false, true]) {
      for (final MapEntry(key: moduleId, value: ids) in byModule.entries) {
        if (moduleId > 9) continue;

        testWidgets('${size.width.toInt()}x${size.height.toInt()} '
            '${isCfw ? 'CFW base' : 'stock'}: module $moduleId fits', (
          tester,
        ) async {
          for (final fxId in ids) {
            final c = await pumpPage(
              tester,
              size: size,
              state: loadedPresetState.copyWith(isCloneMode: moduleId == 9),
              selectedEffects: {...fullPresetEffects, moduleId: fxId},
              parameters: const {},
              overrides: [if (isCfw) cfwInfoProvider.overrideWith((_) => cfw)],
            );

            c.read(selectedModuleProvider.notifier).state = moduleId;
            await tester.pump();

            final why =
                '${isCfw ? 'CFW' : 'stock'}, module $moduleId, '
                'effect $fxId';
            final editor = find.byType(ModuleEditor);
            final viewport = Offset.zero & size;

            bool inside(Rect r) =>
                viewport.contains(r.topLeft) &&
                viewport.contains(r.bottomRight - const Offset(.01, .01));

            final piece = find.descendant(
              of: editor,
              matching: find.byType(GearPiece),
            );

            expect(piece, findsOneWidget, reason: why);
            expect(inside(tester.getRect(piece)), isTrue, reason: why);
            for (final line in tester.widgetList(
              find.byKey(const Key('piece-value')),
            )) {
              expect(
                inside(tester.getRect(find.byWidget(line))),
                isTrue,
                reason: why,
              );
            }

            final row = find.byKey(const ValueKey('control-row'));
            final rowRect = tester.getRect(row);

            expect(inside(rowRect), isTrue, reason: '$why: $rowRect');
            worstBottom = rowRect.bottom > worstBottom
                ? rowRect.bottom
                : worstBottom;
            for (final s in tester.stateList<ScrollableState>(
              find.ancestor(of: editor, matching: find.byType(Scrollable)),
            )) {
              if (s.position.axis == .vertical &&
                  s.position.maxScrollExtent > worstPageExtent) {
                worstPageExtent = s.position.maxScrollExtent;
              }
            }
            expect(tester.takeException(), isNull, reason: why);

            await tester.pumpWidget(const SizedBox.shrink());
          }
        });
      }
    }
  }
}
