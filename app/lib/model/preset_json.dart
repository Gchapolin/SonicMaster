import '../l10n/presets_text.dart';
import 'cfw_scenes.dart';
import 'data_assets.dart';
import 'decoded_preset_state.dart';

/// How many tempo-sync note divisions there are (1/1 … 1/16): see
/// `syncDivisions` in the module editor.
const syncDivisionCount = 11;

/// The `version` value every exported preset carries.
const presetJsonVersion = '1.0';

/// Physical module slots, in a stable export order (ids 0-8). The amp slot
/// (AMP, id 3) is emitted as "Clone" (effect/params from id 9) in clone mode.
const _physicalModules = [
  'NR',
  'FX1',
  'DRV',
  'AMP',
  'IR',
  'EQ',
  'FX2',
  'DLY',
  'RVB',
];

/// Serializes the live decoded preset to the web-compatible JSON schema;
/// [isCfw] when it comes from a CFW pedal.
Map<String, dynamic> presetToJson({
  required DecodedPresetState state,
  required Map<int, int> selected,
  required Map<int, Map<int, num>> params,
  required DataAssets data,
  String? presetName,
  bool isCfw = false,
}) {
  final modules = <String, dynamic>{};

  for (final name in _physicalModules) {
    final clone = name == 'AMP' && state.isCloneMode;
    final effModuleId = clone ? 9 : (data.modules.idOf(name) ?? -1);
    final key = clone ? 'Clone' : name;
    final fxId = selected[effModuleId];
    final def = fxId == null ? null : data.effects.byId(fxId);
    final vals = params[effModuleId] ?? const <int, num>{};
    final paramMap = <String, dynamic>{};

    if (def != null) {
      for (final p in def.params) {
        // The CFW's extra knobs only from a CFW pedal; like the CFW app, the
        // stock knob a CFW slot replaces still goes in the file.
        if (p.onlyOnCfw == true && !isCfw) continue;

        if (vals[p.algId] != null) paramMap[p.name] = vals[p.algId];
      }
    }

    modules[key] = {
      'enabled': state.moduleStates[name] ?? false,
      'effect': def?.name,
      'parameters': paramMap,
    };
  }

  return {
    'version': presetJsonVersion,
    'presetName': presetName ?? '',
    'ampMode': state.isCloneMode ? 'Clone' : 'Normal',
    'presetVolume': state.presetVolume,
    'presetBpm': state.presetBpm,
    'modules': modules,
    'signalChain': state.chainOrder,
  };
}

/// A converted preset ready to push to the device (ids, not names).
class ImportedPreset {
  ImportedPreset({
    required this.isCloneMode,
    required this.presetVolume,
    required this.presetBpm,
    required this.moduleStates,
    required this.selectedEffects,
    required this.parameters,
    required this.chainOrder,
    required this.warnings,
    this.footswitch,
    this.scenes,
  });

  final bool isCloneMode;
  final int presetVolume;
  final int presetBpm;
  final Map<int, bool> moduleStates; // physical moduleId -> on
  final Map<int, int> selectedEffects; // effect moduleId (9 for clone) -> fxId
  final Map<int, Map<int, num>> parameters; // effect moduleId -> algId -> value
  final List<String> chainOrder; // module names
  final List<String> warnings;

  /// FS1 / FS2 module bit masks (bit = 1 << moduleId); null when the file has
  /// none (a stock export), so the pedal's assignment is left alone.
  final ({int fs1, int fs2})? footswitch;

  /// CFW scene records by module; null when the file has no "scenes" (leave the
  /// pedal's scenes alone), empty when it has none in use (clear them all).
  final Map<int, SceneRecord>? scenes;
}

/// Validates and converts a preset JSON doc. Throws [FormatException] on an
/// unsupported version or an unknown effect name; collects non-fatal issues
/// (unknown module, clamped/defaulted params) into `warnings`.
ImportedPreset importedPresetFromJson(
  Map<String, dynamic> json,
  DataAssets data,
) {
  if (json['version'] != presetJsonVersion) {
    throw FormatException(
      PresetsText.current.unsupportedPresetVersion(json['version']),
    );
  }

  final warnings = <String>[];
  final isCloneMode = json['ampMode'] == 'Clone';
  final presetVolume = (((json['presetVolume'] as num?) ?? 75).clamp(
    0,
    100,
  )).round();
  // Optional key (added after v1.0 shipped): absent in older exports -> default.
  // Range mirrors the hardware / official app (40–260).
  final presetBpm = (((json['presetBpm'] as num?) ?? 120).clamp(
    40,
    260,
  )).round();

  final moduleStates = <int, bool>{};
  final selectedEffects = <int, int>{};
  final parameters = <int, Map<int, num>>{};

  int? effectIdByName(String name) {
    for (final e in data.effects.effects.entries) {
      if (e.value.name == name) return e.key;
    }

    return null;
  }

  final modules =
      (json['modules'] as Map?)?.cast<String, dynamic>() ?? const {};

  modules.forEach((key, raw) {
    final m = (raw as Map).cast<String, dynamic>();
    final isClone = key == 'Clone';
    final physId = data.modules.idOf(isClone ? 'AMP' : key);

    if (physId == null) {
      warnings.add('Unknown module "$key" — skipped');
      return;
    }

    final effModuleId = isClone ? 9 : physId;

    moduleStates[physId] = (m['enabled'] as bool?) ?? true;

    final effectName = m['effect'] as String?;

    if (effectName == null) return;

    final fxId = effectIdByName(effectName);

    if (fxId == null) {
      throw FormatException(PresetsText.current.unknownEffect(key, effectName));
    }

    selectedEffects[effModuleId] = fxId;

    final def = data.effects.byId(fxId);

    if (def == null) return;

    final jsonParams =
        (m['parameters'] as Map?)?.cast<String, dynamic>() ?? const {};

    final upper = <String, dynamic>{
      for (final e in jsonParams.entries) e.key.toUpperCase(): e.value,
    };

    final out = <int, num>{};
    // The file's values by slot, for the tempo knobs' sync state.
    final given = <int, num>{
      for (final p in def.params)
        if (upper[p.name.toUpperCase()] case final num v) p.algId: v,
    };

    for (final p in def.params) {
      var v = upper[p.name.toUpperCase()] as num?;
      // Synced, a tempo knob holds a note-division index, not ms / Hz.
      final (lo, hi) = p.isSynced(given)
          ? (0, syncDivisionCount - 1)
          : (p.min, p.max);

      if (v == null) {
        // A file from stock firmware has none of the CFW's extra knobs: leave
        // them to the pedal.
        if (p.onlyOnCfw == true) continue;

        v = p.defaultValue;
        warnings.add(
          '$key.${p.name} missing — using default ${p.defaultValue}',
        );
      } else if (lo != null && hi != null) {
        final c = v.clamp(lo, hi);

        if (c != v) {
          warnings.add('$key.${p.name} clamped from $v to $c');
          v = c;
        }
      }

      out[p.algId] = v;
    }

    parameters[effModuleId] = out;
  });

  final fs = (json['footswitch'] as Map?)?.cast<String, dynamic>();
  final scenesJson = (json['scenes'] as Map?)?.cast<String, dynamic>();

  return ImportedPreset(
    footswitch: fs == null
        ? null
        : (
            fs1: (fs['fs1'] as num? ?? 0).toInt(),
            fs2: (fs['fs2'] as num? ?? 0).toInt(),
          ),
    scenes: scenesJson == null
        ? null
        : _scenesFromJson(scenesJson, selectedEffects, data, warnings),
    isCloneMode: isCloneMode,
    presetVolume: presetVolume,
    presetBpm: presetBpm,
    moduleStates: moduleStates,
    selectedEffects: selectedEffects,
    parameters: parameters,
    chainOrder: ((json['signalChain'] as List?) ?? const []).cast<String>(),
    warnings: warnings,
  );
}

/// The CFW app's "scenes" object: per module ("Clone" = 9), SC1 / SC2 knob
/// values by name and an optional "onOff" {SC1|SC2: bool}. A module with
/// "enabled": false is not in the scenes.
Map<int, SceneRecord> _scenesFromJson(
  Map<String, dynamic> json,
  Map<int, int> selectedEffects,
  DataAssets data,
  List<String> warnings,
) {
  final out = <int, SceneRecord>{};

  json.forEach((key, raw) {
    final module = key == 'Clone' ? 9 : data.modules.idOf(key);

    if (module == null || module > 9 || raw is! Map) {
      warnings.add('scenes: unknown module "$key" — skipped');
      return;
    }

    final m = raw.cast<String, dynamic>();

    if (m['enabled'] == false) return;

    final fxId = selectedEffects[module];
    final def = fxId == null ? null : data.effects.byId(fxId);

    if (def == null) {
      warnings.add('scenes: $key has no effect in this preset — skipped');
      return;
    }

    final byName = {for (final p in def.params) p.name.toUpperCase(): p.algId};

    Map<int, double> values(Object? v) => {
      for (final e in ((v as Map?) ?? const {}).entries)
        ?byName[(e.key as String).toUpperCase()]: (e.value as num).toDouble(),
    };

    final onOff = (m['onOff'] as Map?) ?? const {};

    out[module] = SceneRecord(
      module: module,
      sc1On: onOff['SC1'] as bool?,
      sc2On: onOff['SC2'] as bool?,
      sc1: values(m['SC1']),
      sc2: values(m['SC2']),
    );
  });

  return out;
}
