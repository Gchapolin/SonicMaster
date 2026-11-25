import 'global_setting_writer.dart';
import 'sysex_write_frame.dart';

/// Frames for the community custom firmware (CFW) settings, verified
/// byte-for-byte against frames captured from the CFW web app
/// (docs/cfw-protocol/capture-notes.md).
///
/// The CFW keeps its settings in register `0x2A`: a write is
/// `11 2A <key> <value>`, the whole block reads back with `12 2A`.
abstract final class CfwSettingWriter {
  static const theme = 0x01;
  static const directMonitor = 0x03;
  static const usbRec = 0x04;
  static const pedalMode = 0x06;

  /// Writes one CFW setting: `11 2A <key> <value>`.
  static String setting(int key, int value) =>
      buildSysexWriteFrame([0x11, 0x2A, key & 0xFF, value & 0xFF]);

  /// Screen brightness (10..100 %). The CFW app writes it as a settings-dump
  /// record at address (03, 02), not through register 0x2A.
  static String brightness(int percent) =>
      GlobalSettingWriter.dumpRecord(a0: 0x03, a1: 0x02, value: percent);

  /// Reads the CFW settings block (`12 2A`).
  static String readSettings() => buildSysexWriteFrame([0x12, 0x2A]);

  /// Reads the status block with the DSP load (`12 2B`).
  static String readDsp() => buildSysexWriteFrame([0x12, 0x2B]);
}
