import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/protocol/cfw_backup.dart';
import 'package:sonicmaster/protocol/global_setting_writer.dart';
import 'package:sonicmaster/state/cfw_backup_io.dart';

import '../support/backup_fixtures.dart';
import '../support/fake_cfw_pedal.dart';
import '../support/test_assets.dart';

/// AMP SC1 p0 = 33.0, keyed with effect id 0x07000001 (captured).
final _ampScenes = Uint8List.fromList([
  0x53, 0x43, 0x01, 0x01, 0x14, 0x00, 0xc3, 0xc2, //
  0x03, 0x01, 0x01, 0x00, 0x01, 0x00, 0x00, 0x07, 0x00, 0x00, 0x04, 0x42,
]);

final _ampIds = [0, 0, 0, 0x07000001, 0, 0, 0, 0, 0, 0];

String? _noGlobals(String name, int value, int expFsType) => null;

Future<CfwBackup> _read(FakeCfwPedal pedal, {int caps2 = cfwCaps2}) =>
    readPedalBackup(
      pedal,
      testCfwInfo(caps2: caps2),
      app: 'SonicMaster test',
      now: DateTime.utc(2026, 11, 25, 18),
    );

void main() {
  group('backup', () {
    test('reads what the CFW app reads, in its order', () async {
      final pedal = FakeCfwPedal()
        ..clones[1] = (Uint8List(cloneDataLength)..[0] = 9);

      await _read(pedal);

      expect(pedal.reads.take(50), [
        for (var s = 0; s < 50; s++) '12 4f ${_b(s)} 00 00 00',
      ]);
      expect(pedal.reads.skip(50).take(100), [
        for (var s = 0; s < 50; s++) ...['12 34 ${_b(s)}', '12 3d ${_b(s)}'],
      ]);
      expect(pedal.reads.skip(150), [
        '12 39 00',
        '12 2a',
        '12 3a',
        '12 37',
        '12 28',
        '12 29',
        for (var c = 0; c < 6; c++) '12 38 00 00 ${_b(c)}',
        'globals',
      ]);
    });

    test('builds the CFW app document', () async {
      final pedal = FakeCfwPedal()
        ..records[2] = testPresetRecord('Amp', effectIds: _ampIds)
        ..scenes[2] = _ampScenes
        ..exp[2] = Uint8List.fromList([
          0, 0, 0, 0, 35, 0, //
          for (var s = 0; s < 3; s++) ...[255, 0, 0, 0, 0, 0],
        ])
        ..clones[1] = (Uint8List(cloneDataLength)..[0] = 9);

      final b = await _read(pedal);

      expect(b.presets, hasLength(50));
      expect(b.presets[2].scenes, _ampScenes);
      expect(b.presets[1].scenes, isNull);
      expect(b.presets[2].midiPedals, hasLength(26));
      expect(b.presets[1].midiPedals, isNull);
      expect(b.pedal.cfwTag, 'CFW1.0.2');
      expect(b.pedal.caps, cfwCaps);
      expect(b.cfwSettings.containsKey(16), isFalse); // the live scene
      expect(b.cfwSettings[1], 3);
      expect(b.globalEq, [0, 0, 0, 0, 0, 0, 0, 50, 0, 100]);
      expect(b.order, List.generate(50, (i) => i));
      expect(b.clones.single.slot, 1);
      expect(b.clones.single.data[0], 9);
      expect(b.irs, isEmpty);
      expect(b.midiMap!.entries, isEmpty);
      expect(b.sections, {
        'presets': 'complete',
        'scenes': 'complete',
        'midiPedals': 'complete',
        'midiMap': 'none',
        'order': 'complete',
        'globals': 'unavailable',
        'cfwSettings': 'complete',
        'globalEq': 'complete',
        'irs': 'none',
        'clones': 'complete',
      });
      // The file it makes passes the CFW app's checks.
      expect(parseCfwBackup(encodeCfwBackup(b)).$2, isEmpty);
    });

    test('a read that fails aborts the backup', () async {
      final pedal = FakeCfwPedal()..deadSlots.add(2);

      await expectLater(
        _read(pedal),
        throwsA(
          isA<CfwBackupException>().having(
            (e) => e.message,
            'message',
            'P03: no answer from the pedal (12 4F)',
          ),
        ),
      );
      expect(pedal.reads.where((r) => r.startsWith('12 4f 02')), hasLength(3));
      expect(pedal.reads.any((r) => r.startsWith('12 4f 03')), isFalse);
    });
  });

  group('restore', () {
    test('writes only what differs, in the CFW app order', () async {
      final pedal = FakeCfwPedal();
      final before = await _read(pedal);
      final amp = testPresetRecord('Amp', effectIds: _ampIds);
      final expBytes = Uint8List.fromList([
        0, 0, 0, 0, 35, 0, //
        for (var s = 0; s < 3; s++) ...[255, 0, 0, 0, 0, 0],
      ]);
      final file = CfwBackup(
        created: before.created,
        app: 'CFW app',
        pedal: before.pedal,
        sections: before.sections,
        presets: [
          ...before.presets.take(1),
          BackupPreset(
            index: 1,
            record: amp,
            scenes: _ampScenes,
            midiPedals: expBlockToMidiPedals(expBytes),
          ),
          ...before.presets.skip(2),
        ],
        cfwSettings: {...before.cfwSettings, 3: 0},
        globalEq: const [1, 0, 0, 0, 0, 0, 0, 50, 0, 100],
      );
      final (plan, error) = planRestore(file, before, testCfwInfo());

      expect(error, isNull);
      expect(plan!.overwrites, [
        'CFW settings: 1 to change',
        'Global EQ: changes',
        'Presets: 1 written (P02)',
        'Scenes: restored on P02',
        'EXP A–D: restored on P02',
      ]);

      pedal.reads.clear();

      final result = await runRestore(pedal, plan, globalFrame: _noGlobals);

      expect(result.isOk, isTrue);
      expect(
        result.message,
        'Restored 1 preset(s), 1 CFW setting(s), the Global EQ',
      );
      expect(pedal.writes, [
        [0x11, 0x2A, 3, 0],
        [0x11, 0x3A, 1, 0, 0, 0, 0, 0, 0, 50, 0, 100],
        presetWithScenesPayload(
          1,
          amp,
          scenes: _ampScenes,
          midiPedals: expBlockToMidiPedals(expBytes),
        ),
      ]);
      // Each write is checked by reading it back.
      expect(pedal.reads, [
        '12 2a',
        '12 4f 01 00 00 00',
        '12 34 01',
        '12 3d 01',
      ]);
      expect(result.notes, isEmpty);
    });

    test('a pedal without the one-write path gets 11 4F, scenes noted', () async {
      final pedal = FakeCfwPedal();
      final before = await _read(pedal, caps2: 0);
      final amp = testPresetRecord('Amp', effectIds: _ampIds);
      final file = _withPreset(
        before,
        BackupPreset(index: 4, record: amp, scenes: _ampScenes),
      );
      final (plan, _) = planRestore(file, before, testCfwInfo(caps2: 0));
      final result = await runRestore(pedal, plan!, globalFrame: _noGlobals);

      expect(pedal.writes, [presetWritePayload(4, amp)]);
      expect(result.isOk, isTrue);
      expect(result.notes, [
        'P05 scenes: not restored (this firmware needs the preset selected and saved; SonicMaster does not do that yet)',
      ]);
    });

    test('a preset that reads back different stops the restore', () async {
      final pedal = FakeCfwPedal();
      final before = await _read(pedal);
      final file = _withPreset(
        _withPreset(
          before,
          BackupPreset(index: 0, record: testPresetRecord('A')),
        ),
        BackupPreset(index: 1, record: testPresetRecord('B')),
      );
      final (plan, _) = planRestore(file, before, testCfwInfo());

      // The pedal takes the write but keeps its old preset.
      pedal.statusFor[0x34] = 0;

      final result = await runRestore(pedal, plan!, globalFrame: _noGlobals);

      expect(result.isOk, isFalse);
      expect(
        result.message,
        startsWith('P01: the pedal reads back a different preset'),
      );
      expect(pedal.writes, hasLength(1));
    });

    test('a refused write stops the restore', () async {
      final pedal = FakeCfwPedal();
      final before = await _read(pedal);
      final file = _withPreset(
        before,
        BackupPreset(index: 0, record: testPresetRecord('A')),
      );
      final (plan, _) = planRestore(file, before, testCfwInfo());

      pedal.statusFor[0x34] = 2;

      final result = await runRestore(pedal, plan!, globalFrame: _noGlobals);

      expect(result.isOk, isFalse);
      expect(result.message, 'P01: not written (11 34 status 2)');
    });

    test('nothing differs: nothing is written', () async {
      final pedal = FakeCfwPedal();
      final before = await _read(pedal);
      final (plan, _) = planRestore(before, before, testCfwInfo());

      expect(plan!.isEmpty, isTrue);
      expect(plan.overwrites, [
        'Nothing differs from the pedal: nothing to write',
      ]);
    });

    test(
      'a backup of another pedal or of the NAM CFW keeps the presets',
      () async {
        final pedal = FakeCfwPedal();
        final before = await _read(pedal);
        final other = CfwBackup(
          created: before.created,
          app: '',
          pedal: const BackupPedal(model: 'Smart Box', cfwTag: 'SB-CFW1.0'),
          sections: const {},
          presets: before.presets,
        );

        expect(
          planRestore(other, before, testCfwInfo()).$2,
          'This backup comes from a Smart Box: restore it on that pedal.',
        );

        final nam = CfwBackup(
          created: before.created,
          app: '',
          pedal: const BackupPedal(
            model: 'Pocket Master',
            cfwTag: 'CFW1.0.2-NAM',
            edition: 'nam',
          ),
          sections: const {},
          presets: [BackupPreset(index: 0, record: testPresetRecord('A'))],
          cfwSettings: {...before.cfwSettings, 3: 0},
          namModels: const {'models': []},
        );
        final (plan, _) = planRestore(nam, before, testCfwInfo());

        expect(plan!.presets, isEmpty);
        expect(plan.cfwSettings, {3: 0});
        expect(
          plan.notes.first,
          startsWith(
            'NAM models (slots 02–20), User presets (P01–P50): not restored. This backup was made on the NAM CFW',
          ),
        );
      },
    );

    test('the globals that differ are written after the presets', () async {
      final pedal = FakeCfwPedal();
      final before = await _read(pedal);
      final file = CfwBackup(
        created: before.created,
        app: '',
        pedal: before.pedal,
        sections: const {},
        presets: before.presets,
        globals: const {'globalVolume': 60, 'reamp': 1, 'eco': 1},
      );
      final (plan, _) = planRestore(
        file,
        CfwBackup(
          created: before.created,
          app: '',
          pedal: before.pedal,
          sections: const {},
          presets: before.presets,
          globals: const {'globalVolume': 75, 'reamp': 0, 'eco': 1},
        ),
        testCfwInfo(),
      );

      expect(plan!.globals, {'globalVolume': 60});
      expect(plan.notes, [
        'Global setting reamp: not restored (SonicMaster cannot check it on this pedal)',
      ]);

      final result = await runRestore(
        pedal,
        plan,
        globalFrame: (name, value, _) => 'frame-$name-$value',
      );

      expect(pedal.frames, ['frame-globalvolume-60']);
      expect(result.message, 'Restored 0 preset(s), 1 global setting(s)');
    });
  });

  test("global settings restore through the app's own writes", () {
    final c = loadTestDataAssets().commands;

    expect(
      globalRestoreFrame(c, 'globalVolume', 60, 0),
      c.globalCommand('globalVolume', 60),
    );
    expect(
      globalRestoreFrame(c, 'eco', 1, 0),
      GlobalSettingWriter.dumpRecord(a0: 4, a1: 2, value: 1),
    );
    expect(
      globalRestoreFrame(c, 'expFsTarget', 3, 0),
      GlobalSettingWriter.registerWrite(reg: 0x17, sub: 1, value: 3),
    );
    expect(
      globalRestoreFrame(c, 'expFsTarget2', 3, 2),
      GlobalSettingWriter.registerWrite(reg: 0x16, sub: 4, value: 3),
    );
    // Func 2 only exists for DualFS.
    expect(globalRestoreFrame(c, 'expFsTarget2', 3, 0), isNull);
    expect(globalRestoreFrame(c, 'reamp', 1, 0), isNull);
  });
}

String _b(int v) => v.toRadixString(16).padLeft(2, '0');

CfwBackup _withPreset(CfwBackup b, BackupPreset p) => CfwBackup(
  created: b.created,
  app: b.app,
  pedal: b.pedal,
  sections: b.sections,
  presets: [for (final q in b.presets) q.index == p.index ? p : q],
  cfwSettings: b.cfwSettings,
  globalEq: b.globalEq,
  midiMap: b.midiMap,
  clones: b.clones,
  irs: b.irs,
  order: b.order,
);
