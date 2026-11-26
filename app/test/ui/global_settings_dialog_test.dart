import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/model/cfw_eq_models.dart';
import 'package:sonicmaster/model/cfw_global_eq.dart';
import 'package:sonicmaster/model/cfw_info.dart';
import 'package:sonicmaster/model/global_settings.dart';
import 'package:sonicmaster/model/preset_ref.dart';
import 'package:sonicmaster/protocol/cfw_geq_codec.dart';
import 'package:sonicmaster/protocol/cfw_preset_order_codec.dart';
import 'package:sonicmaster/protocol/cfw_setting_writer.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/preset_providers.dart';
import 'package:sonicmaster/ui/eq_curve_view.dart';
import 'package:sonicmaster/ui/global_settings_dialog.dart';
import 'package:sonicmaster/ui/knob_control.dart';
import 'package:sonicmaster/ui/midi_map_dialog.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';
import 'package:sonicmaster/ui/sonic_metrics.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/silent_transport.dart';
import '../support/sonic_host.dart';
import '../support/test_assets.dart';
import '../support/view_helpers.dart';

void main() {
  final assets = loadTestDataAssets();

  // Opens the Settings dialog over a silent pedal; returns its transport (the
  // frames a knob or switch sends).
  Future<SilentTransport> openSettings(
    WidgetTester tester, {
    required Size size,
    List<Override> extra = const [],
    int expFsType = 0,
  }) async {
    final transport = SilentTransport();
    final context = await pumpSonicHost(
      tester,
      size: size,
      overrides: [
        dataAssetsProvider.overrideWith((_) => assets),
        deviceServiceProvider.overrideWith((ref) {
          final service = DeviceService(transport)..startListening();

          ref.onDispose(service.dispose);

          return service;
        }),
        globalSettingsProvider.overrideWith(
          (_) => GlobalSettings(
            globalVolume: 50,
            inputLevel: 0,
            fxRecLevel: 0,
            monitorLevel: 0,
            btRecLevel: 0,
            expFsType: expFsType,
          ),
        ),
        ...extra,
      ],
    );

    unawaited(
      showSonicDialog<void>(
        context: context,
        builder: (_) => const GlobalSettingsDialog(),
      ),
    );
    await tester.pumpAndSettle();

    return transport;
  }

  Finder inDialog(Finder finder) =>
      find.descendant(of: find.byType(GlobalSettingsDialog), matching: finder);

  // The dialog's scroll views, outermost first: SonicDialog's carries the
  // whole dialog.
  List<ScrollPosition> scrolls(WidgetTester tester) => tester
      .stateList<ScrollableState>(inDialog(find.byType(Scrollable)))
      .map((state) => state.position)
      .toList();

  for (final size in const [
    Size(852, 393),
    Size(780, 360),
    Size(640, 300),
    Size(740, 280),
    Size(568, 320),
  ]) {
    final where = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('$where: title, settings and Close scroll as one list', (
      tester,
    ) async {
      await openSettings(tester, size: size);

      final [dialog, ...] = scrolls(tester);

      expect(tester.takeException(), isNull);
      expect(dialog.maxScrollExtent, greaterThan(0));

      await tester.ensureVisible(find.text('Close'));
      await tester.pumpAndSettle();

      expectWithin(
        tester.getRect(find.text('Close')),
        Offset.zero & size,
        'Close',
      );
    });
  }

  testWidgets('568x320: a level being typed stays above the keyboard', (
    tester,
  ) async {
    const size = Size(568, 320);
    const visible = Rect.fromLTWH(0, 0, 568, 320 - 180);

    await openSettings(tester, size: size);

    final readout = tester.getCenter(find.text('0 dB').first); // Input

    await tester.tapAt(readout);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(readout);
    await tester.pump();
    await setKeyboard(tester, 180);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expectWithin(
      tester.getRect(find.byType(EditableText)),
      visible,
      'the level field',
    );

    await tester.ensureVisible(find.text('Close'));
    await tester.pumpAndSettle();

    expectWithin(tester.getRect(find.text('Close')), visible, 'Close');
  });

  // A phone user flicks the Settings list upward and the flick starts on a
  // level knob: the list must scroll, and no live level may change.
  testWidgets('568x320: a flick that starts on a level knob scrolls', (
    tester,
  ) async {
    final transport = await openSettings(tester, size: const Size(568, 320));
    final gesture = await tester.startGesture(
      tester.getCenter(inDialog(find.byKey(const Key('knob'))).first),
    );

    for (final _ in Iterable<int>.generate(6)) {
      await gesture.moveBy(const Offset(0, -10));
    }

    await gesture.up();
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GlobalSettingsDialog)),
    );

    expect(scrolls(tester).first.pixels, greaterThan(0));
    expect(transport.sentFrames, isEmpty);
    expect(container.read(globalSettingsProvider)!.inputLevel, 0);
  });

  for (final size in const [Size(1280, 800), Size(1024, 768), Size(960, 640)]) {
    final where = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('regular $where: a CFW pedal lays out without overflow', (
      tester,
    ) async {
      await openSettings(
        tester,
        size: size,
        extra: [
          connectionStateProvider.overrideWith((_) => true),
          cfwInfoProvider.overrideWith(
            (_) => decodeCfwSettingsFrame(cfwSettingsOriginal)!,
          ),
        ],
      );

      expectNoOverflow(tester);
    });
  }

  group('new layout (1180x820, Portuguese)', () {
    final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;
    final models = parseCfwEqModels(
      jsonDecode(File('assets/data/cfw_eq_models.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final full = <Override>[
      connectionStateProvider.overrideWith((_) => true),
      cfwInfoProvider.overrideWith((_) => cfw),
      cfwEqModelsProvider.overrideWith((_) => models),
      globalEqProvider.overrideWith(
        (_) => const CfwGlobalEq(
          isOn: true,
          model: 0,
          slots: [4, 0, 0, 0, 0, 50, 7, 100],
        ),
      ),
    ];
    const screen = Size(1180, 820);

    // The prototype's faces, so the fit is measured with the real metrics
    // instead of the wide test font.
    setUpAll(() async {
      for (final (family, file) in const [
        ('Inter', 'Inter'),
        ('Space Grotesk', 'SpaceGrotesk'),
        ('JetBrains Mono', 'JetBrainsMono'),
      ]) {
        await (FontLoader(
          family,
        )..addFont(rootBundle.load('assets/fonts/$file.ttf'))).load();
      }
    });
    setUp(() => appLang = Lang.pt);
    tearDown(() => appLang = Lang.en);

    // Typical, and the tallest state: the Custom MIDI map (three more rows)
    // with DualFS (two targets), as the prototype draws it.
    for (final (state, info, expFsType) in [
      ('', cfw, 0),
      (
        ' (Custom map, DualFS)',
        cfw.copyWithSetting(CfwInfo.midiMapKey, CfwInfo.customMap),
        2,
      ),
    ]) {
      testWidgets(
        'all nine sections fit in three columns at 1180x820 without scrolling'
        '$state',
        (tester) async {
          await openSettings(
            tester,
            size: screen,
            expFsType: expFsType,
            extra: [
              ...full.skip(2),
              connectionStateProvider.overrideWith((_) => true),
              cfwInfoProvider.overrideWith((_) => info),
            ],
          );

          expectNoOverflow(tester);
          for (final s in scrolls(tester)) {
            expect(s.maxScrollExtent, 0);
          }

          const titles = [
            'NÍVEIS',
            'EQ GLOBAL',
            'TELA',
            'FOOTSWITCHES',
            'MIDI',
            'ENERGIA',
            'ORDEM DOS PRESETS',
            'PEDALEIRA INTEIRA',
            'REDEFINIR',
          ];
          final lefts = <double>{};

          for (final title in titles) {
            final rect = tester.getRect(inDialog(find.text(title)));

            expectWithin(rect, Offset.zero & screen, title);
            lefts.add(rect.left.roundToDouble());
          }
          expect(lefts, hasLength(3));
          expectWithin(
            tester.getRect(inDialog(find.text('Fechar'))),
            Offset.zero & screen,
            'Fechar',
          );
          // Dense knobs keep the regular layout's input behaviour.
          expect(
            SonicMetrics.of(
              tester.element(inDialog(find.byType(KnobControl)).first),
            ).isCompact,
            isFalse,
          );
        },
      );
    }

    testWidgets('selects open their options', (tester) async {
      await openSettings(tester, size: screen, extra: full);

      await tester.tap(inDialog(find.text('Todos os canais')));
      await tester.pumpAndSettle();

      expect(find.text('Canal 2'), findsOneWidget);

      await tester.tap(find.text('Canal 2'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.textContaining('Auto —')));
      await tester.pumpAndSettle();

      expect(find.text('Smart Box'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Fazer backup agora is the primary button', (tester) async {
      await openSettings(tester, size: screen, extra: full);

      final backup = tester.widget<SonicButton>(
        inDialog(find.widgetWithText(SonicButton, 'Fazer backup agora')),
      );
      final restore = tester.widget<SonicButton>(
        inDialog(find.widgetWithText(SonicButton, 'Restaurar…')),
      );

      expect(backup.isAccent, isTrue);
      expect(restore.isAccent, isFalse);
    });
  });

  for (final (size, eco) in const [
    (Size(852, 393), 1), // compact: the whole row is the switch
    (Size(1280, 800), 0), // regular: only the toggle (unchanged)
  ]) {
    final mode = eco == 1 ? 'compact' : 'regular';

    testWidgets('$mode: tapping the ECO label toggles ECO: ${eco == 1}', (
      tester,
    ) async {
      final transport = await openSettings(tester, size: size);
      final label = find.text('ECO');

      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      await tester.tap(label);
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GlobalSettingsDialog)),
      );

      expect(container.read(globalSettingsProvider)!.eco, eco);
      expect(transport.sentFrames, hasLength(eco));
    });
  }

  group('CFW', () {
    final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;
    final cfwConnected = <Override>[
      connectionStateProvider.overrideWith((_) => true),
      cfwInfoProvider.overrideWith((_) => cfw),
    ];

    testWidgets('a CFW pedal shows its version and the CFW settings', (
      tester,
    ) async {
      await openSettings(
        tester,
        size: const Size(1280, 800),
        extra: cfwConnected,
      );

      for (final label in [
        'CFW 1.0.2',
        'Theme',
        'BRIGHTNESS',
        'Direct Monitor',
        'USB Rec',
        'Pedal mode',
        'Back up now',
        'Restore…',
      ]) {
        expect(inDialog(find.text(label)), findsOneWidget, reason: label);
      }
      expect(inDialog(find.text('BACKLIGHT')), findsNothing);
      expect(inDialog(find.text('DRY')), findsNothing);
    });

    testWidgets('a stock pedal keeps the stock settings', (tester) async {
      await openSettings(tester, size: const Size(1280, 800));

      expect(inDialog(find.text('BACKLIGHT')), findsOneWidget);
      expect(inDialog(find.text('DRY')), findsOneWidget);
      expect(inDialog(find.text('Theme')), findsNothing);
      expect(inDialog(find.text('Back up now')), findsNothing);
    });

    testWidgets('CFW settings stay hidden while disconnected', (tester) async {
      await openSettings(
        tester,
        size: const Size(1280, 800),
        extra: [cfwInfoProvider.overrideWith((_) => cfw)],
      );

      expect(inDialog(find.text('Theme')), findsNothing);
    });

    testWidgets('picking a theme sends it and shows it', (tester) async {
      final transport = await openSettings(
        tester,
        size: const Size(1280, 800),
        extra: cfwConnected,
      );

      await tester.ensureVisible(inDialog(find.text('Synthwave')));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.text('Synthwave')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Game Boy').last);
      await tester.pumpAndSettle();

      expect(
        transport.sentFrames.map((f) => f.toLowerCase()),
        contains(
          CfwSettingWriter.setting(CfwSettingWriter.theme, 5).toLowerCase(),
        ),
      );
      expect(inDialog(find.text('Game Boy')), findsOneWidget);
      // The silent pedal never acks: let the ack wait time out.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('an unknown theme value does not break the dialog', (
      tester,
    ) async {
      await openSettings(
        tester,
        size: const Size(1280, 800),
        extra: [
          connectionStateProvider.overrideWith((_) => true),
          cfwInfoProvider.overrideWith((_) => cfw.copyWithSetting(0x01, 9)),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(inDialog(find.text('Theme')), findsOneWidget);
    });
  });

  group('CFW Global EQ', () {
    final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;
    final models = parseCfwEqModels(
      jsonDecode(File('assets/data/cfw_eq_models.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    const studio = CfwGlobalEq(
      isOn: true,
      model: 0,
      slots: [4, 0, 0, 0, 0, 50, 7, 100],
    );
    List<Override> withEq(CfwGlobalEq? eq) => [
      connectionStateProvider.overrideWith((_) => true),
      cfwInfoProvider.overrideWith((_) => cfw),
      cfwEqModelsProvider.overrideWith((_) => models),
      globalEqProvider.overrideWith((_) => eq),
    ];

    testWidgets('shows the model, its knobs and their texts', (tester) async {
      await openSettings(
        tester,
        size: const Size(1280, 800),
        extra: withEq(studio),
      );

      expect(inDialog(find.text('Global EQ')), findsWidgets);
      expect(inDialog(find.text('Studio EQ')), findsOneWidget);
      expect(inDialog(find.text('BASS')), findsOneWidget);
      expect(inDialog(find.text('+2.0dB')), findsOneWidget);
      expect(inDialog(find.text('26Hz')), findsOneWidget);
      expect(inDialog(find.byType(EqCurve)), findsOneWidget);
    });

    testWidgets('is absent on stock firmware', (tester) async {
      await openSettings(tester, size: const Size(1280, 800));

      expect(inDialog(find.text('Global EQ')), findsNothing);
    });

    testWidgets('picking a model sends the block with its defaults', (
      tester,
    ) async {
      final transport = await openSettings(
        tester,
        size: const Size(1280, 800),
        extra: withEq(studio),
      );

      await tester.ensureVisible(inDialog(find.text('Studio EQ')));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.text('Studio EQ')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parametric 3').last);
      await tester.pumpAndSettle();

      expect(
        transport.sentFrames.map((f) => f.toLowerCase()),
        contains(
          buildGlobalEqFrame(
            const CfwGlobalEq(
              isOn: true,
              model: 1,
              slots: [0, 0, 0, 0, 0, 50, 33, 40],
            ),
          ).toLowerCase(),
        ),
      );
      expect(inDialog(find.text('LOW F')), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('an unknown model shows only the switch', (tester) async {
      await openSettings(
        tester,
        size: const Size(1280, 800),
        extra: withEq(studio.copyWith(model: 5)),
      );

      expect(tester.takeException(), isNull);
      expect(inDialog(find.text('Global EQ')), findsWidgets);
      expect(inDialog(find.text('BASS')), findsNothing);
      expect(inDialog(find.text('Model')), findsNothing);
    });
  });

  group('CFW MIDI', () {
    final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;
    List<Override> on(CfwInfo info) => [
      connectionStateProvider.overrideWith((_) => true),
      cfwInfoProvider.overrideWith((_) => info),
    ];
    Future<void> pick(WidgetTester tester, String current, String next) async {
      await tester.ensureVisible(inDialog(find.text(current)));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.text(current)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(next).last);
      await tester.pumpAndSettle();
    }

    List<String> sent(SilentTransport t) =>
        t.sentFrames.map((f) => f.toLowerCase()).toList();

    testWidgets('shows the MIDI settings of a CFW pedal', (tester) async {
      await openSettings(tester, size: const Size(1280, 800), extra: on(cfw));

      for (final label in [
        'MIDI map',
        'MIDI channel',
        'Same preset again',
        'Tempo scope',
        'Drum Sync',
      ]) {
        expect(inDialog(find.text(label)), findsOneWidget, reason: label);
      }
      expect(inDialog(find.text('Stock')), findsOneWidget);
      expect(inDialog(find.text('All channels')), findsOneWidget);
      // Only the Custom map has these options.
      expect(inDialog(find.text('First PC')), findsNothing);
    });

    testWidgets('is absent on stock firmware', (tester) async {
      await openSettings(tester, size: const Size(1280, 800));

      expect(inDialog(find.text('MIDI map')), findsNothing);
    });

    testWidgets('map and channel send the captured keys', (tester) async {
      final t = await openSettings(
        tester,
        size: const Size(1280, 800),
        extra: on(cfw),
      );

      await pick(tester, 'Stock', 'Chocolate');
      await pick(tester, 'All channels', 'Channel 2');

      expect(
        sent(t),
        containsAll([
          '8080f00f0a0001000000040101020a01050003f7',
          '8080f009060001000000040101020a01020002f7',
        ]),
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('same-again, tempo scope and drum sync send their keys', (
      tester,
    ) async {
      final t = await openSettings(
        tester,
        size: const Size(1280, 800),
        extra: on(cfw),
      );

      await tester.ensureVisible(inDialog(find.text('CYCLE')));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.text('CYCLE')));
      await tester.tap(inDialog(find.text('GLOBAL')));
      await tester.pump();

      expect(
        sent(t),
        containsAll([
          '8080f00a000001000000040101020a01010001f7',
          '8080f00c0b0001000000040101020a01060001f7',
        ]),
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
      'the Custom map adds First PC and the CC range (one bitfield)',
      (tester) async {
        final t = await openSettings(
          tester,
          size: const Size(1280, 800),
          extra: on(cfw.copyWithSetting(0x15, 1).copyWithSetting(0x17, 1)),
        );

        expect(inDialog(find.text('First PC')), findsOneWidget);
        await tester.ensureVisible(inDialog(find.text('0..127')));
        await tester.pumpAndSettle();
        await tester.tap(inDialog(find.text('0..127')));
        await tester.pump();

        // bit0 (PC 1) kept, bit1 (0..127) added -> 3.
        expect(
          sent(t),
          contains(CfwSettingWriter.setting(0x17, 3).toLowerCase()),
        );
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });

  group('CFW preset order', () {
    final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

    testWidgets('is absent on stock firmware', (tester) async {
      await openSettings(tester, size: const Size(1280, 800));

      expect(inDialog(find.text('PRESET ORDER')), findsNothing);
      expect(inDialog(find.text('Move preset')), findsNothing);
    });

    testWidgets('moving to the same position is not offered', (tester) async {
      final transport = await openSettings(
        tester,
        size: const Size(1280, 800),
        extra: [
          connectionStateProvider.overrideWith((_) => true),
          cfwInfoProvider.overrideWith((_) => cfw),
          currentPresetProvider.overrideWith((_) => const PresetRef(.user, 1)),
        ],
      );
      final button = inDialog(find.text('Move preset'));

      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();

      expect(
        transport.sentFrames.map((f) => f.toLowerCase()),
        isNot(contains(readPresetOrderFrame().toLowerCase())),
      );
    });

    testWidgets('a different position asks the pedal for its order', (
      tester,
    ) async {
      final transport = await openSettings(
        tester,
        size: const Size(1280, 800),
        extra: [
          connectionStateProvider.overrideWith((_) => true),
          cfwInfoProvider.overrideWith((_) => cfw),
          currentPresetProvider.overrideWith((_) => const PresetRef(.user, 2)),
        ],
      );
      final button = inDialog(find.text('Move preset'));

      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();

      expect(
        transport.sentFrames.map((f) => f.toLowerCase()),
        contains(readPresetOrderFrame().toLowerCase()),
      );

      // The silent pedal never answers: run out the read.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    });

    testWidgets('phone: the section fits', (tester) async {
      await openSettings(
        tester,
        size: const Size(852, 393),
        extra: [
          connectionStateProvider.overrideWith((_) => true),
          cfwInfoProvider.overrideWith((_) => cfw),
        ],
      );

      expectNoOverflow(tester);
    });
  });

  group('CFW custom MIDI map', () {
    final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

    testWidgets('Edit map is offered only with the Custom map', (tester) async {
      await openSettings(
        tester,
        size: const Size(1280, 800),
        extra: [
          connectionStateProvider.overrideWith((_) => true),
          cfwInfoProvider.overrideWith((_) => cfw),
        ],
      );
      expect(inDialog(find.text('Edit map')), findsNothing);
    });

    testWidgets('with the Custom map it opens the editor', (tester) async {
      await openSettings(
        tester,
        size: const Size(1280, 800),
        extra: [
          connectionStateProvider.overrideWith((_) => true),
          cfwInfoProvider.overrideWith(
            (_) => cfw.copyWithSetting(CfwInfo.midiMapKey, CfwInfo.customMap),
          ),
        ],
      );

      final button = inDialog(find.text('Edit map'));

      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(MidiMapDialog), findsOneWidget);

      // The silent pedal never answers the map read: run it out.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    });
  });

  group('in Portuguese', () {
    final cfw = decodeCfwSettingsFrame(
      cfwSettingsOriginal,
    )!.copyWithSetting(0x15, 1);
    final on = <Override>[
      connectionStateProvider.overrideWith((_) => true),
      cfwInfoProvider.overrideWith((_) => cfw),
    ];

    setUp(() => appLang = Lang.pt);
    tearDown(() => appLang = Lang.en);

    testWidgets('820x1180: the CFW settings read in Portuguese and fit', (
      tester,
    ) async {
      await openSettings(tester, size: const Size(820, 1180), extra: on);

      expect(tester.takeException(), isNull);
      for (final text in [
        'Ajustes',
        'NÍVEIS',
        'Canal MIDI',
        'Todos os canais',
        'Mesmo preset de novo',
        'Editar mapa',
        'ORDEM DOS PRESETS',
        'Mover preset',
        'PEDALEIRA INTEIRA',
        'Fazer backup agora',
        'Restaurar de um arquivo',
        'Fechar',
      ]) {
        expect(inDialog(find.text(text)), findsOneWidget, reason: text);
      }
    });

    testWidgets('the factory reset asks in Portuguese', (tester) async {
      await openSettings(tester, size: const Size(820, 1180));

      final reset = find.text('Redefinir para o padrão de fábrica');

      await tester.ensureVisible(reset);
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Redefinir para o padrão de fábrica?'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Redefinir'), findsWidgets);
    });
  });
}
