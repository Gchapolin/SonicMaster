import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
import 'package:sonicmaster/gear/paint/knob_painter.dart';
import 'package:sonicmaster/state/edit_providers.dart';
import 'package:sonicmaster/ui/chain_view.dart';
import 'package:sonicmaster/ui/knob_control.dart';
import 'package:sonicmaster/ui/module_editor.dart';
import 'package:sonicmaster/ui/preset_rail.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';
import 'package:sonicmaster/ui/sonic_metrics.dart';

import '../support/page_harness.dart';
import '../support/view_helpers.dart';

/// The work area of the whole page per density: regular keeps today's
/// numbers; compact fits a phone (one chain row, the first knob row above the
/// fold at 360 px and up, nothing overflowing at any phone size).
///
/// Fake time: zero-length pumps plus two 50-ms ones, far below the connected
/// heartbeat's 2 s; pages with the DLY tap tempo are unmounted at the end (its
/// beat timer).
void main() {
  /// The page with [moduleId]'s editor open on [fxId].
  Future<ProviderContainer> pumpEditorPage(
    WidgetTester tester, {
    required Size size,
    int moduleId = 0,
    int fxId = 1,
    Map<int, num> params = const {},
    bool isCloneMode = false,
  }) => pumpPage(
    tester,
    size: size,
    state: loadedPresetState.copyWith(isCloneMode: isCloneMode),
    selectedEffects: {moduleId: fxId},
    parameters: {moduleId: params},
    overrides: [selectedModuleProvider.overrideWith((_) => moduleId)],
  );

  Finder inEditor(Finder finder) =>
      find.descendant(of: find.byType(ModuleEditor), matching: finder);

  // The editor's plate: the SonicSurface right around ModuleEditor.
  Finder editorSurface() => find
      .ancestor(
        of: find.byType(ModuleEditor),
        matching: find.byType(SonicSurface),
      )
      .first;

  double gap(WidgetTester tester) =>
      tester.getRect(editorSurface()).top -
      tester.getBottomLeft(find.byType(ChainView)).dy;

  Iterable<double> cardWidths() =>
      find.byType(ModuleCard).evaluate().map((element) => element.size!.width);

  // How far apart the chain cards' top edges are: ~0 on one row (the amp
  // block's cards sit inside its 4-px padding), ~110 once a second row starts.
  double cardTopSpread(WidgetTester tester) {
    final tops = find
        .byType(ModuleCard)
        .evaluate()
        .map((element) => tester.getTopLeft(find.byWidget(element.widget)).dy)
        .toList();

    return tops.reduce(math.max) - tops.reduce(math.min);
  }

  String label(Size size) => '${size.width.toInt()}x${size.height.toInt()}';

  const heavyEditors = [
    ('AMP Brit 50JP', 3, 307, <int, num>{}, false),
    ('Clone User Profile 1', 9, 901, <int, num>{}, true),
    ('DLY Sweep + tap tempo', 7, 708, <int, num>{1: 500, 6: 0}, false),
  ];

  // Regular (prototype N_Principal): the 210-px pedalboard band edge to edge
  // beside the rail, the editor 16 under it filling the rest.
  group('regular: the band and the editor under it', () {
    for (final size in const [Size(1280, 800), Size(960, 640)]) {
      testWidgets('${label(size)}: band, editor, the 3:2 piece', (
        tester,
      ) async {
        await pumpPage(tester, size: size);

        final band = tester.getRect(find.byKey(const Key('pedalboard-band')));

        expect(band.left, railWidth);
        expect(band.height, 210);
        expect(tester.getRect(editorSurface()).top, band.bottom);
        expect(tester.getSize(editorSurface()).width, band.width);
        // The knobs are on the selected module's piece, 3:2 kept.
        final piece = tester.getRect(inEditor(find.byType(GearPiece))).size;

        expect(piece.aspectRatio, closeTo(1.5, 0.01));
        expect(cardWidths(), regularUnitWidths);
      });

      testWidgets('${label(size)}: an empty editor fills the rest', (
        tester,
      ) async {
        await pumpPage(tester, size: size, selectedEffects: const {});

        final band = tester.getRect(find.byKey(const Key('pedalboard-band')));

        expect(tester.getRect(editorSurface()).bottom, size.height);
        expect(tester.getRect(editorSurface()).top, band.bottom);
      });
    }
  });

  // An iPad in landscape: under a two-row chain the effect's first knob row
  // is on screen without scrolling.
  testWidgets('1180x820: the effect knobs are on screen under the chain', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1180, 820));

    expect(
      tester
          .getRect(
            inEditor(
              find.byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is GearKnobPainter,
              ),
            ).first,
          )
          .bottom,
      lessThanOrEqualTo(820),
    );
    expectNoOverflow(tester);
  });

  group('compact', () {
    testWidgets('852x393: padding 8, gap 8, 72 dials, one row', (tester) async {
      // A two-row editor: the content is taller than the work area, so it is
      // top-aligned and the chain starts right under the work padding. NR is
      // on FS1; its badge overhangs the card corner and must stay inside the
      // work area's scroll viewport, which starts under the 48-px title bar.
      await pumpPage(
        tester,
        size: const Size(852, 393),
        state: loadedPresetState.withFootswitchMasks(fs1Mask: 1, fs2Mask: 0),
        selectedEffects: const {3: 307},
        parameters: const {3: {}},
        overrides: [selectedModuleProvider.overrideWith((_) => 3)],
      );

      const metrics = SonicMetrics.compact;

      final chain = tester.getTopLeft(find.byType(ChainView));
      final badge = find
          .ancestor(
            of: find.descendant(
              of: find.byType(ChainView),
              matching: find.text('FS1'),
            ),
            matching: find.byType(Container),
          )
          .first;

      expect(chain, Offset(8, metrics.topBarHeight + 8));
      expect(gap(tester), 8);
      expect(
        tester.getSize(inEditor(find.byKey(const Key('knob'))).first),
        const Size.square(72),
      );
      expect(cardWidths(), everyElement(77));
      expect(cardTopSpread(tester), lessThanOrEqualTo(4));
      expect(
        tester.getRect(badge).top,
        greaterThanOrEqualTo(metrics.topBarHeight),
      );
    });

    testWidgets('852x393: an empty editor keeps the 142 minimum', (
      tester,
    ) async {
      await pumpPage(
        tester,
        size: const Size(852, 393),
        selectedEffects: const {},
      );

      expect(tester.getSize(editorSurface()).height, 142);
    });

    // The D5 target: at 360 px and up (fullscreen / installed app) the first
    // row of a two- or three-row editor is on screen without scrolling: bar 48
    // + padding 8 + chain row 111 (the amp block holding the selected card) +
    // gap 8 + border 1 + header 40 + one 123-px cell = 339.
    for (final size in const [Size(852, 393), Size(780, 360), Size(640, 360)]) {
      testWidgets('${label(size)}: the first knob row is fully on screen', (
        tester,
      ) async {
        await pumpEditorPage(tester, size: size, moduleId: 3, fxId: 307);

        const metrics = SonicMetrics.compact;

        final knob = tester.getRect(inEditor(find.byType(KnobControl)).first);
        final chain = tester.getSize(find.byType(ChainView)).height;

        expect(
          knob.bottom,
          metrics.topBarHeight +
              metrics.workPadding +
              chain +
              metrics.chainPanelsGap +
              1 + // the editor plate's border
              metrics.editorHeaderPadding.vertical +
              metrics.editorControlHeight +
              knob.height,
        );
        expect(knob.bottom, lessThanOrEqualTo(size.height));
      });
    }

    for (final size in const [Size(740, 280), Size(640, 300)]) {
      testWidgets(
        '${label(size)}: a browser tab height scrolls, nothing overflows',
        (tester) async {
          await pumpEditorPage(tester, size: size, moduleId: 3, fxId: 307);

          expectNoOverflow(tester);

          final position = tester
              .state<ScrollableState>(
                find
                    .ancestor(
                      of: find.byType(ChainView),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              )
              .position;

          expect(position.maxScrollExtent, greaterThan(0));

          position.jumpTo(position.maxScrollExtent);
          await tester.pump();

          expect(
            tester.getRect(editorSurface()).bottom,
            lessThanOrEqualTo(size.height),
          );
        },
      );
    }

    for (final size in const [Size(852, 393), Size(640, 360)]) {
      for (final (name, moduleId, fxId, params, isCloneMode) in heavyEditors) {
        testWidgets('${label(size)}: $name does not overflow', (tester) async {
          await pumpEditorPage(
            tester,
            size: size,
            moduleId: moduleId,
            fxId: fxId,
            params: params,
            isCloneMode: isCloneMode,
          );

          expectNoOverflow(tester);
          expect(inEditor(find.byType(KnobControl)), findsWidgets);

          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }

    for (final size in const [Size(568, 320), Size(852, 300)]) {
      testWidgets('${label(size)} disconnected: the empty state fits', (
        tester,
      ) async {
        await pumpPage(tester, size: size, isConnected: false);

        expectNoOverflow(tester);
        expect(find.text('No device connected'), findsOneWidget);
      });
    }
  });

  group('phone failure modes', () {
    // Android Chrome's text-size setting reaches Flutter web as a text scale.
    // Compact knob captions then outgrow their 72-px dials: every cell must
    // reflow instead of overflowing.
    for (final (name, moduleId, fxId, params, isCloneMode) in [
      ('NR Gate', 0, 1, <int, num>{}, false),
      ...heavyEditors,
    ]) {
      testWidgets('640x360 at 130% text: $name does not overflow', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await pumpEditorPage(
          tester,
          size: const Size(640, 360),
          moduleId: moduleId,
          fxId: fxId,
          params: params,
          isCloneMode: isCloneMode,
        );

        expectNoOverflow(tester);

        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    // Turning the phone to portrait (the app lays out at the 640 minimum) and
    // back keeps the editor across the work area, with no overflow.
    testWidgets('a rotation keeps the editor full width, no overflow', (
      tester,
    ) async {
      await pumpEditorPage(
        tester,
        size: const Size(852, 393),
        moduleId: 4,
        fxId: 416,
      );

      for (final size in const [Size(393, 852), Size(852, 393)]) {
        tester.view.physicalSize = size;
        await tester.pump();
        await tester.pump();

        expect(
          tester.getSize(editorSurface()).width,
          tester.getSize(find.byType(ChainView)).width,
        );
        expectNoOverflow(tester);
      }
    });

    // Typing a knob value in a browser tab: the keyboard leaves the work area
    // ~12 px tall. Its min height (viewport - 2 x workPadding) must stay
    // clamped at 0, or BoxConstraints asserts on a negative minimum.
    testWidgets('740x280: a 220-px keyboard over an open knob editor', (
      tester,
    ) async {
      await pumpPage(tester, size: const Size(740, 280));

      final readout = tester.getCenter(inEditor(find.text('50')));

      await tester.tapAt(readout);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(readout);
      await tester.pump();

      expect(inEditor(find.byType(EditableText)), findsOneWidget);

      await setKeyboard(tester, 220);

      expect(tester.takeException(), isNull);
      expect(inEditor(find.byType(EditableText)), findsOneWidget);

      // Flushes the double-tap recognizer's timer.
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
