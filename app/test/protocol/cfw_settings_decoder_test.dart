import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';

import '../fixtures/cfw_dumps.dart';

void main() {
  test('the captured block decodes version and every setting', () {
    final info = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

    expect(info.version, 'CFW1.0.2');
    expect(info.theme, 3);
    expect(info.brightness, 100);
    expect(info.directMonitor, isTrue);
    expect(info.usbRec, 0);
    expect(info.pedalMode, 0);
    expect(info.settings[0x10], 2); // current scene SC2
    expect(info.settings.length, 12);
  });

  test('the trailing capability word (tag 4) is decoded, and kept', () {
    final info = decodeCfwSettingsFrame(cfwSettingsOriginal)!;

    expect(info.capabilities, 0xcfff8f7f);
    expect(info.extraCapabilities, 0x09cf);
    expect(info.copyWithSetting(0x01, 5).extraCapabilities, 0x09cf);
  });

  test('brightness 90 reads back as 90', () {
    expect(decodeCfwSettingsFrame(cfwSettingsBrightness90)!.brightness, 90);
  });

  test('theme Default reads back as 0', () {
    expect(decodeCfwSettingsFrame(cfwSettingsThemeDefault)!.theme, 0);
  });

  test('the current scene key follows the pedal', () {
    expect(decodeCfwSettingsFrame(cfwSettingsSceneSc1)!.settings[0x10], 1);
  });

  test('a truncated block is not decoded', () {
    final cut = cfwSettingsOriginal.substring(0, 120);

    expect(decodeCfwSettingsFrame('${cut}f7'), isNull);
  });

  test('a reply without the CFW version string is not decoded', () {
    // 'C' (0x43) of "CFW" replaced by 'X' (0x58).
    final stock = cfwSettingsOriginal.replaceFirst(
      '0001040304060507',
      '0001050804060507',
    );

    expect(decodeCfwSettingsFrame(stock), isNull);
  });

  test('a frame that is not a 12 2A reply is not decoded', () {
    expect(
      decodeCfwSettingsFrame('8080F00B02000100000003010400080000F7'),
      isNull,
    );
    expect(decodeCfwSettingsFrame('not hex'), isNull);
  });

  test('copyWithSetting replaces one key and keeps the rest', () {
    final info = decodeCfwSettingsFrame(cfwSettingsOriginal)!;
    final changed = info.copyWithSetting(0x01, 5);

    expect(changed.theme, 5);
    expect(changed.brightness, 100);
    expect(info.theme, 3);
  });
}
