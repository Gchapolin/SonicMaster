import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_lookup.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
import 'package:sonicmaster/gear/pedal_piece.dart';
import 'package:sonicmaster/model/decoded_preset_state.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/ui/chain_view.dart';
import 'package:sonicmaster/ui/led_button.dart';
import 'package:sonicmaster/ui/sonic_metrics.dart';

import '../support/page_harness.dart';
import '../support/test_assets.dart';

final _assets = loadTestDataAssets();

const _order = ['NR', 'FX1', 'DRV', 'AMP', 'IR', 'EQ', 'FX2', 'DLY', 'RVB'];

/// One model per physical module (0=NR … 8=RVB).
const _models = [
  'Gate',
  'COMP 1',
  'Scream',
  'Brit 800',
  'BritGN 4x12',
  'GT EQ 1',
  'A-Chorus',
  'Pure',
  'Room',
];

int _idOf(String model) => _assets.effects.effects.entries
    .firstWhere((e) => e.value.name == model)
    .key;

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('compact: ChainConnector shows a chevron icon', (tester) async {
    await tester.pumpWidget(
      host(
        const SonicMetricsScope(
          metrics: SonicMetrics.compact,
          child: ChainConnector(),
        ),
      ),
    );
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('regular: ChainConnector is a plain 12-px gap', (tester) async {
    await tester.pumpWidget(host(const ChainConnector()));
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(tester.getSize(find.byType(ChainConnector)).width, 12);
  });

  testWidgets('AmpBlockBorder wraps its child without error', (tester) async {
    await tester.pumpWidget(host(const AmpBlockBorder(child: Text('block'))));
    expect(find.text('block'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> pumpChain(
    WidgetTester tester, {
    Map<String, bool>? states,
    Map<int, int>? selected,
  }) async {
    tester.view.physicalSize = const Size(1600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = DecodedPresetState(
      isCloneMode: false,
      presetVolume: 50,
      presetBpm: 120,
      moduleStates: states ?? {for (final m in _order) m: true},
      chainOrder: _order,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataAssetsProvider.overrideWith((_) => _assets),
          currentPresetStateProvider.overrideWith((_) => state),
          currentSelectedEffectsProvider.overrideWith(
            (_) =>
                selected ?? {for (final (i, m) in _models.indexed) i: _idOf(m)},
          ),
        ],
        child: host(const ChainView()),
      ),
    );
    await tester.pump();
  }

  testWidgets("each module shows its model's piece", (tester) async {
    await pumpChain(tester);

    final pieces = tester.widgetList<GearPiece>(find.byType(GearPiece));

    expect(pieces.map((p) => p.model), _models);
    expect(pieces.map((p) => p.kind), [
      for (var i = 0; i < 9; i++) gearKindForModule(i),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an off module draws its piece unlit', (tester) async {
    await pumpChain(tester, states: {for (final m in _order) m: m != 'DRV'});

    final lit = {
      for (final p in tester.widgetList<GearPiece>(find.byType(GearPiece)))
        p.model: p.lit,
    };

    expect(lit['Scream'], isFalse);
    expect(lit['Gate'], isTrue);
    expect(lit['Brit 800'], isTrue);
  });

  testWidgets('no preset shows empty slots', (tester) async {
    await pumpChain(tester, selected: const {});

    expect(find.byType(GearPiece), findsNothing);
    expect(find.byKey(const ValueKey('empty-slot')), findsNWidgets(9));
    for (final m in _order) {
      expect(find.text(m), findsOneWidget);
    }
  });

  // A rack (250x74) in the pedal's 66x114 box drew a 66x19 sliver: wide
  // units get the amp's 118x76 slot and fill most of its width.
  for (final model in const ['Analog', 'Studio EQ', 'Echo']) {
    testWidgets('a wide $model unit fills its slot', (tester) async {
      await tester.pumpWidget(
        host(
          ModuleCard(
            iconId: model == 'Studio EQ' ? 5 : 7,
            name: 'DLY',
            model: model,
            isOn: true,
            isSelected: false,
            isEnabled: true,
          ),
        ),
      );

      final slot = tester.getSize(find.byType(GearPiece));
      final piece = tester.getRect(
        find.descendant(
          of: find.byType(GearPiece),
          matching: find.byType(PedalPiece),
        ),
      );

      expect(slot.width, 118);
      expect(piece.width, greaterThanOrEqualTo(0.8 * slot.width));
      expect(piece.height, greaterThanOrEqualTo(30));
    });
  }

  testWidgets('a selected unit is filled with card and outlined in primary', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const ModuleCard(
          iconId: 3,
          name: 'AMP',
          model: 'Brit 800',
          isOn: true,
          isSelected: true,
          isEnabled: true,
        ),
      ),
    );

    final box = tester.widget<Container>(find.byKey(const Key('regular-unit')));
    final deco = box.decoration! as BoxDecoration;

    expect(deco.color, Palette.surfaceContainerHigh);
    expect((deco.border! as Border).top.color, Palette.primary);
    expect(tester.widget<Text>(find.text('AMP')).style?.color, Palette.primary);
  });

  // The panel's "Block on" (BlockPanel) is the regular on/off: the unit is
  // the piece and its tag (prototype N_Principal), 6-px padding all round.
  testWidgets('a regular unit has no LED', (tester) async {
    await tester.pumpWidget(
      host(
        const ModuleCard(
          iconId: 0,
          name: 'NR',
          model: 'Gate',
          isOn: true,
          isSelected: false,
          isEnabled: true,
        ),
      ),
    );

    expect(find.byType(LedButton), findsNothing);
    expect(
      tester.widget<Container>(find.byKey(const Key('regular-unit'))).padding,
      const EdgeInsets.all(6),
    );
  });

  // The prototype pedalboard is one row of nine units: at the iPad (A16) and
  // iPad Pro 11 landscape widths and at 1280 every unit top is the same.
  for (final size in const [
    Size(1180, 820),
    Size(1194, 834),
    Size(1280, 800),
  ]) {
    testWidgets('regular ${size.width.toInt()}x${size.height.toInt()}: '
        'the pedalboard is one row', (tester) async {
      await pumpPage(tester, size: size, selectedEffects: fullPresetEffects);

      final tops = find
          .byType(ModuleCard)
          .evaluate()
          .map((e) => tester.getTopLeft(find.byWidget(e.widget)).dy)
          .toList();

      expect(tops, hasLength(9));
      expect(tops, everyElement(closeTo(tops.first, 0.01)));
      expect(find.byType(AmpBlockBorder), findsOneWidget);
    });
  }
}
