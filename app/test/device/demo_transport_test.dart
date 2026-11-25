import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/demo_transport.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/model/cfw_global_eq.dart';
import 'package:sonicmaster/model/cfw_scenes.dart';
import 'package:sonicmaster/model/character_map.dart';
import 'package:sonicmaster/model/command_library.dart';
import 'package:sonicmaster/model/modules.dart';
import 'package:sonicmaster/protocol/cfw_geq_codec.dart';
import 'package:sonicmaster/protocol/cfw_scene_codec.dart';
import 'package:sonicmaster/protocol/cfw_setting_writer.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/global_settings_decoder.dart';
import 'package:sonicmaster/protocol/name_dump_decoder.dart';
import 'package:sonicmaster/protocol/preset_state_decoder.dart';

Map<String, dynamic> _read(String f) =>
    jsonDecode(File('assets/data/$f.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  late DeviceService service;

  setUp(() async {
    service = DeviceService(DemoTransport())..startListening();
    await service.connect();
  });
  tearDown(() => service.dispose());

  test('answers the stock reads with decodable dumps', () async {
    final state = PresetStateDecoder(
      Modules.fromJson(_read('modules')),
    ).decode((await service.requestStateDump())!);

    expect(state!.chainOrder, hasLength(9));
    expect(
      const GlobalSettingsDecoder().decode(
        (await service.requestGlobalSettings())!,
      ),
      isNotNull,
    );
    expect(
      decodePresetNames(
        (await service.requestPresetNames())!,
        CharacterMap.fromJson(_read('character_map')),
      ),
      isNotEmpty,
    );
  });

  test('acks writes, and a preset select changes the loaded preset', () async {
    final commands = CommandLibrary.fromJson(_read('command_library'));
    final before = await service.requestStateDump();

    expect(
      await service.sendAndAwaitAck(commands.presetSelect(.user, 3)!),
      isTrue,
    );
    expect(await service.requestStateDump(), isNot(before));
  });

  test('is a CFW pedal whose settings read back what was written', () async {
    final info = decodeCfwSettingsFrame((await service.requestCfwSettings())!)!;

    expect(info.version, startsWith('CFW'));
    await service.sendAndAwaitAck(
      CfwSettingWriter.setting(CfwSettingWriter.theme, 5),
    );
    await service.sendAndAwaitAck(CfwSettingWriter.brightness(40));

    final after = decodeCfwSettingsFrame(
      (await service.requestCfwSettings())!,
    )!;

    expect(after.theme, 5);
    expect(after.brightness, 40);
    expect(await service.requestDspLoad(), inInclusiveRange(0, 100));
  });

  test('keeps the Global EQ and the scenes it is sent', () async {
    const eq = CfwGlobalEq(
      isOn: true,
      model: 2,
      slots: [1, 0, 0, 0, 0, 50, 38, 69],
    );

    await service.sendAndAwaitAck(buildGlobalEqFrame(eq));

    final back = decodeGlobalEqFrame((await service.requestGlobalEq())!)!;

    expect(back.model, 2);
    expect(back.slots, eq.slots);

    await service.sendFrame(
      buildSceneRecordFrame(
        const SceneRecord(module: 3, sc1On: false, sc1: {1: 96}),
      ),
    );
    await service.sendFrame(selectSceneFrame(1));

    final records = decodeSceneRecordsFrame(
      (await service.requestSceneRecords())!,
    );

    expect(records.single.module, 3);
    expect(records.single.sc1, {1: 96.0});
    expect(records.single.sc1On, isFalse);
    expect(decodeCurrentSceneFrame((await service.requestCurrentScene())!), 1);

    await service.sendFrame(clearSceneRecordFrame(3));
    expect(
      decodeSceneRecordsFrame((await service.requestSceneRecords())!),
      isEmpty,
    );
  });
}
