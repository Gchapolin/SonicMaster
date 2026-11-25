import 'dart:convert';
import 'dart:typed_data';

import 'crc16_modbus.dart';
import 'sha256.dart';

/// The whole-pedal backup file of the CFW web app ("Back up now"): a JSON
/// document of type `sonicmaster-cfw-backup`, read from and written to the
/// layout of the CFW app's own code (main.dart.js, functions `afq` / `fH` /
/// `bca`), so a file made by either app restores in the other.
const cfwBackupType = 'sonicmaster-cfw-backup';

/// A preset record as the pedal stores it (`12 4F` reply after `12 4F`):
/// 494 bytes on the Pocket Master, 506 on the Smart Box.
const presetRecordLength = 494;
const _smartBoxRecordLength = 506;

/// IR data is 512 int32 taps; a Clone (User Profile) is a 2696-byte .clo.
const irDataLength = 2048;
const cloneDataLength = 2696;

/// What the file says about the pedal it was made on.
class BackupPedal {
  const BackupPedal({
    required this.model,
    this.cfwTag,
    this.caps,
    this.irSlots = 5,
    this.cloneSlots = 5,
    this.edition,
  });

  final String model;
  final String? cfwTag;
  final int? caps;
  final int irSlots;
  final int cloneSlots;

  /// `nam` for the NAM CFW, `cfw` or null for the normal one.
  final String? edition;

  /// Whether the file comes from the NAM CFW (the CFW app's `gqB`).
  bool get isNam => edition == null ? isNamTag(cfwTag ?? '') : edition == 'nam';
}

/// The CFW app's NAM-edition test on a version tag (`aaw`).
bool isNamTag(String tag) {
  final t = tag.trim().toUpperCase();

  return t.startsWith('NAM') || t.contains('-NAM');
}

class BackupPreset {
  const BackupPreset({
    required this.index,
    required this.record,
    this.scenes,
    this.midiPedals,
  });

  /// 0..49 (P01..P50).
  final int index;
  final Uint8List record;

  /// The preset's "SC" scene block (`12 34 <slot>` reply), null when none.
  final Uint8List? scenes;

  /// EXP A-D: `50 <44 ^ sum> <24 bytes>`, null when the preset has none.
  final Uint8List? midiPedals;

  String get label => presetLabel(index);
}

/// User IR or User Profile data read back from a slot.
class BackupSlot {
  const BackupSlot({
    required this.slot,
    required this.name,
    required this.data,
  });

  /// 1-based.
  final int slot;
  final String name;
  final Uint8List data;
}

class CfwBackup {
  const CfwBackup({
    required this.created,
    required this.app,
    required this.pedal,
    required this.sections,
    required this.presets,
    this.order,
    this.globals,
    this.globalsRaw,
    this.cfwSettings = const {},
    this.globalEq,
    this.irs = const [],
    this.clones = const [],
    this.midiMap,
    this.namModels,
  });

  final DateTime created;
  final String app;
  final BackupPedal pedal;

  /// Section name -> complete / none / unavailable / partial.
  final Map<String, String> sections;
  final List<BackupPreset> presets;

  /// The preset order table (information only, never restored).
  final List<int>? order;

  /// The decoded global settings (names as in [GlobalSettings]) and the raw
  /// `12 10` frame they came from.
  final Map<String, int>? globals;
  final String? globalsRaw;
  final Map<int, int> cfwSettings;

  /// The 10 bytes after `12 3A`.
  final List<int>? globalEq;
  final List<BackupSlot> irs;
  final List<BackupSlot> clones;

  /// The custom MIDI map: header options and the rows (8 bytes each).
  final ({int options, Uint8List entries})? midiMap;

  /// The NAM CFW's models, kept as read (this app does not restore them).
  final Object? namModels;
}

String presetLabel(int index) => 'P${'${index + 1}'.padLeft(2, '0')}';

String _hex8(int v) => '0x${v.toRadixString(16).padLeft(8, '0')}';

/// The document the CFW app writes, in its key order, without the checksum.
Map<String, Object?> _toJson(CfwBackup b) => {
  'type': cfwBackupType,
  'format': b.pedal.isNam ? 2 : 1,
  'created': b.created.toUtc().toIso8601String(),
  'app': b.app,
  'pedal': {
    'model': b.pedal.model,
    'cfwTag': b.pedal.cfwTag,
    'caps': b.pedal.caps == null
        ? null
        : '0x${b.pedal.caps!.toRadixString(16).toUpperCase()}',
    'irSlots': b.pedal.irSlots,
    'cloneSlots': b.pedal.cloneSlots,
    if (b.pedal.edition != null) 'edition': b.pedal.edition,
  },
  'sections': b.sections,
  'presets': [
    for (final p in b.presets)
      {
        'index': p.index,
        'label': p.label,
        'name': presetRecordName(p.record),
        'record': base64Encode(p.record),
        'sha256': sha256Hex(p.record),
        'scenes': p.scenes == null ? null : base64Encode(p.scenes!),
        if (p.scenes != null) 'scenesSha256': sha256Hex(p.scenes!),
        if (p.midiPedals != null) 'midiPedals': base64Encode(p.midiPedals!),
        if (p.midiPedals != null) 'midiPedalsSha256': sha256Hex(p.midiPedals!),
        'summary': {
          'ids': [for (final id in presetRecordEffectIds(p.record)) _hex8(id)],
          'fs1': presetRecordStomp(p.record).fs1,
          'fs2': presetRecordStomp(p.record).fs2,
        },
      },
  ],
  'order': b.order == null
      ? null
      : {'map': b.order, 'note': 'information only'},
  'globals': b.globals == null
      ? null
      : {'decoded': b.globals, 'raw12_10': b.globalsRaw},
  'cfwSettings': [
    for (final e in b.cfwSettings.entries) {'id': e.key, 'value': e.value},
  ],
  'globalEq': b.globalEq == null ? null : {'raw': b.globalEq},
  'irs': [for (final s in b.irs) _slotJson(s, 'taps')],
  'clones': [for (final s in b.clones) _slotJson(s, 'clo')],
  if (b.midiMap case final m?)
    'midiMap': {
      'options': m.options & 3,
      'count': m.entries.length ~/ 8,
      'entries': base64Encode(m.entries),
      'sha256': sha256Hex(m.entries),
    },
  if (b.namModels != null) 'namModels': b.namModels,
};

Map<String, Object?> _slotJson(BackupSlot s, String key) => {
  'slot': s.slot,
  'name': s.name,
  key: base64Encode(s.data),
  'sha256': sha256Hex(s.data),
  'source': 'readback',
};

/// [value] with every map's keys sorted, encoded compactly: the text the
/// document checksum covers (the CFW app's `bik`).
String canonicalJson(Object? value) {
  Object? sorted(Object? v) => switch (v) {
    final Map<dynamic, dynamic> m => {
      for (final k in (m.keys.map((k) => '$k').toList()..sort()))
        k: sorted(m[k]),
    },
    final List<dynamic> l => [for (final e in l) sorted(e)],
    _ => v,
  };

  return jsonEncode(sorted(value));
}

/// The backup file's text: the document, then its checksum over the
/// canonical form with `"sha256": ""` (indented by one space, like the CFW
/// app).
String encodeCfwBackup(CfwBackup b) {
  final doc = _toJson(b);

  doc['sha256'] = '';
  doc['sha256'] = sha256Hex(utf8.encode(canonicalJson(doc)));

  return const JsonEncoder.withIndent(' ').convert(doc);
}

/// `sonicake-cfw-backup-<tag>-<yyyymmdd>-<hhmm>.smbackup.json`, local time.
String cfwBackupFileName(CfwBackup b, {String suffix = ''}) {
  final t = b.created.toLocal();
  String two(int v) => '$v'.padLeft(2, '0');
  final tag = (b.pedal.cfwTag ?? 'stock').replaceAll(
    RegExp('[^A-Za-z0-9.]'),
    '',
  );

  return 'sonicake-cfw-backup-$tag-${t.year}${two(t.month)}${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}$suffix.smbackup.json';
}

/// Parses and checks a backup file like the CFW app (`bca`): any problem
/// refuses the whole file, with the CFW app's messages.
(CfwBackup?, List<String>) parseCfwBackup(String text) {
  final errors = <String>[];
  Object? decoded;

  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return (null, const ['not a JSON file']);
  }

  if (decoded is! Map<String, dynamic> || decoded['type'] != cfwBackupType) {
    return (null, const ['not a Sonicake CFW backup file']);
  }

  final doc = decoded;
  final format = doc['format'];

  if (format is! int || format > 2) {
    return (
      null,
      ['backup format $format: made by a newer app version, update the app'],
    );
  }

  final sum = doc['sha256'];

  if (sum is! String ||
      sum != sha256Hex(utf8.encode(canonicalJson({...doc, 'sha256': ''})))) {
    errors.add('the file was changed or damaged (document checksum)');
  }

  Uint8List? blob(Object? data, Object? sha, String label) {
    if (data is! String) {
      errors.add('$label: missing data');

      return null;
    }

    try {
      final bytes = base64Decode(data);

      if (sha != sha256Hex(bytes)) errors.add('$label: checksum mismatch');

      return bytes;
    } on FormatException {
      errors.add('$label: not base64');

      return null;
    }
  }

  final presets = <BackupPreset>[];
  final seen = <int>{};

  for (final e in (doc['presets'] as List?) ?? const []) {
    if (e is! Map) {
      errors.add('presets: bad entry');
      continue;
    }

    final index = e['index'];

    if (index is! int || index < 0 || index >= 50 || !seen.add(index)) {
      errors.add('presets: bad index $index');
      continue;
    }

    final label = presetLabel(index);
    final record = blob(e['record'], e['sha256'], label);
    final scenes = e['scenes'] == null
        ? null
        : blob(e['scenes'], e['scenesSha256'], '$label scenes');
    final pedals = e['midiPedals'] == null
        ? null
        : blob(e['midiPedals'], e['midiPedalsSha256'], '$label EXP A–D');

    if (pedals != null && pedals.length != 26) {
      errors.add('$label EXP A–D: ${pedals.length} bytes');
    }

    if (record == null) continue;

    if (presetRecordError(record) case final err?) {
      errors.add('$label: $err');
      continue;
    }

    presets.add(
      BackupPreset(
        index: index,
        record: record,
        scenes: scenes,
        midiPedals: pedals,
      ),
    );
  }

  List<BackupSlot> slots(String section, bool isIr) {
    final out = <BackupSlot>[];

    for (final e in (doc[section] as List?) ?? const []) {
      final slot = e is Map ? e['slot'] : null;

      if (e is! Map || slot is! int || slot < 1 || slot > 10) {
        errors.add('$section: bad slot $slot');
        continue;
      }

      final label = '${isIr ? 'User IR' : 'User Profile'} $slot';
      final data = blob(e[isIr ? 'taps' : 'clo'], e['sha256'], label);
      final expected = isIr ? irDataLength : cloneDataLength;

      if (data == null) continue;

      if (data.length != expected) {
        errors.add('$label: ${data.length} bytes (expected $expected)');
        continue;
      }

      out.add(BackupSlot(slot: slot, name: '${e['name'] ?? ''}', data: data));
    }

    return out;
  }

  final irs = slots('irs', true);
  final clones = slots('clones', false);
  final pedal = doc['pedal'] is Map ? doc['pedal'] as Map : const {};
  final caps = pedal['caps'] is String
      ? int.tryParse((pedal['caps'] as String).replaceAll('0x', ''), radix: 16)
      : null;
  final orderJson = doc['order'] is Map ? (doc['order'] as Map)['map'] : null;
  final globalsJson = doc['globals'] is Map
      ? (doc['globals'] as Map)['decoded']
      : null;
  final geqJson = doc['globalEq'] is Map
      ? (doc['globalEq'] as Map)['raw']
      : null;
  final mapJson = doc['midiMap'];
  ({int options, Uint8List entries})? midiMap;

  if (mapJson is Map) {
    final entries = blob(
      mapJson['entries'],
      mapJson['sha256'],
      'Custom MIDI map',
    );
    final options = mapJson['options'];

    if (options is! int || options < 0 || options > 3) {
      errors.add('Custom MIDI map: bad options $options');
    } else if (entries != null) {
      if (entries.length % 8 != 0 || entries.length ~/ 8 > 64) {
        errors.add('Custom MIDI map: ${entries.length} bytes');
      } else {
        midiMap = (options: options, entries: entries);
      }
    }
  } else if (mapJson != null) {
    errors.add('Custom MIDI map: not an object');
  }

  final cfwSettings = <int, int>{};

  for (final e in (doc['cfwSettings'] as List?) ?? const []) {
    if (e is Map && e['id'] is int && e['value'] is int) {
      cfwSettings[e['id'] as int] = e['value'] as int;
    } else {
      errors.add('cfwSettings: bad entry');
    }
  }

  if (orderJson != null &&
      (orderJson is! List ||
          orderJson.length != 50 ||
          orderJson.any((v) => v is! int))) {
    errors.add('order: not 50 indices');
  }

  if (geqJson != null &&
      (geqJson is! List || geqJson.any((v) => v is! int || v < 0 || v > 255))) {
    errors.add('globalEq: bad payload');
  }

  if (globalsJson != null &&
      (globalsJson is! Map || globalsJson.values.any((v) => v is! int))) {
    errors.add('globals: bad values');
  }

  final nam = doc['namModels'];

  if (nam != null && nam is! Map) errors.add('NAM models: not an object');

  final edition = pedal['edition'];

  if (edition != null && edition != 'nam' && edition != 'cfw') {
    errors.add('pedal: edition $edition');
  }

  if (errors.isNotEmpty) return (null, errors);

  presets.sort((a, b) => a.index.compareTo(b.index));

  final globalsMap = doc['globals'] is Map ? doc['globals'] as Map : null;

  return (
    CfwBackup(
      created:
          DateTime.tryParse('${doc['created']}') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      app: '${doc['app'] ?? ''}',
      pedal: BackupPedal(
        model: pedal['model'] is String
            ? pedal['model'] as String
            : 'Pocket Master',
        cfwTag: pedal['cfwTag'] is String ? pedal['cfwTag'] as String : null,
        caps: caps,
        irSlots: pedal['irSlots'] is int ? pedal['irSlots'] as int : 5,
        cloneSlots: pedal['cloneSlots'] is int ? pedal['cloneSlots'] as int : 5,
        edition: edition as String?,
      ),
      sections: {
        if (doc['sections'] is Map)
          for (final e in (doc['sections'] as Map).entries)
            '${e.key}': '${e.value}',
      },
      presets: presets,
      order: orderJson == null ? null : List<int>.from(orderJson as List),
      globals: globalsJson == null
          ? null
          : {
              for (final e in (globalsJson as Map).entries)
                '${e.key}': e.value as int,
            },
      globalsRaw: globalsMap?['raw12_10'] as String?,
      cfwSettings: cfwSettings,
      globalEq: geqJson == null ? null : List<int>.from(geqJson as List),
      irs: irs,
      clones: clones,
      midiMap: midiMap,
      namModels: nam,
    ),
    const <String>[],
  );
}

// --- Preset records ---------------------------------------------------------

/// Walks the record's groups and tags; null when the layout holds, else why
/// not (the checks of the CFW app's record parser `cD` that the restore
/// relies on).
String? presetRecordError(Uint8List r) {
  if (r.length != presetRecordLength && r.length != _smartBoxRecordLength) {
    return 'preset record: ${r.length} bytes (expected 494, Smart Box 506)';
  }

  final tags = _tags(r);

  if (tags == null) return 'preset record: bad layout';

  int? u32(int tag) {
    final d = tags[tag];

    return d == null || d.length != 4 ? null : _u32(d, 0);
  }

  if (u32(0x0002) != 0x514D450A) return 'preset record: not a preset';
  if (u32(0x1001) != 10 || u32(0x1002) != 8) {
    return 'preset record: unknown layout';
  }
  if (_group3(r) == null) return 'preset record: no STOMP groups';
  if (tags[0x3003]?.length != 40) return 'preset record: no effect ids';
  if (tags[0x3002]?.length != 10) return 'preset record: no chain order';

  final params = tags[0x3004];

  if (params == null || params.length != 320) {
    return 'preset record: no parameters';
  }

  final bd = ByteData.sublistView(params);

  for (var i = 0; i < 80; i++) {
    if (!bd.getFloat32(4 * i, Endian.little).isFinite) {
      return 'preset record: a parameter is not a number';
    }
  }

  final mask = u32(0x3001);

  if (mask == null || mask >> 10 != 0) return 'preset record: enable mask';

  return null;
}

int _u16(List<int> b, int at) => b[at] | (b[at + 1] << 8);

int _u32(List<int> b, int at) =>
    b[at] | (b[at + 1] << 8) | (b[at + 2] << 16) | (b[at + 3] << 24);

/// Tag -> data of every tag in the record's groups (groups 3 and the Smart
/// Box's 4 hold raw bytes, not tags); null when the walk does not end
/// exactly at the end.
Map<int, Uint8List>? _tags(Uint8List r) {
  if (r.length < 20 || _u32(r, 0) != 0xFFFFFFFF) return null;

  final out = <int, Uint8List>{};
  var at = 20;

  while (at + 4 <= r.length) {
    final id = _u16(r, at);
    final end = at + 4 + _u16(r, at + 2);

    if (end > r.length) return null;

    if (id != 3 && !(id == 4 && r.length == _smartBoxRecordLength)) {
      var k = at + 4;

      while (k + 4 <= end) {
        final dataEnd = k + 4 + _u16(r, k + 2);

        if (dataEnd > end) return null;

        out[_u16(r, k)] = Uint8List.sublistView(r, k + 4, dataEnd);
        k = dataEnd;
      }

      if (k != end) return null;
    }

    at = end;
  }

  return at == r.length ? out : null;
}

/// Offset of group 3's 8 bytes (the STOMP groups), null if absent.
int? _group3(Uint8List r) {
  var at = 20;

  while (at + 4 <= r.length) {
    final len = _u16(r, at + 2);

    if (_u16(r, at) == 3) return len == 8 ? at + 4 : null;

    at += 4 + len;
  }

  return null;
}

/// The preset name (bytes 4..20, zero bytes dropped).
String presetRecordName(Uint8List r) => r.length < 20
    ? ''
    : String.fromCharCodes(r.sublist(4, 20).where((b) => b != 0));

/// The ten effect ids (tag 0x3003), module order.
List<int> presetRecordEffectIds(Uint8List r) {
  final d = _tags(r)?[0x3003];

  return d == null || d.length != 40
      ? const []
      : [for (var i = 0; i < 10; i++) _u32(d, 4 * i)];
}

/// The STOMP groups: modules on FS1 / FS2 (bitmasks).
({int fs1, int fs2}) presetRecordStomp(Uint8List r) {
  final at = _group3(r);

  return at == null
      ? (fs1: 0, fs2: 0)
      : (fs1: _u32(r, at), fs2: _u32(r, at + 4));
}

/// [r] with both STOMP groups cleared (the CFW app's `Mz(0, 0)`, for
/// firmware without capability bit 10).
Uint8List withoutStompGroups(Uint8List r) {
  final out = Uint8List.fromList(r);
  final at = _group3(out);

  if (at != null) out.fillRange(at, at + 8, 0);

  return out;
}

/// Offset of the 80 parameter floats (after the tag `04 30 40 01`).
int? presetRecordParamsOffset(Uint8List r) {
  for (var i = 0; i + 4 <= r.length; i++) {
    if (r[i] == 0x04 && r[i + 1] == 0x30 && r[i + 2] == 0x40 && r[i + 3] == 1) {
      return i + 4;
    }
  }

  return null;
}

// --- Writes -----------------------------------------------------------------

/// `11 4F <slot u32 LE> <record without its FF FF FF FF>`: writes one stored
/// preset (the CFW app's `Cq`; the pedal acks every packet and then
/// notifies `12 1B 02`).
Uint8List presetWritePayload(int slot, Uint8List record) => Uint8List.fromList([
  0x11,
  0x4F,
  slot & 0xFF,
  0,
  0,
  0,
  ...record.sublist(4),
]);

/// `11 34 <slot u16 LE> <flags> <device> <record without FF..>`
/// `<EXP A-D 24 B> <scene block>`: a stored preset with its scenes and EXP A-D in one write
/// (the CFW app's `lh`, used when capability word 2 has bit 11). flags: bit0
/// always, bit1 when scenes or EXP are set; device 1 Pocket Master.
/// No [scenes] / [midiPedals] clears them.
Uint8List presetWithScenesPayload(
  int slot,
  Uint8List record, {
  Uint8List? scenes,
  Uint8List? midiPedals,
}) {
  final ids = presetRecordEffectIds(record);
  final sceneRecords = _normalizedScenes(scenes, ids);
  final exp = midiPedals == null
      ? _freeExp
      : (midiPedalsToExpBlock(midiPedals) ?? _freeExp);
  final hasExp = !_isFreeExp(exp);

  return Uint8List.fromList([
    0x11,
    0x34,
    slot & 0xFF,
    (slot >> 8) & 0xFF,
    (sceneRecords.isNotEmpty || hasExp ? 2 : 0) | 1,
    1,
    ...record.sublist(4),
    ...exp,
    ...encodeSceneBlock(sceneRecords),
  ]);
}

// --- Scene blocks -----------------------------------------------------------

/// One scene record as the "SC" block carries it.
class BlockScene {
  const BlockScene({
    required this.module,
    required this.flags,
    required this.sc1Mask,
    required this.sc2Mask,
    required this.key,
    required this.values,
  });

  final int module;

  /// bit0 in scenes, bits 1-4 the on/off overrides, bit7 a pedal-side flag.
  final int flags;
  final int sc1Mask;
  final int sc2Mask;

  /// The effect id the record belongs to (pedal-filled).
  final int key;

  /// The float32 values, raw (4 bytes each).
  final Uint8List values;
}

/// Decodes an "SC" block: `53 43 <version 1|2> <count> <total u16 LE>`
/// `<CRC-16/MODBUS of the records u16 LE>`, then the records. Anything that
/// fails those checks is no scenes at all, as in the CFW app (`b83`).
List<BlockScene> decodeSceneBlock(Uint8List? s) {
  if (s == null || s.length < 8) return const [];

  final total = _u16(s, 4);

  if (_u16(s, 0) != 0x4353 ||
      (s[2] != 1 && s[2] != 2) ||
      total < 8 ||
      total > 616 ||
      total > s.length ||
      _u16(s, 6) != Crc16Modbus.ofBytes(s.sublist(8, total))) {
    return const [];
  }

  final out = <BlockScene>[];
  final seen = <int>{};
  var at = 8;

  for (var i = 0; i < s[3]; i++) {
    final valuesAt = at + 8;

    if (valuesAt > total) break;

    final n = _bits(s[at + 2]) + _bits(s[at + 3]);

    if (valuesAt + 4 * n > total) break;

    final module = s[at];

    if (module < 10 && seen.add(module)) {
      out.add(
        BlockScene(
          module: module,
          flags: s[at + 1],
          sc1Mask: s[at + 2],
          sc2Mask: s[at + 3],
          key: _u32(s, at + 4),
          values: Uint8List.fromList(s.sublist(valuesAt, valuesAt + 4 * n)),
        ),
      );
    }

    at = valuesAt + 4 * n;
  }

  return out;
}

/// The block of [records], sorted by module, as the CFW app writes it (`rx`).
Uint8List encodeSceneBlock(List<BlockScene> records) {
  final sorted = [...records]..sort((a, b) => a.module.compareTo(b.module));
  final body = <int>[
    for (final r in sorted) ...[
      r.module,
      r.flags,
      r.sc1Mask,
      r.sc2Mask,
      r.key & 0xFF,
      (r.key >> 8) & 0xFF,
      (r.key >> 16) & 0xFF,
      (r.key >> 24) & 0xFF,
      ...r.values,
    ],
  ];
  final crc = Crc16Modbus.ofBytes(body);
  final total = 8 + body.length;

  return Uint8List.fromList([
    0x53,
    0x43,
    sorted.any((r) => r.flags & 0x0A != 0) ? 2 : 1,
    sorted.length,
    total & 0xFF,
    total >> 8,
    crc & 0xFF,
    crc >> 8,
    ...body,
  ]);
}

/// The scenes of [block] that belong to the record's effects (a non-zero key
/// must match the module's effect id; IR and Clone compare the id's high
/// byte only), re-keyed with that id and without the pedal-side flag: what
/// the CFW app writes back (`aa2` + `axy`).
List<BlockScene> _normalizedScenes(Uint8List? block, List<int> ids) => [
  for (final r in decodeSceneBlock(block))
    if (r.module < ids.length &&
        (r.key == 0 ||
            ((r.module == 4 || r.module == 9)
                ? r.key >> 24 == ids[r.module] >> 24
                : r.key == ids[r.module])))
      BlockScene(
        module: r.module,
        flags: r.flags & 0x1F,
        sc1Mask: r.sc1Mask,
        sc2Mask: r.sc2Mask,
        key: ids[r.module],
        values: r.values,
      ),
];

/// [block] as the pedal stores it for [record]: for comparing a read-back.
Uint8List normalizedSceneBlock(Uint8List? block, Uint8List record) =>
    encodeSceneBlock(_normalizedScenes(block, presetRecordEffectIds(record)));

/// Whether [block] has scene records for [record]'s effects.
bool hasScenes(Uint8List? block, Uint8List record) =>
    _normalizedScenes(block, presetRecordEffectIds(record)).isNotEmpty;

/// Whether the preset's scenes leave room for EXP A-D (616 bytes in all,
/// the CFW app's `bq9`).
bool hasRoomForExp(Uint8List? block, Uint8List record) {
  final records = _normalizedScenes(block, presetRecordEffectIds(record));

  return 616 - (records.isEmpty ? 0 : encodeSceneBlock(records).length) >= 26;
}

int _bits(int mask) {
  var n = 0;

  for (var m = mask & 0xFF; m != 0; m &= m - 1) {
    n++;
  }

  return n;
}

// --- EXP A-D ----------------------------------------------------------------

final _freeExp = Uint8List.fromList([
  for (var i = 0; i < 4; i++) ...[255, 0, 0, 0, 0, 0],
]);

bool _isFreeExp(Uint8List exp) {
  for (var i = 0; i < 24; i += 6) {
    if (exp[i] != 255) return false;
  }

  return true;
}

/// The four 6-byte slots as the CFW app keeps them (`b81` + `Gm`): a slot
/// with an impossible module / knob / mode is free, min and max are clamped.
Uint8List _normalizeExp(List<int> b, int at) => Uint8List.fromList([
  for (var i = 0; i < 4; i++)
    ...switch (b.sublist(at + 6 * i, at + 6 * i + 6)) {
      final s when s[0] == 255 || s[0] > 9 || s[1] > 7 || s[2] > 2 => const [
        255,
        0,
        0,
        0,
        0,
        0,
      ],
      final s => [s[0], s[1], s[2], s[3].clamp(0, 100), s[4].clamp(0, 100), 0],
    },
]);

/// `50 <0x44 ^ byte sum> <24 bytes>`: a preset's EXP A-D as the backup file
/// stores it (`bJa`). [exp] is the 24 bytes of a `12 3D` reply.
Uint8List expBlockToMidiPedals(Uint8List exp) {
  final n = _normalizeExp(exp, 0);

  return Uint8List.fromList([
    0x50,
    0x44 ^ (n.fold(0, (a, b) => a + b) & 0xFF),
    ...n,
  ]);
}

/// The 24 bytes of [midiPedals]; null when its check byte is wrong (the CFW
/// app then treats the slots as free).
Uint8List? midiPedalsToExpBlock(Uint8List midiPedals) {
  if (midiPedals.length < 26) return null;

  final body = midiPedals.sublist(2, 26);

  if (midiPedals[0] != 0x50 ||
      midiPedals[1] != (0x44 ^ (body.fold(0, (a, b) => a + b) & 0xFF))) {
    return null;
  }

  return _normalizeExp(body, 0);
}

/// Whether the 24 EXP bytes [exp] hold no assignment.
bool isFreeExpBlock(Uint8List exp) => _isFreeExp(_normalizeExp(exp, 0));
