import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/presets_text.dart';
import '../model/cfw_models.dart';
import '../model/chain_order.dart';
import '../model/effect_parameter.dart';
import '../model/preset_json.dart';
import '../protocol/cfw_scene_codec.dart';
import '../protocol/footswitch_frame.dart';
import '../protocol/param_value_key.dart';
import '../protocol/preset_field_frame.dart';
import 'cfw_providers.dart';
import 'data_providers.dart';
import 'device_providers.dart';
import 'file_download.dart';
import 'names_providers.dart';
import 'preset_providers.dart';

/// Exports the current decoded preset to a user-chosen JSON file. No-op if no
/// preset is loaded or the user cancels the dialog.
Future<void> exportPreset(WidgetRef ref) async {
  final data = ref.read(dataAssetsProvider).valueOrNull;
  final state = ref.read(currentPresetStateProvider);

  if (data == null || state == null) return;

  final status = ref.read(presetLoadStatusProvider.notifier);
  final cur = ref.read(currentPresetProvider);
  final name =
      (cur == null ? null : ref.read(presetNamesProvider)[cur]) ??
      cur?.label ??
      'preset';

  final str = const JsonEncoder.withIndent('  ').convert(
    presetToJson(
      state: state,
      selected: ref.read(currentSelectedEffectsProvider),
      params: ref.read(currentParametersProvider),
      data: data,
      presetName: name,
      isCfw: ref.read(cfwInfoProvider) != null,
    ),
  );

  try {
    final saved = await saveBytesFile(
      fileName: '${name.replaceAll(RegExp(r'\s+'), '_')}.json',
      bytes: utf8.encode(str),
      dialogTitle: PresetsText.current.exportDialogTitle,
      extensions: const ['json'],
    );

    if (saved == null) return; // cancelled

    status.state = PresetsText.current.exportedTo(saved);
  } catch (e) {
    status.state = PresetsText.current.exportFailed(e);
  }
}

/// Imports a preset JSON file and pushes it to the connected pedal (live state
/// only — Save persists it to a slot). Requires a connection.
Future<void> importPreset(WidgetRef ref) async {
  final data = ref.read(dataAssetsProvider).valueOrNull;

  if (data == null) return;

  final status = ref.read(presetLoadStatusProvider.notifier);

  final ImportedPreset imported;

  try {
    final res = await FilePicker.platform.pickFiles(
      dialogTitle: PresetsText.current.importDialogTitle,
      type: .custom,
      allowedExtensions: const ['json'],
      withData: true,
    );

    final bytes = res?.files.single.bytes;

    if (bytes == null) return; // cancelled

    final str = utf8.decode(bytes);

    imported = importedPresetFromJson(
      jsonDecode(str) as Map<String, dynamic>,
      data,
    );
  } catch (e) {
    status.state = PresetsText.current.importFailed(e);

    return;
  }

  await pushImportedPreset(ref, imported);
}

/// Pushes an [imported] preset to the connected pedal's live state (Save
/// persists it to a slot): volume, BPM, modules, effects, chain, knobs, and,
/// when the file has them, the footswitches and the CFW scenes. No-op while a
/// preset is loading. Returns false when it did not complete.
Future<bool> pushImportedPreset(WidgetRef ref, ImportedPreset imported) async {
  final data = ref.read(dataAssetsProvider).valueOrNull;

  if (data == null) return false;

  final status = ref.read(presetLoadStatusProvider.notifier);

  if (ref.read(presetLoadingProvider)) return false;

  if (cfwOnlyEffectName(ref, imported) case final name?) {
    status.state = PresetsText.current.needsCfw(name);

    return false;
  }

  ref.read(presetLoadingProvider.notifier).state = true;
  final service = ref.read(deviceServiceProvider);
  final c = data.commands;
  var skipped = 0;

  Future<void> send(String? frame) async {
    if (frame == null) {
      skipped++;

      return;
    }

    await service.sendFrame(frame);
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  try {
    await send(c.globalCommand('presetVolume', imported.presetVolume));
    // BPM has no captured command — synthesize it (0402 field 2, 16-bit LE).
    await send(
      PresetFieldFrame.build(
        field: PresetFieldFrame.bpmField,
        value: imported.presetBpm,
      ),
    );

    for (final e in imported.moduleStates.entries) {
      await send(e.value ? c.moduleOn(e.key) : c.moduleOff(e.key));
    }

    await send(imported.isCloneMode ? c.ampClone : c.ampFactory);

    for (final e in imported.selectedEffects.entries) {
      await send(c.effectType(e.key, e.value));
    }

    await send(
      c.chainOrderCommand(chainKey(collapseChain(imported.chainOrder))),
    );

    final isCfw = ref.read(cfwInfoProvider) != null;

    for (final me in imported.parameters.entries) {
      final fxId = imported.selectedEffects[me.key];
      final def = fxId == null ? null : data.effects.byId(fxId);
      // Not the knobs this firmware lacks (the CFW's extras on stock).
      final lacks = {
        for (final p in def?.params ?? const <EffectParameter>[])
          if (!p.isShownOn(isCfw: isCfw)) p.algId,
      };

      for (final pe in me.value.entries) {
        if (lacks.contains(pe.key)) continue;

        await send(
          c.parameterCommand(me.key, pe.key, formatParamValueKey(pe.value)),
        );
      }
    }

    // CFW extras, when the file has them (the CFW app's export).
    if (imported.footswitch case final fs?) {
      for (var m = 0; m < 9; m++) {
        for (final (isFs2, mask) in [(false, fs.fs1), (true, fs.fs2)]) {
          await send(
            FootswitchFrame.build(
              moduleId: m,
              isFs2: isFs2,
              isOn: (mask >> m) & 1 == 1,
            ),
          );
        }
      }
    }

    final scenes = imported.scenes;

    if (scenes != null && isCfw) {
      // Clear only records the pedal is known to hold, then write the file's.
      for (final m in ref.read(sceneRecordsProvider).keys) {
        if (!scenes.containsKey(m)) await send(clearSceneRecordFrame(m));
      }

      for (final r in scenes.values) {
        await send(buildSceneRecordFrame(r));
      }
    }

    await refreshDecodedState(ref);

    if (isCfw) await refreshScenes(ref);
    ref.read(presetModifiedProvider.notifier).state = true;

    status.state = PresetsText.current.imported(
      skipped,
      imported.warnings.length,
    );
  } catch (e) {
    status.state = PresetsText.current.importPushFailed(e);

    return false;
  } finally {
    ref.read(presetLoadingProvider.notifier).state = false;
  }

  return true;
}

/// The name of a CFW-only model [imported] uses when the pedal is not on the
/// CFW (it would not understand the select), else null.
String? cfwOnlyEffectName(WidgetRef ref, ImportedPreset imported) {
  if (ref.read(cfwInfoProvider) != null) return null;

  final data = ref.read(dataAssetsProvider).valueOrNull;

  for (final fxId in imported.selectedEffects.values) {
    if (cfwModelIds.contains(fxId)) return data?.effects.byId(fxId)?.name;
  }

  return null;
}
