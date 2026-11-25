import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/cfw_eq_models.dart';
import '../model/cfw_exp.dart';
import '../model/cfw_global_eq.dart';

import '../model/cfw_info.dart';
import '../model/cfw_scenes.dart';
import '../model/command_library.dart';
import '../model/midi_map.dart';
import '../model/preset_ref.dart';
import '../protocol/cfw_exp_codec.dart';
import '../protocol/cfw_geq_codec.dart';
import '../protocol/cfw_midi_map_codec.dart';
import '../protocol/cfw_preset_order_codec.dart';
import '../protocol/cfw_scene_codec.dart';
import '../protocol/cfw_setting_writer.dart';
import '../protocol/cfw_settings_decoder.dart';
import '../protocol/cfw_slot_names_codec.dart';
import 'device_providers.dart';
import 'names_providers.dart';
import 'preset_providers.dart';

/// What the connected pedal's community custom firmware (CFW) reports; null
/// for stock firmware (it never answers the `12 2A` read). Re-read on every
/// connect, so a stock pedal after a CFW one reads back null. The UI shows CFW
/// controls only while connected.
final cfwInfoProvider = StateProvider<CfwInfo?>((_) => null);

/// The CFW's DSP load in percent, polled by the connection heartbeat; null
/// until read (or on stock firmware).
final dspLoadProvider = StateProvider<int?>((_) => null);

/// Reads the CFW settings block into [cfwInfoProvider]. Fired unawaited on
/// connect, so it takes what it needs from [ref] before the read and only
/// writes back if the state is still alive.
Future<void> refreshCfwInfo(
  WidgetRef ref, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final service = ref.read(deviceServiceProvider);
  final info = ref.read(cfwInfoProvider.notifier);
  final hex = await service.requestCfwSettings(timeout: timeout);

  if (info.mounted) {
    info.state = hex == null ? null : decodeCfwSettingsFrame(hex);
  }
}

/// Reads the DSP load into [dspLoadProvider]; a missed read clears it, so the
/// chip disappears instead of freezing at a stale value.
Future<void> refreshDspLoad(WidgetRef ref) async {
  final service = ref.read(deviceServiceProvider);
  final dsp = ref.read(dspLoadProvider.notifier);
  final load = await service.requestDspLoad();

  if (dsp.mounted) dsp.state = load;
}

/// Drops the CFW state, at the start of every connection.
void clearCfwState(WidgetRef ref) {
  clearSceneState(ref);
  ref.read(globalEqProvider.notifier).state = null;
  ref.read(midiMapProvider.notifier).state = null;
  ref.read(cfwInfoProvider.notifier).state = null;
  ref.read(dspLoadProvider.notifier).state = null;
}

/// The connect-time reads, in order: preset names first, then the CFW block.
/// On stock firmware the CFW read only times out, so it goes last and never
/// delays the names on the serialized IO gate.
Future<void> refreshNamesThenCfw(WidgetRef ref) async {
  await refreshNames(ref);
  await refreshCfwInfo(ref);
  await refreshCfwSlotNames(ref);
  // The preset loaded at connect arrives as a pushed dump, before the CFW is
  // known: read its scenes now.
  await refreshScenes(ref);
}

/// On a CFW pedal, reads the names of its ten User IR and ten User Profile
/// slots into [userNamesProvider] (the stock dumps only carry five, cut
/// short). A slot the pedal calls "Empty" keeps the name it had. Best-effort,
/// like the stock name reads; a no-op on stock firmware.
Future<void> refreshCfwSlotNames(WidgetRef ref) async {
  if (ref.read(cfwInfoProvider) == null) return;

  final service = ref.read(deviceServiceProvider);
  final names = ref.read(userNamesProvider.notifier);

  for (final (register, idOf) in const [
    (cfwIrNamesRegister, cfwIrEffectId),
    (cfwProfileNamesRegister, cfwProfileEffectId),
  ]) {
    try {
      final hex = await service.requestCfwSlotNames(register);
      final decoded = hex == null ? null : decodeCfwSlotNames(hex, register);

      if (decoded == null || !names.mounted) continue;

      names.state = {
        ...names.state,
        for (final (slot, name) in decoded.indexed)
          if (name.isNotEmpty && name != 'Empty') idOf(slot): name,
      };
    } catch (_) {
      // best-effort
    }
  }
}

/// Sets one CFW setting: shows it at once, then sends it and waits for the
/// pedal's ack. Brightness ([CfwInfo.brightnessKey]) goes through its own
/// frame, like the CFW app does.
Future<void> setCfwSetting(WidgetRef ref, int key, int value) async {
  final info = ref.read(cfwInfoProvider.notifier);
  final service = ref.read(deviceServiceProvider);
  final current = info.state;

  if (current == null) return;

  info.state = current.copyWithSetting(key, value);
  await service.sendAndAwaitAck(
    key == CfwInfo.brightnessKey
        ? CfwSettingWriter.brightness(value)
        : CfwSettingWriter.setting(key, value),
  );
}

bool _statusPollInFlight = false;

/// The CFW part of the connection heartbeat: on a CFW pedal, reads the DSP
/// load. Like pollGlobalSettings it stays quiet while a load or an upload
/// holds the pedal ([presetLoadingProvider]), never stacks a second read on
/// the serialized IO gate behind a stalled one, and swallows a send error
/// (the chip then disappears). A no-op on stock firmware.
Future<void> pollCfwStatus(WidgetRef ref) async {
  if (_statusPollInFlight ||
      ref.read(cfwInfoProvider) == null ||
      ref.read(presetLoadingProvider)) {
    return;
  }

  final dsp = ref.read(dspLoadProvider.notifier);

  _statusPollInFlight = true;
  try {
    await refreshDspLoad(ref);
  } catch (_) {
    if (dsp.mounted) dsp.state = null;
  } finally {
    _statusPollInFlight = false;
  }
}

/// The CFW Global EQ models (bundled data).
final cfwEqModelsProvider = FutureProvider<List<CfwEqModel>>(
  (_) async => parseCfwEqModels(
    jsonDecode(await rootBundle.loadString('assets/data/cfw_eq_models.json'))
        as Map<String, dynamic>,
  ),
);

/// The pedal's Global EQ block; null until read (or on stock firmware).
final globalEqProvider = StateProvider<CfwGlobalEq?>((_) => null);

/// Reads the Global EQ block into [globalEqProvider]; a missed read keeps the
/// last value. A no-op on stock firmware.
Future<void> refreshGlobalEq(WidgetRef ref) async {
  if (ref.read(cfwInfoProvider) == null) return;

  final service = ref.read(deviceServiceProvider);
  final eq = ref.read(globalEqProvider.notifier);

  try {
    final hex = await service.requestGlobalEq();
    final decoded = hex == null ? null : decodeGlobalEqFrame(hex);

    if (decoded != null && eq.mounted) eq.state = decoded;
  } catch (_) {
    // Best-effort: the section keeps what it had.
  }
}

/// Sets the Global EQ: shows it at once and sends the whole block.
Future<void> setGlobalEq(WidgetRef ref, CfwGlobalEq value) async {
  final service = ref.read(deviceServiceProvider);

  ref.read(globalEqProvider.notifier).state = value;
  try {
    await service.sendAndAwaitAck(buildGlobalEqFrame(value));
  } catch (_) {
    // A failed send leaves the shown value; the next read corrects it.
  }
}

/// The loaded preset's scene records on a CFW pedal, by module id.
final sceneRecordsProvider = StateProvider<Map<int, SceneRecord>>(
  (_) => const {},
);

/// The live scene: 0 BASE, 1 SC1, 2 SC2.
final currentSceneProvider = StateProvider<int>((_) => 0);

const _noExp = <ExpAssign?>[null, null, null, null];

/// EXP A-D of the loaded preset on a CFW pedal; null is a free slot. They
/// belong to the preset, so they are read and dropped with its scenes.
final expAssignsProvider = StateProvider<List<ExpAssign?>>((_) => _noExp);

/// Whether [expAssignsProvider] holds what the pedal answered for the loaded
/// preset. False after a preset change until the read lands: four free slots
/// then only mean "not read", and writing them would erase the pedal's.
final expKnownProvider = StateProvider<bool>((_) => false);

/// Assigns EXP slot [index] (0 = A) to [assign], or frees it with null: shows
/// it at once and sends all four slots. With the pedal's slots not read yet
/// it reads them first, and writes nothing if that fails (the block carries
/// all four slots). A no-op on stock firmware.
Future<void> setExpAssign(WidgetRef ref, int index, ExpAssign? assign) async {
  if (ref.read(cfwInfoProvider) == null) return;

  if (!ref.read(expKnownProvider)) {
    await _readExp(ref);

    if (!ref.read(expKnownProvider)) {
      ref.read(presetLoadStatusProvider.notifier).state =
          'EXP not changed: the pedal did not answer';

      return;
    }
  }

  final slots = [...ref.read(expAssignsProvider)]..[index] = assign;

  ref.read(expAssignsProvider.notifier).state = slots;
  ref.read(presetModifiedProvider.notifier).state = true;
  await _sendScene(ref, buildExpFrame(slots));
}

Future<void> _readExp(WidgetRef ref) async {
  final service = ref.read(deviceServiceProvider);
  final exp = ref.read(expAssignsProvider.notifier);
  final known = ref.read(expKnownProvider.notifier);

  try {
    final hex = await service.requestExpAssigns();
    final slots = hex == null ? null : decodeExpFrame(hex);

    if (slots == null || !exp.mounted) return;

    exp.state = slots;
    known.state = true;
  } catch (_) {
    // Best-effort.
  }
}

/// Drops the scene state (a new preset or a new connection).
void clearSceneState(WidgetRef ref) {
  ref.read(expAssignsProvider.notifier).state = _noExp;
  ref.read(expKnownProvider.notifier).state = false;
  ref.read(sceneRecordsProvider.notifier).state = const {};
  ref.read(currentSceneProvider.notifier).state = 0;
}

/// Reads the loaded preset's scene records and the live scene. A no-op on
/// stock firmware; best-effort (a missed read keeps the current state).
Future<void> refreshScenes(WidgetRef ref) async {
  if (ref.read(cfwInfoProvider) == null) return;

  final service = ref.read(deviceServiceProvider);
  final records = ref.read(sceneRecordsProvider.notifier);
  final scene = ref.read(currentSceneProvider.notifier);

  try {
    final recordsHex = await service.requestSceneRecords();
    final sceneHex = await service.requestCurrentScene();

    await _readExp(ref);

    if (!records.mounted) return;

    // A missed read keeps what we have: the scenes are cleared where the
    // preset changes, so nothing stale survives, and a timeout must not wipe
    // records or drop the live scene mid-edit.
    if (recordsHex != null) {
      records.state = {
        for (final r in decodeSceneRecordsFrame(recordsHex)) r.module: r,
      };
    }

    final live = sceneHex == null ? null : decodeCurrentSceneFrame(sceneHex);

    if (live != null) scene.state = live;
  } catch (_) {
    // Best-effort.
  }
}

/// Whether an edit of [module] right now belongs to a scene: a CFW pedal, SC1
/// or SC2 live, and the module taking part in scenes.
bool isSceneEdit(WidgetRef ref, int module) =>
    ref.read(cfwInfoProvider) != null &&
    ref.read(currentSceneProvider) != 0 &&
    ref.read(sceneRecordsProvider).containsKey(module);

Future<void> _sendScene(WidgetRef ref, String frame) async {
  try {
    await ref.read(deviceServiceProvider).sendFrame(frame);
  } catch (e) {
    ref.read(presetLoadStatusProvider.notifier).state = 'edit failed: $e';
  }
}

void _storeRecord(WidgetRef ref, SceneRecord r) {
  ref.read(sceneRecordsProvider.notifier).state = {
    ...ref.read(sceneRecordsProvider),
    r.module: r,
  };
  ref.read(presetModifiedProvider.notifier).state = true;
}

/// Selects the live scene on the pedal.
Future<void> selectScene(WidgetRef ref, int scene) async {
  ref.read(currentSceneProvider.notifier).state = scene;
  await _sendScene(ref, selectSceneFrame(scene));
}

/// Adds [module] to the scenes, or takes it out (dropping its overrides).
Future<void> setModuleInScenes(
  WidgetRef ref,
  int module, {
  required bool isIn,
}) async {
  if (isIn) {
    // With no local record, ask the pedal first: a bare record would wipe
    // overrides it already holds (a missed read at load, for example).
    if (!ref.read(sceneRecordsProvider).containsKey(module)) {
      await refreshScenes(ref);
    }

    final r =
        ref.read(sceneRecordsProvider)[module] ?? SceneRecord(module: module);

    _storeRecord(ref, r);
    await _sendScene(ref, buildSceneRecordFrame(r));
  } else {
    ref.read(sceneRecordsProvider.notifier).state = {
      for (final e in ref.read(sceneRecordsProvider).entries)
        if (e.key != module) e.key: e.value,
    };
    ref.read(presetModifiedProvider.notifier).state = true;
    await _sendScene(ref, clearSceneRecordFrame(module));
  }
}

/// Sets one knob of [module] in the live scene (SC1 / SC2).
Future<void> setSceneParam(
  WidgetRef ref,
  int module,
  int algId,
  num value,
) async {
  final scene = ref.read(currentSceneProvider);
  final current = ref.read(sceneRecordsProvider)[module];

  if (scene == 0 || current == null) return;

  final r = current.withValue(scene, algId, value.toDouble());

  _storeRecord(ref, r);
  await _sendScene(ref, buildSceneRecordFrame(r));
}

/// Sets [module]'s on/off in the live scene; null follows BASE.
Future<void> setSceneModuleState(WidgetRef ref, int module, bool? isOn) async {
  final scene = ref.read(currentSceneProvider);
  final current = ref.read(sceneRecordsProvider)[module];

  if (scene == 0 || current == null) return;

  final r = current.withOn(scene, isOn);

  _storeRecord(ref, r);
  await _sendScene(ref, buildSceneRecordFrame(r));
}

/// Moves the User preset at position [from] to position [to] (1-based, as the
/// labels P01..P50); the presets in between shift by one. The CFW only
/// rewrites its order table: no preset is changed, but MIDI and footswitch
/// preset numbers then select different sounds. Returns whether the pedal
/// took the whole table. A no-op (false) on stock firmware.
Future<bool> moveUserPreset(WidgetRef ref, int from, int to) async {
  bool isSlot(int n) => n >= 1 && n <= presetOrderLength;

  if (ref.read(cfwInfoProvider) == null ||
      !isSlot(from) ||
      !isSlot(to) ||
      from == to) {
    return false;
  }

  final service = ref.read(deviceServiceProvider);
  final names = ref.read(presetNamesProvider.notifier);
  final current = ref.read(currentPresetProvider.notifier);

  try {
    final hex = await service.requestPresetOrder();
    final order = hex == null ? null : decodePresetOrderFrame(hex);

    if (order == null) return false;

    final frames = buildPresetOrderFrames(
      token: order.token,
      entries: movePreset(order.entries, from: from - 1, to: to - 1),
    );

    for (final frame in frames) {
      if (!await service.sendAndAwaitAck(frame)) return false;
    }
  } catch (_) {
    return false;
  }

  if (!names.mounted) return true;

  // Where each position's preset came from, 1-based.
  final source = movePreset(
    [for (var i = 1; i <= presetOrderLength; i++) i],
    from: from - 1,
    to: to - 1,
  );
  final old = names.state;

  names.state = {
    for (final e in old.entries)
      if (e.key.bank != PresetBank.user) e.key: e.value,
    for (final (i, src) in source.indexed)
      if (old[PresetRef(.user, src)] case final name?)
        PresetRef(.user, i + 1): name,
  };

  final loaded = current.state;

  if (loaded != null && loaded.bank == PresetBank.user) {
    current.state = PresetRef(.user, source.indexOf(loaded.number) + 1);
  }

  return true;
}

/// The rows of the pedal's custom MIDI map; null until read (or when the read
/// failed), so an unread map is never mistaken for an empty one.
final midiMapProvider = StateProvider<List<MidiMapEntry>?>((_) => null);

/// Reads the pedal's custom MIDI map into [midiMapProvider]: the summary,
/// then pages of eight rows. Any missed or short read leaves it null. A no-op
/// on stock firmware.
Future<void> refreshMidiMap(WidgetRef ref) async {
  if (ref.read(cfwInfoProvider) == null) return;

  final service = ref.read(deviceServiceProvider);
  final map = ref.read(midiMapProvider.notifier);
  List<MidiMapEntry>? rows;

  try {
    final infoHex = await service.requestMidiMapInfo();
    final info = infoHex == null ? null : decodeMidiMapInfo(infoHex);

    if (info != null && info.count <= MidiMapEntry.maxEntries) {
      rows = [];
      while (rows != null && rows.length < info.count) {
        final hex = await service.requestMidiMapPage(rows.length);
        final page = hex == null ? null : decodeMidiMapPage(hex);

        rows = page == null || page.entries.isEmpty || page.first != rows.length
            ? null
            : [...rows, ...page.entries];
      }
    }
  } catch (_) {
    rows = null;
  }

  if (map.mounted) map.state = rows;
}

/// Replaces the pedal's custom MIDI map with [entries], keeping the pedal's
/// custom-map options (first PC, level CC range). Every frame waits for its
/// ack; a missing one stops the write (the pedal only switches maps on the
/// commit). Returns whether the pedal took it all.
Future<bool> saveMidiMap(WidgetRef ref, List<MidiMapEntry> entries) async {
  final cfw = ref.read(cfwInfoProvider);

  if (cfw == null || entries.length > MidiMapEntry.maxEntries) return false;

  final service = ref.read(deviceServiceProvider);
  final map = ref.read(midiMapProvider.notifier);

  try {
    for (final frame in buildMidiMapFrames(
      options: cfw.customMapOptions,
      entries: entries,
    )) {
      if (!await service.sendAndAwaitAck(frame)) return false;
    }
  } catch (_) {
    return false;
  }

  if (map.mounted) map.state = [...entries];

  return true;
}
