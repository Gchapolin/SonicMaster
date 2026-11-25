import '../model/cfw_exp.dart';
import 'cfw_settings_decoder.dart';
import 'sysex_write_frame.dart';

/// EXP A-D of the loaded preset live in register `0x3D`: four 6-byte slots,
/// `<module> <algId> <mode> <min %> <max %> 00`; a free slot starts with `FF`.
/// Verified against frames captured from the CFW web app
/// (docs/cfw-protocol/capture-notes.md).
const expSlotCount = 4;
const _slotLength = 6;
const _free = 0xFF;

/// Writes all four slots: `11 3D` + 4 x 6 bytes. [slots] must have four
/// entries; null is a free slot.
String buildExpFrame(List<ExpAssign?> slots) => buildSysexWriteFrame([
  0x11,
  0x3D,
  for (var i = 0; i < expSlotCount; i++)
    ...switch (i < slots.length ? slots[i] : null) {
      null => const [_free, 0, 0, 0, 0, 0],
      final a => [
        a.module & 0xFF,
        a.algId & 0xFF,
        a.mode & 0xFF,
        a.min.clamp(0, 100),
        a.max.clamp(0, 100),
        0,
      ],
    },
]);

/// Reads the four slots (`12 3D`).
String readExpFrame() => buildSysexWriteFrame([0x12, 0x3D]);

/// Decodes the reply `12 3D 01 01` + 4 x 6 bytes. Null for another reply or
/// a truncated block.
List<ExpAssign?>? decodeExpFrame(String frameHex) {
  final bytes = collapseFrame(frameHex);

  if (bytes == null || bytes.length < 6) return null;

  final p = bytes.sublist(4);
  const slotsAt = 4;

  if (p[0] != 0x12 || p[1] != 0x3D) return null;
  if (p.length < slotsAt + expSlotCount * _slotLength) return null;

  return [
    for (var i = slotsAt; i < slotsAt + expSlotCount * _slotLength; i += 6)
      p[i] == _free
          ? null
          : ExpAssign(
              module: p[i],
              algId: p[i + 1],
              mode: p[i + 2] > ExpAssign.momentary
                  ? ExpAssign.continuous
                  : p[i + 2],
              min: p[i + 3].clamp(0, 100),
              max: p[i + 4].clamp(0, 100),
            ),
  ];
}
