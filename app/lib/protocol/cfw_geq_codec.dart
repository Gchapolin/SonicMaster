import '../model/cfw_global_eq.dart';
import 'cfw_settings_decoder.dart';
import 'sysex_write_frame.dart';

/// Global EQ frames (register 0x3A), verified against captured frames
/// (docs/cfw-protocol/capture-notes.md): `11 3A [on] [model] [8 slot bytes]`.
/// The whole block is sent on every change; slot bytes are signed.
String buildGlobalEqFrame(CfwGlobalEq eq) => buildSysexWriteFrame([
  0x11,
  0x3A,
  eq.isOn ? 1 : 0,
  eq.model & 0xFF,
  for (var i = 0; i < 8; i++) (i < eq.slots.length ? eq.slots[i] : 0) & 0xFF,
]);

String readGlobalEqFrame() => buildSysexWriteFrame([0x12, 0x3A]);

/// Decodes the `12 3A` reply; null for anything else or a short block.
CfwGlobalEq? decodeGlobalEqFrame(String frameHex) {
  final b = collapseFrame(frameHex);

  if (b == null || b.length < 16 || b[4] != 0x12 || b[5] != 0x3A) return null;

  return CfwGlobalEq(
    isOn: b[6] != 0,
    model: b[7],
    slots: [for (final v in b.sublist(8, 16)) v.toSigned(8)],
  );
}
