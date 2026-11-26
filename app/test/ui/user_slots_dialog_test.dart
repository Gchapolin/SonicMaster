import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/gear/gear_piece.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/ir_upload_frame.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/state/edit_providers.dart';
import 'package:sonicmaster/state/names_providers.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';
import 'package:sonicmaster/ui/user_ir_actions.dart';
import 'package:sonicmaster/ui/user_profile_actions.dart';
import 'package:sonicmaster/ui/user_slots_dialog.dart';

import '../fixtures/cfw_dumps.dart';
import '../support/page_harness.dart';
import '../support/sonic_host.dart';
import '../support/silent_transport.dart';
import '../support/test_assets.dart';

class _Pedal extends DeviceService {
  _Pedal() : super(SilentTransport());

  final uploads = <List<String>>[];

  @override
  Future<String?> requestCfwSlotNames(
    int register, {
    Duration timeout = const Duration(seconds: 1),
  }) async => null;

  @override
  Future<String?> requestUserNames(
    String requestHex, {
    Duration timeout = const Duration(seconds: 1),
  }) async => null;

  @override
  Future<IrWriteResult> uploadIr(
    List<String> chunkFrames, {
    void Function(int sent, int total)? onProgress,
    Duration ackTimeout = const Duration(milliseconds: 1200),
    int ackRetries = 10,
    Duration commitTimeout = const Duration(seconds: 5),
  }) async {
    uploads.add(chunkFrames);

    return IrWriteResult.committed;
  }
}

void main() {
  setUp(() => appLang = Lang.pt);
  tearDown(() => appLang = Lang.en);

  final assets = loadTestDataAssets();
  final cfw = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

  Future<void> pump(
    WidgetTester tester, {
    bool isCfw = true,
    bool isConnected = true,
    DeviceService? pedal,
  }) async {
    await pumpSonicHost(
      tester,
      size: const Size(1180, 820),
      home: const UserSlotsDialog(),
      overrides: [
        if (pedal != null) deviceServiceProvider.overrideWithValue(pedal),
        dataAssetsProvider.overrideWith((_) async => assets),
        connectionStateProvider.overrideWith((_) => isConnected),
        cfwInfoProvider.overrideWith((_) => isCfw ? cfw : null),
        userNamesProvider.overrideWith(
          (_) => const {416: 'Jazz 2x12', 426: 'Last IR', 901: 'Satan 50'},
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('CFW: ten IR and ten Clone slots, with their names', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(UserIrActions), findsNWidgets(10));
    expect(find.byType(UserProfileActions), findsNWidgets(10));
    expect(find.text('IR 1'), findsOneWidget);
    expect(find.text('Jazz 2x12'), findsOneWidget);
    expect(find.text('Last IR'), findsOneWidget);
    expect(find.text('Clone 1'), findsOneWidget);
    expect(find.text('Satan 50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two columns of ten', (tester) async {
    await pump(tester);

    final ir = tester.getTopLeft(find.text('IR 1')).dx;
    final clone = tester.getTopLeft(find.text('Clone 1')).dx;

    expect(clone, greaterThan(ir + 400));
    expect(tester.getTopLeft(find.text('IR 10')).dx, ir);
    expect(tester.getTopLeft(find.text('Clone 10')).dx, clone);
    expect(find.text('Carregar…'), findsNWidgets(20));
    expect(find.text('Nome…'), findsNWidgets(20));
    expect(find.text('Limpar'), findsNWidgets(20));
  });

  testWidgets('each header shows its piece', (tester) async {
    await pump(tester);

    final pieces = tester.widgetList<GearPiece>(find.byType(GearPiece));

    expect(pieces.map((p) => p.model), ['User IR 1', 'Brit 800']);
    expect(pieces.map((p) => p.kind), [GearKind.cab, GearKind.amp]);
    expect(find.text('10 SLOTS'), findsNWidgets(2));
  });

  testWidgets('Limpar clears that slot only', (tester) async {
    final pedal = _Pedal();

    await pump(tester, pedal: pedal);

    await tester.tap(
      find.descendant(
        of: find.byType(UserIrActions).at(2),
        matching: find.text('Limpar'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(SonicDialog).last,
        matching: find.widgetWithText(SonicButton, 'Limpar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(pedal.uploads, [
      IrUploadFrame.buildChunks(IrUploadFrame.buildClearBlob(slot: 2)),
    ]);
  });

  testWidgets('stock firmware: five of each', (tester) async {
    await pump(tester, isCfw: false);

    expect(find.byType(UserIrActions), findsNWidgets(5));
    expect(find.byType(UserProfileActions), findsNWidgets(5));
  });

  testWidgets('disconnected: the slot buttons are off', (tester) async {
    await pump(tester, isConnected: false);

    final load = tester.widget<SonicButton>(
      find
          .descendant(
            of: find.byType(UserIrActions).first,
            matching: find.byType(SonicButton),
          )
          .first,
    );

    expect(load.onPressed, isNull);
  });

  // The IR and Clone modules open the dialog, whatever cab or amp the preset
  // uses: no need to switch it to a user slot first.
  for (final (name, module, fx) in const [('IR', 4, 401), ('Clone', 9, 901)]) {
    testWidgets('the $name module opens the slots dialog', (tester) async {
      await pumpPage(
        tester,
        size: const Size(820, 1180),
        selectedEffects: {module: fx},
        parameters: const {},
        overrides: [selectedModuleProvider.overrideWith((_) => module)],
      );

      final button = find.text('Slots…');

      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(UserSlotsDialog), findsOneWidget);
    });
  }
}
