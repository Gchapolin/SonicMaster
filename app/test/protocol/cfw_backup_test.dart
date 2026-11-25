import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/protocol/cfw_backup.dart';
import 'package:sonicmaster/protocol/sha256.dart';

import '../support/backup_fixtures.dart';

/// The one-record "SC" block captured from the pedal (AMP, SC1 p0 = 33.0).
final _sceneBlock = Uint8List.fromList([
  0x53, 0x43, 0x01, 0x01, 0x14, 0x00, 0xc3, 0xc2, //
  0x03, 0x01, 0x01, 0x00, 0x01, 0x00, 0x00, 0x07, 0x00, 0x00, 0x04, 0x42,
]);

CfwBackup _backup() => CfwBackup(
  created: DateTime.utc(2026, 11, 25, 18, 30),
  app: 'SonicMaster test',
  pedal: const BackupPedal(
    model: 'Pocket Master',
    cfwTag: 'CFW1.0.2',
    caps: 0xCFFF8F7F,
    irSlots: 10,
    cloneSlots: 10,
  ),
  sections: const {'presets': 'complete', 'scenes': 'complete'},
  presets: [
    BackupPreset(
      index: 0,
      record: testPresetRecord(
        'Ponty',
        effectIds: [0, 0, 0, 0x07000001, 0, 0, 0, 0, 0, 0],
      ),
      scenes: _sceneBlock,
      midiPedals: expBlockToMidiPedals(
        Uint8List.fromList([0, 0, 0, 0, 35, 0, ...List.filled(18, 0)]),
      ),
    ),
    BackupPreset(index: 1, record: testPresetRecord('Clean')),
  ],
  order: List.generate(50, (i) => i),
  globals: const {'globalVolume': 75, 'inputLevel': -3},
  globalsRaw: '8080F00B',
  cfwSettings: const {1: 3, 3: 1},
  globalEq: const [1, 0, 4, 0, 0, 0, 0, 50, 0, 100],
  irs: const [],
  clones: [
    BackupSlot(slot: 1, name: 'Randall', data: Uint8List(2696)..[0] = 7),
  ],
  midiMap: (options: 1, entries: Uint8List.fromList([1, 0, 0, 0, 0, 5, 0, 0])),
);

/// Recomputes the document checksum after a test edited [doc].
String _resign(Map<String, dynamic> doc) {
  doc['sha256'] = '';
  doc['sha256'] = sha256Hex(utf8.encode(canonicalJson(doc)));

  return jsonEncode(doc);
}

void main() {
  test('a backup survives the round trip through its file', () {
    final text = encodeCfwBackup(_backup());
    final (parsed, errors) = parseCfwBackup(text);

    expect(errors, isEmpty);
    expect(parsed, isNotNull);
    expect(encodeCfwBackup(parsed!), text);
    expect(parsed.presets[0].record, _backup().presets[0].record);
    expect(parsed.presets[0].scenes, _sceneBlock);
    expect(parsed.presets[1].scenes, isNull);
    expect(parsed.cfwSettings, {1: 3, 3: 1});
    expect(parsed.midiMap!.options, 1);
    expect(parsed.clones.single.data[0], 7);
  });

  test('the file has the CFW app layout', () {
    final doc = jsonDecode(encodeCfwBackup(_backup())) as Map<String, dynamic>;

    expect(doc['type'], 'sonicmaster-cfw-backup');
    expect(doc['format'], 1);
    expect(doc['pedal'], {
      'model': 'Pocket Master',
      'cfwTag': 'CFW1.0.2',
      'caps': '0xCFFF8F7F',
      'irSlots': 10,
      'cloneSlots': 10,
    });

    final p0 = (doc['presets'] as List)[0] as Map<String, dynamic>;
    final record = base64Decode(p0['record'] as String);

    expect(p0['label'], 'P01');
    expect(p0['name'], 'Ponty');
    expect(p0['sha256'], sha256Hex(record));
    expect(p0['scenesSha256'], sha256Hex(_sceneBlock));
    expect(base64Decode(p0['midiPedals'] as String), hasLength(26));
    expect((p0['summary'] as Map)['ids'], contains('0x07000001'));
    // "scenes" is always there, null when the preset has none.
    expect((doc['presets'] as List)[1], containsPair('scenes', null));
    expect(doc['order'], {
      'map': List.generate(50, (i) => i),
      'note': 'information only',
    });
    expect(doc['cfwSettings'], [
      {'id': 1, 'value': 3},
      {'id': 3, 'value': 1},
    ]);
    expect(doc['globalEq'], {
      'raw': [1, 0, 4, 0, 0, 0, 0, 50, 0, 100],
    });
    expect((doc['clones'] as List).single, containsPair('source', 'readback'));
    expect(doc['midiMap'], containsPair('count', 1));
    // The checksum covers the document with "sha256" blank, keys sorted.
    final copy = Map<String, dynamic>.of(doc)..['sha256'] = '';

    expect(doc['sha256'], sha256Hex(utf8.encode(canonicalJson(copy))));
  });

  test('a changed byte anywhere fails the document checksum', () {
    final doc = jsonDecode(encodeCfwBackup(_backup())) as Map<String, dynamic>;

    (doc['cfwSettings'] as List)[0]['value'] = 4;

    final (parsed, errors) = parseCfwBackup(jsonEncode(doc));

    expect(parsed, isNull);
    expect(errors, ['the file was changed or damaged (document checksum)']);
  });

  test('a preset whose record does not match its checksum is refused', () {
    final doc = jsonDecode(encodeCfwBackup(_backup())) as Map<String, dynamic>;
    final p1 = (doc['presets'] as List)[1] as Map<String, dynamic>;

    p1['record'] = base64Encode(testPresetRecord('Other'));

    final (parsed, errors) = parseCfwBackup(_resign(doc));

    expect(parsed, isNull);
    expect(errors, ['P02: checksum mismatch']);
  });

  test('a damaged record is refused', () {
    final doc = jsonDecode(encodeCfwBackup(_backup())) as Map<String, dynamic>;
    final p1 = (doc['presets'] as List)[1] as Map<String, dynamic>;
    final bad = Uint8List(494);

    p1['record'] = base64Encode(bad);
    p1['sha256'] = sha256Hex(bad);

    final (parsed, errors) = parseCfwBackup(_resign(doc));

    expect(parsed, isNull);
    expect(errors.single, startsWith('P02: '));
  });

  test('other files are refused', () {
    expect(parseCfwBackup('not json').$2, ['not a JSON file']);
    expect(parseCfwBackup('{"type": "preset"}').$2, [
      'not a Sonicake CFW backup file',
    ]);
    expect(
      parseCfwBackup('{"type": "sonicmaster-cfw-backup", "format": 3}').$2,
      ['backup format 3: made by a newer app version, update the app'],
    );
  });

  test('duplicate and out-of-range preset indices are refused', () {
    final doc = jsonDecode(encodeCfwBackup(_backup())) as Map<String, dynamic>;

    ((doc['presets'] as List)[1] as Map)['index'] = 0;

    expect(parseCfwBackup(_resign(doc)).$2, ['presets: bad index 0']);
  });

  group('preset record', () {
    test('name, effect ids and STOMP groups', () {
      final r = testPresetRecord(
        'Ponty',
        effectIds: List.generate(10, (i) => 100 + i),
        fs1: 5,
        fs2: 2,
      );

      expect(presetRecordError(r), isNull);
      expect(presetRecordName(r), 'Ponty');
      expect(presetRecordEffectIds(r), List.generate(10, (i) => 100 + i));
      expect(presetRecordStomp(r), (fs1: 5, fs2: 2));
      expect(presetRecordStomp(withoutStompGroups(r)), (fs1: 0, fs2: 0));
    });

    test('a record of the wrong size or header is damaged', () {
      expect(presetRecordError(Uint8List(10)), contains('10 bytes'));
      expect(presetRecordError(Uint8List(494)), isNotNull);
    });
  });

  group('preset writes', () {
    test('11 4F: slot u32 and the record without its FF header', () {
      final r = testPresetRecord('Ponty');
      final payload = presetWritePayload(7, r);

      expect(payload.sublist(0, 6), [0x11, 0x4F, 7, 0, 0, 0]);
      expect(payload.sublist(6), r.sublist(4));
    });

    test('11 34: record, EXP A-D and scenes in one write', () {
      final r = testPresetRecord(
        'Ponty',
        effectIds: [0, 0, 0, 0x07000001, 0, 0, 0, 0, 0, 0],
      );
      final exp = Uint8List.fromList([
        0,
        0,
        0,
        0,
        35,
        0,
        ...List.filled(18, 0),
      ]);
      final payload = presetWithScenesPayload(
        3,
        r,
        scenes: _sceneBlock,
        midiPedals: expBlockToMidiPedals(exp),
      );
      final recordEnd = 6 + r.length - 4;

      expect(payload.sublist(0, 6), [0x11, 0x34, 3, 0, 0x03, 0x01]);
      expect(payload.sublist(6, recordEnd), r.sublist(4));
      // A free slot is FF 00 00 00 00 00 (the zero-filled ones in [exp]
      // address NR param 0, a valid slot).
      expect(payload.sublist(recordEnd, recordEnd + 24), exp);
      // The scene record gets the record's effect id as its key.
      expect(payload.sublist(recordEnd + 24), [
        0x53, 0x43, 0x01, 0x01, 0x14, 0x00, 0xc3, 0xc2, //
        0x03, 0x01, 0x01, 0x00, 0x01, 0x00, 0x00, 0x07, 0x00, 0x00, 0x04, 0x42,
      ]);
    });

    test('11 34 with no scenes or EXP clears both', () {
      final r = testPresetRecord('Ponty');
      final payload = presetWithScenesPayload(0, r);
      final recordEnd = 6 + r.length - 4;

      expect(payload[4], 0x01);
      expect(payload.sublist(recordEnd, recordEnd + 6), [255, 0, 0, 0, 0, 0]);
      expect(payload.sublist(recordEnd + 24), [
        0x53, 0x43, 0x01, 0x00, 0x08, 0x00, 0xFF, 0xFF, //
      ]);
    });
  });

  test('scene blocks decode like the pedal checks them', () {
    expect(decodeSceneBlock(_sceneBlock).single.module, 3);
    // A wrong CRC makes the block empty, as in the CFW app.
    final bad = Uint8List.fromList(_sceneBlock)..[6] = 0;

    expect(decodeSceneBlock(bad), isEmpty);
  });

  test('midiPedals: "PD" with a byte checksum', () {
    // EXP A -> NR THRE 0..35 %, the rest free.
    final exp = Uint8List.fromList([
      0, 0, 0, 0, 35, 0, //
      for (var i = 0; i < 3; i++) ...[255, 0, 0, 0, 0, 0],
    ]);
    final mp = expBlockToMidiPedals(exp);

    expect(mp.sublist(0, 2), [0x50, 0x44 ^ ((35 + 3 * 255) & 0xFF)]);
    expect(midiPedalsToExpBlock(mp), exp);
    expect(isFreeExpBlock(exp), isFalse);
    // A bad check byte reads as no EXP, like the CFW app.
    expect(midiPedalsToExpBlock(Uint8List.fromList(mp)..[1] ^= 1), isNull);
    // Impossible slots (mode 8) are free.
    expect(
      isFreeExpBlock(
        Uint8List.fromList([
          for (var i = 0; i < 4; i++) ...[0, 0, 8, 0, 0, 0],
        ]),
      ),
      isTrue,
    );
  });
}
