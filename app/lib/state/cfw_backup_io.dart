import 'dart:typed_data';

import '../device/device_service.dart';
import '../model/cfw_info.dart';
import '../model/command_library.dart';
import '../model/midi_map.dart';
import '../protocol/cfw_backup.dart';
import '../protocol/cfw_midi_map_codec.dart';
import '../protocol/cfw_preset_order_codec.dart';
import '../protocol/cfw_settings_decoder.dart';
import '../protocol/global_setting_writer.dart';
import '../protocol/global_settings_decoder.dart';
import 'preset_providers.dart' show globalSettingAddress;

/// Whole-pedal backup and restore, ported from the CFW web app's "Back up
/// now" / "Restore…" (main.dart.js: `f0` reads, `bqj` plans, `de` writes).
/// The register layouts are in docs/cfw-protocol/capture-notes.md.

/// A read the backup needs did not come: nothing is saved.
class CfwBackupException implements Exception {
  const CfwBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// [step] is what is being done, [done] of [total] steps.
typedef BackupProgress = void Function(String step, int done, int total);

// Capability bits of the `12 2A` block, as the CFW app tests them.
const _capIrSlots10 = 0x2;
const _capCloneSlots10 = 0x4;
const _capStompGroups = 0x400;
const _capScenes = 0x8000;
const _capOrder = 0x10000;
const _capGlobalEq = 0x40000;
const _capSlotData = 0x200000;
const _capExp = 0x1000000;
const _caps2OneWrite = 0x800;
const _caps2Nam = 0x1000;

/// CFW settings the backup leaves out: 0x0F and the live scene (0x10).
const _volatileSettings = {0x0F, 0x10};

const _model = 'Pocket Master';

/// Whether [info] is the NAM edition of the CFW (the CFW app's `hC`).
bool isNamPedal(CfwInfo info) =>
    info.extraCapabilities & _caps2Nam != 0 || isNamTag(info.version);

List<int> _payload(String hex) => collapseFrame(hex)!.sublist(4);

/// Up to three tries of a read, like the CFW app; null when none answered
/// with a payload [isValid] accepts.
Future<String?> _read(
  DeviceService s,
  List<int> request,
  List<int> prefix, {
  bool Function(List<int> payload)? isValid,
}) async {
  for (var i = 0; i < 3; i++) {
    final hex = await s.requestCfwBlock(request, prefix);

    if (hex != null && (isValid == null || isValid(_payload(hex)))) return hex;
  }

  return null;
}

Future<Uint8List?> _readRecord(DeviceService s, int slot) async {
  final hex = await _read(
    s,
    [0x12, 0x4F, slot, 0, 0, 0],
    [0x12, 0x4F],
    isValid: (p) => presetRecordError(Uint8List.fromList(p.sublist(2))) == null,
  );

  return hex == null ? null : Uint8List.fromList(_payload(hex).sublist(2));
}

/// The preset's "SC" scene block (`12 34 <slot>`); throws when unread.
Future<Uint8List> _readScenes(DeviceService s, int slot) async {
  final hex = await _read(s, [0x12, 0x34, slot], [0x12, 0x34, slot]);

  if (hex == null) {
    throw CfwBackupException(
      '${presetLabel(slot)}: no scene read-back (12 34)',
    );
  }

  return Uint8List.fromList(_payload(hex).sublist(3));
}

/// `12 3D <slot>` -> `12 3D 01 <flags> <24 bytes>`: flags bit7 = per-preset
/// EXP supported, bit2 = no room (its scenes use it).
Future<({int flags, Uint8List exp})> _readExp(DeviceService s, int slot) async {
  final hex = await _read(
    s,
    [0x12, 0x3D, slot],
    [0x12, 0x3D],
    isValid: (p) => p.length >= 28 && p[2] == 1,
  );

  if (hex == null) {
    throw CfwBackupException(
      '${presetLabel(slot)}: no EXP A–D read-back (12 3D)',
    );
  }

  final p = _payload(hex);

  return (flags: p[3], exp: Uint8List.fromList(p.sublist(4, 28)));
}

/// The custom MIDI map: summary, then pages of eight rows.
Future<({int options, Uint8List entries})> _readMidiMap(DeviceService s) async {
  const fail = CfwBackupException(
    'Custom MIDI map: no answer from the pedal (12 39)',
  );
  final infoHex = await _read(
    s,
    [0x12, 0x39, 0],
    [0x12, 0x39, 0],
    isValid: (p) => p.length >= 15,
  );
  final info = infoHex == null ? null : decodeMidiMapInfo(infoHex);

  if (info == null || info.count > MidiMapEntry.maxEntries) throw fail;

  final rows = <int>[];

  while (rows.length < info.count * 8) {
    final first = rows.length ~/ 8;
    final hex = await _read(s, [0x12, 0x39, 1, first], [0x12, 0x39, 1, first]);
    final page = hex == null ? null : decodeMidiMapPage(hex);

    if (page == null || page.entries.isEmpty) throw fail;

    for (final e in page.entries.take(info.count - first)) {
      rows.addAll(e.toBytes());
    }
  }

  return (options: info.options & 3, entries: Uint8List.fromList(rows));
}

/// One User IR (kind 1) or Clone (kind 0) slot's data in 460-byte chunks
/// (`12 38 <kind> <slot-1> <chunk>` -> `… <status> <len u16> <data>`); null
/// when the pedal says the slot is empty.
Future<Uint8List?> _readSlotData(
  DeviceService s,
  int kind,
  int slot,
  int length,
) async {
  final label = '${kind == 1 ? 'User IR' : 'User Profile'} $slot';
  final out = BytesBuilder();

  for (var chunk = 0; chunk < (length + 459) ~/ 460; chunk++) {
    final request = [0x12, 0x38, kind, slot - 1, chunk];
    List<int>? reply;

    // A busy pedal answers status 3 / 4: asked again a few times.
    for (var busy = 0; busy < 7; busy++) {
      final hex = await _read(
        s,
        request,
        request,
        isValid: (p) => p.length >= 8 && p.length >= 8 + (p[6] | p[7] << 8),
      );

      if (hex == null) {
        throw CfwBackupException('$label: no read-back (12 38 chunk $chunk)');
      }

      reply = _payload(hex);

      if (reply[5] != 3 && reply[5] != 4) break;

      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    final status = reply![5];

    if (status == 1) return null;

    if (status != 0) {
      throw CfwBackupException('$label: read-back status $status');
    }

    out.add(reply.sublist(8, 8 + (reply[6] | reply[7] << 8)));
  }

  final data = out.takeBytes();

  if (data.length != length) {
    throw CfwBackupException('$label: ${data.length} bytes read back');
  }

  return data;
}

/// Reads the whole pedal the way the CFW app's "Back up now" does, in its
/// order: the 50 stored User presets (`12 4F`), each one's scenes (`12 34`)
/// and EXP A-D (`12 3D`), the custom MIDI map (`12 39`), the CFW settings
/// (`12 2A`), the Global EQ (`12 3A`), the preset order (`12 37`), the User
/// IR and Clone data (`12 28` / `12 29`, `12 38`) and the global settings
/// (`12 10`). A failed read throws [CfwBackupException].
Future<CfwBackup> readPedalBackup(
  DeviceService s,
  CfwInfo info, {
  required String app,
  BackupProgress? onProgress,
  DateTime? now,
}) async {
  if (isNamPedal(info)) {
    throw const CfwBackupException(
      'backups of the NAM CFW are not supported by SonicMaster yet',
    );
  }

  final caps = info.capabilities;
  final hasSlotData = caps & _capSlotData != 0;
  final hasScenes = hasSlotData && caps & _capScenes != 0;
  final hasExp = caps & _capExp != 0;
  final irSlots = caps & _capIrSlots10 != 0 ? 10 : 5;
  final cloneSlots = caps & _capCloneSlots10 != 0 ? 10 : 5;
  final total =
      50 +
      (hasScenes ? 50 : 0) +
      (hasExp ? 51 : 0) +
      (hasSlotData ? irSlots + cloneSlots : 0) +
      4;
  var done = 0;
  void step(String what) => onProgress?.call(what, ++done, total);

  final records = <Uint8List>[];

  for (var slot = 0; slot < 50; slot++) {
    final r = await _readRecord(s, slot);

    if (r == null) {
      throw CfwBackupException(
        '${presetLabel(slot)}: no answer from the pedal (12 4F)',
      );
    }

    records.add(r);
    step('Reading preset ${presetLabel(slot)}');
  }

  final presets = <BackupPreset>[];
  var isExpSupported = hasExp;

  for (var slot = 0; slot < 50; slot++) {
    Uint8List? scenes;
    Uint8List? midiPedals;

    if (hasScenes) {
      final block = await _readScenes(s, slot);

      scenes = decodeSceneBlock(block).isEmpty ? null : block;
      step('Reading the scenes of ${presetLabel(slot)}');
    }

    if (isExpSupported) {
      final r = await _readExp(s, slot);

      if (r.flags & 0x80 == 0) {
        isExpSupported = false;
      } else if (r.flags & 0x04 == 0 && !isFreeExpBlock(r.exp)) {
        midiPedals = expBlockToMidiPedals(r.exp);
      }

      step('Reading EXP A–D of ${presetLabel(slot)}');
    }

    presets.add(
      BackupPreset(
        index: slot,
        record: records[slot],
        scenes: scenes,
        midiPedals: midiPedals,
      ),
    );
  }

  final midiMap = hasExp ? await _readMidiMap(s) : null;

  if (hasExp) step('Reading the Custom MIDI map');

  final settingsHex = await _read(s, [0x12, 0x2A], [0x12, 0x2A]);
  final fresh = settingsHex == null
      ? null
      : decodeCfwSettingsFrame(settingsHex);
  final cfwSettings = {
    for (final e in (fresh ?? info).settings.entries)
      if (!_volatileSettings.contains(e.key)) e.key: e.value,
  };

  step('Reading the CFW settings');

  List<int>? globalEq;

  if (caps & _capGlobalEq != 0) {
    final hex = await _read(
      s,
      [0x12, 0x3A],
      [0x12, 0x3A],
      isValid: (p) => p.length >= 12,
    );

    if (hex == null) {
      throw const CfwBackupException('Global EQ: no answer (12 3A)');
    }

    globalEq = _payload(hex).sublist(2, 12);
  }

  step('Reading the Global EQ');

  List<int>? order;

  if (caps & _capOrder != 0) {
    final hex = await _read(s, [0x12, 0x37], [0x12, 0x37]);

    order = hex == null ? null : decodePresetOrderFrame(hex)?.entries;
  }

  step('Reading the preset order');

  final slotData = <int, List<BackupSlot>>{0: [], 1: []};

  if (hasSlotData) {
    for (final (register, kind, count, length) in [
      (0x28, 1, irSlots, irDataLength),
      (0x29, 0, cloneSlots, cloneDataLength),
    ]) {
      final hex = await _read(s, [0x12, register], [0x12, register]);
      final names = hex == null ? null : _payload(hex);

      for (var slot = 1; slot <= count; slot++) {
        // Each 32-byte entry: a "holds data" flag, then the name.
        final at = 4 + 32 * (slot - 1);
        final hasEntry = names != null && names.length >= at + 2;
        final data = !hasEntry || names[at] != 0
            ? await _readSlotData(s, kind, slot, length)
            : null;

        if (data != null) {
          slotData[kind]!.add(
            BackupSlot(
              slot: slot,
              name: hasEntry
                  ? String.fromCharCodes(
                      names.skip(at + 1).take(31).takeWhile((b) => b != 0),
                    )
                  : '',
              data: data,
            ),
          );
        }

        step('Reading ${kind == 1 ? 'User IR' : 'User Profile'} data');
      }
    }
  }

  final globalsHex = await s.requestGlobalSettings();
  final g = globalsHex == null
      ? null
      : const GlobalSettingsDecoder().decode(globalsHex);

  step('Reading the global settings');

  String state(bool isAvailable, bool hasAny) =>
      !isAvailable ? 'unavailable' : (hasAny ? 'complete' : 'none');

  return CfwBackup(
    created: (now ?? DateTime.now()).toUtc(),
    app: app,
    pedal: BackupPedal(
      model: _model,
      cfwTag: info.version,
      caps: caps,
      irSlots: irSlots,
      cloneSlots: cloneSlots,
    ),
    sections: {
      'presets': 'complete',
      'scenes': state(hasScenes, presets.any((p) => p.scenes != null)),
      if (hasExp)
        'midiPedals': state(
          isExpSupported,
          presets.any((p) => p.midiPedals != null),
        ),
      if (hasExp) 'midiMap': midiMap!.entries.isEmpty ? 'none' : 'complete',
      'order': order == null ? 'unavailable' : 'complete',
      'globals': g == null ? 'unavailable' : 'complete',
      'cfwSettings': 'complete',
      'globalEq': globalEq == null ? 'unavailable' : 'complete',
      'irs': state(hasSlotData, slotData[1]!.isNotEmpty),
      'clones': state(hasSlotData, slotData[0]!.isNotEmpty),
    },
    presets: presets,
    order: order,
    globals: g == null
        ? null
        : {
            'globalVolume': g.globalVolume,
            'inputLevel': g.inputLevel,
            'fxRecLevel': g.fxRecLevel,
            'monitorLevel': g.monitorLevel,
            'btRecLevel': g.btRecLevel,
            'mode': g.mode,
            'reamp': g.reamp,
            'expFsType': g.expFsType,
            'backlight': g.backlight,
            'eco': g.eco,
          },
    globalsRaw: globalsHex,
    cfwSettings: cfwSettings,
    globalEq: globalEq,
    irs: slotData[1]!,
    clones: slotData[0]!,
    midiMap: midiMap,
  );
}

// --- Restore ----------------------------------------------------------------

/// The global settings a restore can write (the `GlobalSettings` names).
const _writableGlobals = {
  'globalVolume',
  'inputLevel',
  'fxRecLevel',
  'monitorLevel',
  'btRecLevel',
  'mode',
  'expFsType',
  'backlight',
  'eco',
  'powerConfirm',
  'battOnly',
  'expFsTarget',
  'expFsTarget2',
};

/// What a restore writes, computed from the file and a fresh backup of the
/// pedal: only what differs, as the CFW app (`bqj`).
class RestorePlan {
  RestorePlan({
    required this.isOneWrite,
    required this.keepsStomp,
    this.midiMap,
    this.cfwSettings = const {},
    this.globalEq,
    this.presets = const [],
    this.scenesFor = const {},
    this.expFor = const {},
    this.globals = const {},
    this.expFsType = 0,
    this.notes = const [],
  });

  /// Presets go in one `11 34` write with their scenes and EXP A-D
  /// (capability word 2, bit 11); else `11 4F` writes the record only.
  final bool isOneWrite;

  /// The firmware keeps STOMP groups (capability bit 10).
  final bool keepsStomp;
  final ({int options, Uint8List entries})? midiMap;
  final Map<int, int> cfwSettings;
  final List<int>? globalEq;

  /// Presets to write, by slot order, each with the record to write.
  final List<BackupPreset> presets;

  /// Presets whose scenes / EXP A-D are restored with them.
  final Set<int> scenesFor;
  final Set<int> expFor;
  final Map<String, int> globals;

  /// The EXP/FS type the targets are written for.
  final int expFsType;

  /// What the restore leaves out or plays differently.
  final List<String> notes;

  bool get isEmpty =>
      midiMap == null &&
      cfwSettings.isEmpty &&
      globalEq == null &&
      presets.isEmpty &&
      globals.isEmpty;

  /// What will be overwritten, as the CFW app lists it (`q9`).
  List<String> get overwrites => [
    if (midiMap case final m?)
      'Custom MIDI map: ${m.entries.length ~/ 8} entries written',
    if (cfwSettings.isNotEmpty) 'CFW settings: ${cfwSettings.length} to change',
    if (globalEq != null) 'Global EQ: changes',
    if (presets.isNotEmpty)
      'Presets: ${presets.length} written (${_labels(presets.map((p) => p.index))})',
    if (scenesFor.isNotEmpty) 'Scenes: restored on ${_labels(scenesFor)}',
    if (expFor.isNotEmpty) 'EXP A–D: restored on ${_labels(expFor)}',
    if (globals.isNotEmpty) 'Global settings: ${globals.length} to change',
    if (isEmpty) 'Nothing differs from the pedal: nothing to write',
  ];
}

String _labels(Iterable<int> indices) {
  final sorted = indices.toList()..sort();

  if (sorted.length == 50) return 'P01–P50';

  final shown = sorted.take(12).map(presetLabel).join(', ');

  return sorted.length > 12 ? '$shown, + ${sorted.length - 12} more' : shown;
}

bool _same(List<int>? a, List<int>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }

  return true;
}

String _article(String word) =>
    'AEIOU'.contains(word.isEmpty ? 'x' : word[0]) ? 'an' : 'a';

/// The CFW app's message for a backup of the other CFW edition (`b0O`).
String _editionMessage({required bool isFileNam}) {
  const settingsOnly =
      'Here only the pedal settings (global settings, CFW settings, Custom '
      'MIDI map) move, no presets. ';
  const switching =
      'Switching CFW: back up BEFORE flashing (on the CFW you are leaving), '
      'then restore the backup you made earlier on the other CFW.';

  return isFileNam
      ? 'This backup was made on the NAM CFW: restore it after installing '
            'the NAM CFW. $settingsOnly$switching'
      : 'This backup was made on the normal CFW: restore it after installing '
            'the normal CFW (its presets would play almost nothing on the NAM '
            'CFW). $settingsOnly$switching No NAM backup yet? Clear the User '
            'presets.';
}

/// Compares [file] with [pedal] (a backup just read from the connected
/// pedal) and lists what a restore writes. The second value is why the
/// whole restore is refused, else null.
(RestorePlan?, String?) planRestore(
  CfwBackup file,
  CfwBackup pedal,
  CfwInfo info,
) {
  final model = file.pedal.model;

  if (model != _model) {
    return (
      null,
      'This backup comes from ${_article(model)} $model: restore it on that '
          'pedal.',
    );
  }

  if (isNamPedal(info)) {
    return (null, 'restoring on the NAM CFW is not supported by SonicMaster');
  }

  final caps = info.capabilities;
  final notes = <String>[];
  final isFileNam = file.pedal.isNam;

  if (isFileNam) {
    notes.add(
      '${[if (file.namModels != null) 'NAM models (slots 02–20)', if (file.presets.isNotEmpty) 'User presets (P01–P50)'].join(', ')}: not restored. ${_editionMessage(isFileNam: true)}',
    );
  }

  // Custom MIDI map.
  ({int options, Uint8List entries})? midiMap;

  if (file.midiMap case final m? when m.entries.isNotEmpty) {
    final current = pedal.midiMap;

    if (caps & _capExp == 0) {
      notes.add('Custom MIDI map: needs CFW 1.0');
    } else if (current == null ||
        current.options != m.options & 3 ||
        !_same(current.entries, m.entries)) {
      midiMap = m;
    }
  }

  // CFW settings.
  final cfwSettings = <int, int>{};

  for (final MapEntry(key: k, value: v) in file.cfwSettings.entries) {
    if (_volatileSettings.contains(k)) continue;
    if (k == 5 && isFileNam) continue;

    if (k == 1 && isFileNam) {
      notes.add(
        'CFW setting Theme (NAM CFW): means another thing on the normal CFW, '
        'kept as it is',
      );
      continue;
    }

    if (k == 0x17 && (midiMap != null || file.cfwSettings[0x15] != 1)) {
      continue;
    }

    final current = pedal.cfwSettings[k] ?? info.settings[k];

    if (current == null) {
      notes.add('CFW setting $k: not on this firmware');
    } else if (current != v) {
      cfwSettings[k] = v;
    }
  }

  // Global EQ.
  List<int>? globalEq;

  if (file.globalEq case final eq? when !isFileNam) {
    if (caps & _capGlobalEq == 0) {
      notes.add('Global EQ: needs CFW 1.0');
    } else if (!_same(pedal.globalEq, eq)) {
      globalEq = eq;
    }
  }

  // User IR / Clone data: compared, not uploaded.
  if (!isFileNam) {
    for (final (slots, current, kind, count) in [
      (file.irs, pedal.irs, 'User IR', pedal.pedal.irSlots),
      (file.clones, pedal.clones, 'User Profile', pedal.pedal.cloneSlots),
    ]) {
      for (final s in slots) {
        final same = current.where(
          (c) => c.slot == s.slot && c.name == s.name && _same(c.data, s.data),
        );

        if (s.slot > count) {
          notes.add('$kind ${s.slot}: this pedal has $count slots');
        } else if (same.isEmpty) {
          notes.add(
            '$kind ${s.slot}: not restored (SonicMaster does not upload '
            'backup data yet)',
          );
        }
      }
    }
  }

  // Presets, with their scenes and EXP A-D.
  final presets = <BackupPreset>[];
  final scenesFor = <int>{};
  final expFor = <int>{};
  final keepsStomp = caps & _capStompGroups != 0;
  final canScenes = caps & _capScenes != 0;
  final canExp = caps & _capExp != 0;

  for (final p in isFileNam ? const <BackupPreset>[] : file.presets) {
    final label = p.label;
    final current = pedal.presets.where((c) => c.index == p.index).firstOrNull;
    final hasScenesInFile = hasScenes(p.scenes, p.record);
    final doesScenes = hasScenesInFile && canScenes;
    final expected = keepsStomp ? p.record : withoutStompGroups(p.record);
    final isRecordChanged = current == null || !_same(current.record, expected);
    final areScenesChanged =
        doesScenes &&
        (current == null ||
            !_same(
              normalizedSceneBlock(current.scenes, current.record),
              normalizedSceneBlock(p.scenes, p.record),
            ));
    final isExpCrowded = doesScenes
        ? !hasRoomForExp(p.scenes, p.record)
        : current != null && !hasRoomForExp(current.scenes, current.record);
    final doesExp = p.midiPedals != null && canExp && !isExpCrowded;

    if (p.midiPedals != null && canExp && isExpCrowded) {
      notes.add(
        '$label EXP A–D: not restored (no room: its scenes use the space)',
      );
    }

    final isExpChanged =
        doesExp &&
        (current == null || !_same(current.midiPedals, p.midiPedals));

    if (hasScenesInFile && !canScenes) {
      notes.add('$label scenes: need CFW 1.0');
    }

    if (p.midiPedals != null && !canExp) {
      notes.add('$label EXP A–D: need CFW 1.0');
    }

    if (!isRecordChanged && !areScenesChanged && !isExpChanged) continue;

    presets.add(
      BackupPreset(
        index: p.index,
        record: isRecordChanged ? p.record : current.record,
        scenes: p.scenes,
        midiPedals: p.midiPedals,
      ),
    );

    if (doesScenes) scenesFor.add(p.index);
    if (doesExp) expFor.add(p.index);

    final stomp = presetRecordStomp(p.record);

    if (!keepsStomp && (stomp.fs1 | stomp.fs2) != 0) {
      notes.add('$label: STOMP groups not kept (needs CFW 1.0)');
    }
  }

  if (file.order != null) {
    notes.add(
      'Preset order: kept as it is (the presets are written in the order of '
      'the backup)',
    );
  }

  // Global settings, written last.
  final globals = <String, int>{};

  for (final MapEntry(key: k, value: v) in (file.globals ?? {}).entries) {
    final current = pedal.globals?[k];

    if (current == v) continue;

    if (_writableGlobals.contains(k)) {
      globals[k] = v;
    } else {
      notes.add(
        'Global setting $k: not restored (SonicMaster cannot check it on '
        'this pedal)',
      );
    }
  }

  return (
    RestorePlan(
      isOneWrite: info.extraCapabilities & _caps2OneWrite != 0,
      keepsStomp: keepsStomp,
      midiMap: midiMap,
      cfwSettings: cfwSettings,
      globalEq: globalEq,
      presets: presets,
      scenesFor: scenesFor,
      expFor: expFor,
      globals: globals,
      expFsType: file.globals?['expFsType'] ?? pedal.globals?['expFsType'] ?? 0,
      notes: notes,
    ),
    null,
  );
}

/// The write frame of global setting [name] through the app's own setters:
/// master volume and levels by their captured frames, EXP/FS targets by
/// their register for [expFsType], the rest as settings-dump records. Null
/// for a setting the app cannot write (Re-amp, Func 2 outside DualFS).
String? globalRestoreFrame(
  CommandLibrary commands,
  String name,
  int value,
  int expFsType,
) {
  switch (name) {
    case 'globalVolume' ||
        'inputLevel' ||
        'fxRecLevel' ||
        'monitorLevel' ||
        'btRecLevel':
      return commands.globalCommand(name, value);
    case 'expFsTarget':
      final (reg, sub) = switch (expFsType) {
        0 => (0x17, 0x01),
        1 => (0x16, 0x00),
        _ => (0x16, 0x02),
      };

      return GlobalSettingWriter.registerWrite(
        reg: reg,
        sub: sub,
        value: value,
      );
    case 'expFsTarget2':
      return expFsType == 2
          ? GlobalSettingWriter.registerWrite(
              reg: 0x16,
              sub: 0x04,
              value: value,
            )
          : null;
    case 'reamp':
      return null;
  }

  final addr = globalSettingAddress[name];

  return addr == null
      ? null
      : GlobalSettingWriter.dumpRecord(a0: addr.$1, a1: addr.$2, value: value);
}

class RestoreResult {
  const RestoreResult({
    required this.isOk,
    required this.message,
    required this.notes,
  });

  /// False when the restore stopped part way ([message] says where).
  final bool isOk;
  final String message;

  /// Sections not restored or read back differently.
  final List<String> notes;
}

enum _ReadBack { same, knobsOnly, different }

/// Compares a read-back record: the knob floats may move (the pedal snaps
/// values), anything else must be identical.
_ReadBack _compareRecord(Uint8List? got, Uint8List expected) {
  if (got == null || got.length != expected.length) return .different;
  if (_same(got, expected)) return .same;

  final at = presetRecordParamsOffset(expected) ?? expected.length;

  for (var i = 0; i < got.length; i++) {
    if ((i < at || i >= at + 320) && got[i] != expected[i]) return .different;
  }

  return .knobsOnly;
}

/// Writes [plan] in the CFW app's order: the custom MIDI map, the CFW
/// settings, the Global EQ, the presets (each read back; a preset that does
/// not read back as written stops the restore), then the global settings.
/// [globalFrame] builds a global setting's write frame.
Future<RestoreResult> runRestore(
  DeviceService s,
  RestorePlan plan, {
  required String? Function(String name, int value, int expFsType) globalFrame,
  BackupProgress? onProgress,
}) async {
  final notes = <String>[];
  final total =
      (plan.midiMap == null ? 0 : 1) +
      plan.cfwSettings.length +
      (plan.globalEq == null ? 0 : 1) +
      plan.presets.length +
      plan.globals.length;
  var done = 0;
  void step(String what) => onProgress?.call(what, ++done, total);
  var written = 0;

  String summary() => [
    'Restored $written preset(s)',
    if (plan.midiMap != null) 'the Custom MIDI map',
    if (plan.cfwSettings.isNotEmpty)
      '${plan.cfwSettings.length} CFW setting(s)',
    if (plan.globalEq != null) 'the Global EQ',
    if (plan.globals.isNotEmpty) '${plan.globals.length} global setting(s)',
  ].join(', ');

  // What was written before the stop stays written: the same file loaded
  // again resumes, as in the CFW app.
  RestoreResult stop(String why) =>
      RestoreResult(isOk: false, message: why, notes: notes);

  if (plan.midiMap case final m?) {
    final entries = [
      for (var i = 0; i < m.entries.length; i += 8)
        MidiMapEntry.fromBytes(m.entries.sublist(i, i + 8)),
    ];
    final isAcked = await s.sendFramesAcked(
      buildMidiMapFrames(options: m.options, entries: entries),
    );
    ({int options, Uint8List entries})? back;

    try {
      back = await _readMidiMap(s);
    } on CfwBackupException {
      back = null;
    }

    if (!isAcked ||
        back == null ||
        back.options != m.options & 3 ||
        !_same(back.entries, m.entries)) {
      notes.add(
        'Custom MIDI map: not restored (${isAcked ? 'read back differently' : 'no ack'})',
      );
    }

    step('Custom MIDI map');
  }

  for (final MapEntry(key: k, value: v) in plan.cfwSettings.entries) {
    final status = await s.writeCfwBlock([0x11, 0x2A, k, v]);

    if (status != 0) {
      notes.add(
        'CFW setting $k: refused (${status == null ? 'no answer' : 'status $status'})',
      );
    } else {
      Future<int?> readBack() async {
        final hex = await _read(s, [0x12, 0x2A], [0x12, 0x2A]);

        return hex == null ? null : decodeCfwSettingsFrame(hex)?.settings[k];
      }

      var got = await readBack();

      if (got != v) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        got = await readBack();
      }

      if (got != v) {
        notes.add('CFW setting $k: pedal reports $got, expected $v');
      }
    }

    step('CFW settings');
  }

  if (plan.globalEq case final eq?) {
    final status = await s.writeCfwBlock([0x11, 0x3A, ...eq]);

    if (status != 0) {
      notes.add(
        'Global EQ: refused (${status == null ? 'no answer' : 'status $status'})',
      );
    }

    step('Global EQ');
  }

  Future<int?> write(List<int> payload) async {
    int? status;

    for (var i = 0; i < 2; i++) {
      status = await s.writeCfwBlock(payload, commitDomain: 2);

      if (status == 0 || (status != null && status != 4 && status != 1)) {
        break;
      }
    }

    return status;
  }

  for (final p in plan.presets) {
    final label = p.label;
    final slot = p.index;
    final expected = plan.keepsStomp ? p.record : withoutStompGroups(p.record);
    final withScenes = plan.scenesFor.contains(slot);
    final withExp = plan.expFor.contains(slot);
    var isOneWrite = plan.isOneWrite;

    if (isOneWrite) {
      final status = await write(
        presetWithScenesPayload(
          slot,
          p.record,
          scenes: withScenes ? p.scenes : null,
          midiPedals: withExp ? p.midiPedals : null,
        ),
      );

      if (status == 5) {
        notes.add('$label: the pedal refused 11 34, written with 11 4F');
        isOneWrite = false;
      } else if (status == 3) {
        return stop(
          '$label: not written (its scenes leave no room for EXP A–D)',
        );
      } else if (status != 0) {
        return stop(
          '$label: not written (11 34 ${status == null ? 'no answer' : 'status $status'})',
        );
      }
    }

    if (!isOneWrite) {
      final status = await write(presetWritePayload(slot, p.record));

      if (status != 0) {
        return stop(
          '$label: not written (11 4F ${status == null ? 'no answer' : 'status $status'})',
        );
      }
    }

    var check = _compareRecord(await _readRecord(s, slot), expected);

    if (check == .different) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      check = _compareRecord(await _readRecord(s, slot), expected);
    }

    if (check == .different) {
      return stop(
        '$label: the pedal reads back a different preset; the restore '
        'stopped here',
      );
    }

    if (check == .knobsOnly) {
      notes.add('$label: the pedal changed some knob values on the write');
    }

    if (isOneWrite) {
      try {
        if (withScenes &&
            !_same(
              normalizedSceneBlock(await _readScenes(s, slot), p.record),
              normalizedSceneBlock(p.scenes, p.record),
            )) {
          notes.add('$label scenes: read back differently');
        }

        if (withExp) {
          final back = await _readExp(s, slot);
          final want = midiPedalsToExpBlock(p.midiPedals!);

          if (want == null ||
              !_same(expBlockToMidiPedals(back.exp).sublist(2), want)) {
            notes.add('$label EXP A–D: read back differently');
          }
        }
      } on CfwBackupException catch (e) {
        notes.add(e.message);
      }
    } else if (withScenes || withExp) {
      notes.add(
        '$label ${[if (withScenes) 'scenes', if (withExp) 'EXP A–D'].join(' + ')}: '
        'not restored (this firmware needs the preset selected and saved; '
        'SonicMaster does not do that yet)',
      );
    }

    written++;
    step('Writing $label ${presetRecordName(p.record)}');
  }

  for (final MapEntry(key: k, value: v) in plan.globals.entries) {
    final frame = globalFrame(k, v, plan.expFsType);

    if (frame == null) {
      notes.add('Global setting $k: not restored (no write for it)');
    } else if (!await s.sendAndAwaitAck(frame)) {
      notes.add('Global setting $k: sent, the pedal did not confirm it');
    }

    step('Global settings');
  }

  return RestoreResult(isOk: true, message: summary(), notes: notes);
}
