import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/protocol/cfw_backup.dart';
import 'package:sonicmaster/state/cfw_backup_io.dart';
import 'package:sonicmaster/state/cfw_providers.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';
import 'package:sonicmaster/ui/cfw_backup_section.dart';

import '../support/backup_fixtures.dart';
import '../support/fake_cfw_pedal.dart';
import '../support/sonic_host.dart';
import '../support/test_assets.dart';

void main() {
  final assets = loadTestDataAssets();

  Future<List<(String, List<int>)>> pump(
    WidgetTester tester,
    FakeCfwPedal pedal, {
    String? picked,
  }) async {
    final saved = <(String, List<int>)>[];

    await pumpSonicHost(
      tester,
      home: const Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 420, child: CfwBackupSection()),
      ),
      overrides: [
        dataAssetsProvider.overrideWith((_) => assets),
        deviceServiceProvider.overrideWithValue(pedal),
        cfwInfoProvider.overrideWith((_) => testCfwInfo()),
        backupFileSaverProvider.overrideWithValue((name, bytes, _) async {
          saved.add((name, bytes));

          return '/saved/$name';
        }),
        backupFilePickerProvider.overrideWithValue(() async => picked),
      ],
    );

    return saved;
  }

  // Lets the post-restore refreshes (they time out on the fake) finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('Back up now saves a file the CFW app accepts', (tester) async {
    final pedal = FakeCfwPedal();
    final saved = await pump(tester, pedal);

    await tester.tap(find.text('Back up now'));
    await settle(tester);

    final (name, bytes) = saved.single;

    expect(name, startsWith('sonicake-cfw-backup-CFW1.0.2-'));
    expect(name, endsWith('.smbackup.json'));
    expect(parseCfwBackup(utf8.decode(bytes)).$2, isEmpty);
    expect(find.textContaining('Backup saved: /saved/'), findsOneWidget);
  });

  testWidgets('a failed read saves nothing', (tester) async {
    final pedal = FakeCfwPedal()..deadSlots.add(0);
    final saved = await pump(tester, pedal);

    await tester.tap(find.text('Back up now'));
    await settle(tester);

    expect(saved, isEmpty);
    expect(
      find.text(
        'Backup failed: P01: no answer from the pedal (12 4F). Nothing was saved.',
      ),
      findsOneWidget,
    );
  });

  Future<String> changedBackup(FakeCfwPedal pedal) async {
    final b = await readPedalBackup(pedal, testCfwInfo(), app: 'test');

    pedal.reads.clear();

    return encodeCfwBackup(
      CfwBackup(
        created: b.created,
        app: b.app,
        pedal: b.pedal,
        sections: b.sections,
        presets: [
          for (final p in b.presets)
            p.index == 1
                ? BackupPreset(index: 1, record: testPresetRecord('New'))
                : p,
        ],
        cfwSettings: b.cfwSettings,
      ),
    );
  }

  testWidgets('Restore shows what it overwrites and writes after Restore', (
    tester,
  ) async {
    final pedal = FakeCfwPedal();
    final file = await tester.runAsync(() => changedBackup(pedal));
    final saved = await pump(tester, pedal, picked: file);

    await tester.tap(find.text('Restore…'));
    await settle(tester);

    expect(find.text('• Presets: 1 written (P02)'), findsOneWidget);
    expect(pedal.writes, isEmpty);
    expect(saved, isEmpty);

    await tester.tap(find.text('Restore'));
    await settle(tester);

    // The pedal as it was is saved before anything is written.
    expect(saved.single.$1, endsWith('-before-restore.smbackup.json'));
    expect(pedal.writes.single.sublist(0, 4), [0x11, 0x34, 1, 0]);
    expect(presetRecordName(pedal.records[1]!), 'New');
    expect(find.textContaining('Restored 1 preset(s)'), findsOneWidget);
  });

  testWidgets('Cancel writes nothing', (tester) async {
    final pedal = FakeCfwPedal();
    final file = await tester.runAsync(() => changedBackup(pedal));
    final saved = await pump(tester, pedal, picked: file);

    await tester.tap(find.text('Restore…'));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(pedal.writes, isEmpty);
    expect(saved, isEmpty);
    expect(find.text('Restore cancelled: nothing was written'), findsOneWidget);
  });

  testWidgets('another file is refused before the pedal is read', (
    tester,
  ) async {
    final pedal = FakeCfwPedal();

    await pump(tester, pedal, picked: '{"type": "preset"}');
    await tester.tap(find.text('Restore…'));
    await settle(tester);

    expect(pedal.reads, isEmpty);
    expect(
      find.text('Restore refused: not a Sonicake CFW backup file'),
      findsOneWidget,
    );
  });

  group('in Portuguese', () {
    setUp(() => appLang = Lang.pt);
    tearDown(() => appLang = Lang.en);

    testWidgets('Back up now and Restore read in Portuguese', (tester) async {
      final pedal = FakeCfwPedal();
      final file = await tester.runAsync(() => changedBackup(pedal));

      await pump(tester, pedal, picked: file);
      await tester.tap(find.text('Restaurar…'));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Restaurar este backup?'), findsOneWidget);
      expect(find.text('Vai sobrescrever na pedaleira:'), findsOneWidget);
      expect(find.text('• Presets: 1 gravados (P02)'), findsOneWidget);

      await tester.tap(find.text('Restaurar'));
      await settle(tester);

      expect(find.textContaining('Restaurado(s): 1 preset(s)'), findsOneWidget);
      expect(
        find.textContaining('Backup de antes da restauração:'),
        findsOneWidget,
      );

      await tester.tap(find.text('Fazer backup agora'));
      await settle(tester);

      expect(find.textContaining('Backup salvo: /saved/'), findsOneWidget);
    });

    testWidgets('a file that is not JSON is refused in Portuguese', (
      tester,
    ) async {
      await pump(tester, FakeCfwPedal(), picked: 'not json');
      await tester.tap(find.text('Restaurar…'));
      await settle(tester);

      expect(
        find.text('Restauração recusada: não é um arquivo JSON'),
        findsOneWidget,
      );
    });
  });
}
