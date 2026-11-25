import 'dart:convert';
import 'dart:io';

import 'package:sonicmaster/model/cfw_models.dart';
import 'package:sonicmaster/model/character_map.dart';
import 'package:sonicmaster/model/command_library.dart';
import 'package:sonicmaster/model/data_assets.dart';
import 'package:sonicmaster/model/device_capabilities.dart';
import 'package:sonicmaster/model/effect_library.dart';
import 'package:sonicmaster/model/effect_signatures.dart';
import 'package:sonicmaster/model/modules.dart';
import 'package:sonicmaster/model/parameter_tables.dart';

/// Loads the real bundled data tables from disk (the cwd is the app package root
/// under `flutter test`), mirroring [DataAssets.load] without a rootBundle so
/// tests can override `dataAssetsProvider` with real data.
DataAssets loadTestDataAssets() {
  Map<String, dynamic> read(String name) =>
      jsonDecode(File('assets/data/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  final effects = EffectLibrary.fromJson(read('effect_library'));
  final commands = CommandLibrary.fromJson(read('command_library'));

  addCfwModels(
    effects,
    commands,
    parseCfwModels(read('cfw_fx_models'), read('cfw_eq_models')),
  );
  addCfwStockExtras(effects, read('cfw_fx_models'));

  return DataAssets(
    effects: effects,
    commands: commands,
    modules: Modules.fromJson(read('modules')),
    characters: CharacterMap.fromJson(read('character_map')),
    signatures: EffectSignatures.build(read('effect_signatures'), effects),
    parameters: ParameterTables.fromJson(
      read('algid_location_map'),
      read('value_reverse_lookup'),
    ),
    capabilities: DeviceCapabilities.fromJson(read('device_capabilities')),
  );
}
