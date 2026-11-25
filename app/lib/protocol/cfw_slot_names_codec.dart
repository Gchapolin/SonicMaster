import 'cfw_settings_decoder.dart';
import 'sysex_write_frame.dart';

/// The community custom firmware (CFW) has 10 User IR and 10 User Profile
/// slots with 32-character names, read at connect from registers `0x28`
/// (IRs) and `0x29` (profiles): docs/cfw-protocol/capture-notes.md.
const cfwIrNamesRegister = 0x28;
const cfwProfileNamesRegister = 0x29;

const _nameLength = 32;

/// The effect id of User IR slot [slot] (0-based): 416-420 are the stock five,
/// 421 is a factory cab, 422-426 are the CFW's slots 6-10.
int cfwIrEffectId(int slot) => slot < 5 ? 416 + slot : 417 + slot;

/// The effect id of User Profile slot [slot] (0-based): 901-910.
int cfwProfileEffectId(int slot) => 901 + slot;

/// Reads the names of [register] (`12 28` or `12 29`).
String readCfwSlotNamesFrame(int register) =>
    buildSysexWriteFrame([0x12, register]);

/// Decodes the reply to [readCfwSlotNamesFrame]: `12 <register> 01 <count>
/// <kind>` then `count` zero-padded ASCII names of 32 bytes. Null for another
/// reply or a truncated block.
List<String>? decodeCfwSlotNames(String frameHex, int register) {
  final bytes = collapseFrame(frameHex);

  if (bytes == null || bytes.length < 9) return null;

  final p = bytes.sublist(4);

  if (p[0] != 0x12 || p[1] != register) return null;

  final count = p[3];
  const namesAt = 5;

  if (p.length < namesAt + count * _nameLength) return null;

  return [
    for (var i = 0; i < count; i++)
      String.fromCharCodes(
        p
            .sublist(namesAt + i * _nameLength, namesAt + (i + 1) * _nameLength)
            .takeWhile((b) => b != 0),
      ).trim(),
  ];
}
