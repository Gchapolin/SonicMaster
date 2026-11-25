import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/protocol/cfw_setting_writer.dart';

/// Every expected frame was captured from the CFW web app talking to a
/// Pocket Master on CFW 1.0.2 (docs/cfw-protocol/capture-notes.md).
void main() {
  test('theme writes', () {
    expect(
      CfwSettingWriter.setting(CfwSettingWriter.theme, 0).toLowerCase(),
      '8080f00f000001000000040101020a00010000f7',
    );
    expect(
      CfwSettingWriter.setting(CfwSettingWriter.theme, 3).toLowerCase(),
      '8080f00f090001000000040101020a00010003f7',
    );
  });

  test('Direct Monitor, USB Rec and pedal mode writes', () {
    expect(
      CfwSettingWriter.setting(CfwSettingWriter.directMonitor, 0).toLowerCase(),
      '8080f00d0a0001000000040101020a00030000f7',
    );
    expect(
      CfwSettingWriter.setting(CfwSettingWriter.usbRec, 1).toLowerCase(),
      '8080f00b060001000000040101020a00040001f7',
    );
    expect(
      CfwSettingWriter.setting(CfwSettingWriter.pedalMode, 1).toLowerCase(),
      '8080f0090c0001000000040101020a00060001f7',
    );
  });

  test('brightness goes through the settings dump record (03, 02)', () {
    expect(
      CfwSettingWriter.brightness(90).toLowerCase(),
      '8080f00b0800010000000a010101010003000200000000050a000000000000f7',
    );
  });

  test('reads of the settings block and of the DSP load', () {
    expect(
      CfwSettingWriter.readSettings().toLowerCase(),
      '8080f0010f0001000000020102020af7',
    );
    expect(
      CfwSettingWriter.readDsp().toLowerCase(),
      '8080f001080001000000020102020bf7',
    );
  });
}
