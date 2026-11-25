import 'dart:convert';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'cfw_models.dart';
import 'character_map.dart';
import 'command_library.dart';
import 'device_capabilities.dart';
import 'effect_library.dart';
import 'effect_signatures.dart';
import 'modules.dart';
import 'parameter_tables.dart';

/// Loads all device data tables from bundled JSON assets.
class DataAssets {
  const DataAssets({
    required this.effects,
    required this.commands,
    required this.modules,
    required this.characters,
    required this.signatures,
    required this.parameters,
    required this.capabilities,
  });

  final EffectLibrary effects;
  final CommandLibrary commands;
  final Modules modules;
  final CharacterMap characters;
  final EffectSignatures signatures;
  final ParameterTables parameters;
  final DeviceCapabilities capabilities;

  static Future<DataAssets> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;

    Future<Map<String, dynamic>> read(String name) async =>
        jsonDecode(await b.loadString('assets/data/$name.json'))
            as Map<String, dynamic>;

    final effects = EffectLibrary.fromJson(await read('effect_library'));
    final commands = CommandLibrary.fromJson(await read('command_library'));

    // Before the signatures: they look the models up by name.
    addCfwModels(
      effects,
      commands,
      parseCfwModels(await read('cfw_fx_models'), await read('cfw_eq_models')),
    );

    return DataAssets(
      effects: effects,
      commands: commands,
      modules: Modules.fromJson(await read('modules')),
      characters: CharacterMap.fromJson(await read('character_map')),
      signatures: EffectSignatures.build(
        await read('effect_signatures'),
        effects,
      ),
      parameters: ParameterTables.fromJson(
        await read('algid_location_map'),
        await read('value_reverse_lookup'),
      ),
      capabilities: DeviceCapabilities.fromJson(
        await read('device_capabilities'),
      ),
    );
  }
}
