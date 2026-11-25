import 'cfw_settings_decoder.dart';
import 'crc8_smbus.dart';
import 'sysex_write_frame.dart';

/// The CFW keeps the order of the 50 User presets in register `0x37`: a table
/// where entry i is the stored slot shown at position i. Reordering rewrites
/// the table only; no preset is moved (docs/cfw-protocol/capture-notes.md).
const presetOrderLength = 50;

/// At most this many payload bytes go in one packet of the write.
const _chunk = 19;

class PresetOrder {
  const PresetOrder({required this.token, required this.entries});

  /// The table's token: a write must carry the token of the table it replaces.
  final int token;

  /// Position (0-based) -> stored slot (0-based).
  final List<int> entries;

  bool get isIdentity {
    for (var i = 0; i < entries.length; i++) {
      if (entries[i] != i) return false;
    }

    return true;
  }
}

/// Reads the order table (`12 37`).
String readPresetOrderFrame() => buildSysexWriteFrame([0x12, 0x37]);

/// Decodes `12 37 01 <state> <token> <50 entries>`. Null for another reply, a
/// short table or one that is not a permutation of the 50 slots.
PresetOrder? decodePresetOrderFrame(String frameHex) {
  final bytes = collapseFrame(frameHex);

  if (bytes == null || bytes.length < 9) return null;

  final p = bytes.sublist(4);
  const entriesAt = 5;

  if (p[0] != 0x12 || p[1] != 0x37) return null;
  if (p.length < entriesAt + presetOrderLength) return null;

  final entries = p.sublist(entriesAt, entriesAt + presetOrderLength);

  if (entries.toSet().length != presetOrderLength ||
      entries.any((e) => e >= presetOrderLength)) {
    return null;
  }

  return PresetOrder(token: p[4], entries: entries);
}

/// [entries] with the preset at position [from] moved to position [to]
/// (0-based); the ones in between shift by one.
List<int> movePreset(List<int> entries, {required int from, required int to}) {
  final out = [...entries];

  out.insert(to, out.removeAt(from));

  return out;
}

/// The packets that write the table: `11 37 01 <token> <entries>` split into
/// packets `<crc> <total> <index> <len> <payload>`, to be sent one by one,
/// each after the pedal's ack.
List<String> buildPresetOrderFrames({
  required int token,
  required List<int> entries,
}) {
  final payload = [0x11, 0x37, 0x01, token & 0xFF, ...entries];
  final total = (payload.length / _chunk).ceil();
  String nib(int b) =>
      '0${(b >> 4).toRadixString(16)}0${(b & 0xF).toRadixString(16)}';
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');

  return [
    for (var i = 0; i < total; i++)
      () {
        final part = payload.skip(i * _chunk).take(_chunk).toList();
        final logical = [total, i, part.length, ...part];
        final crc = int.parse(
          Crc8Smbus.ofHex(logical.map(hex).join()),
          radix: 16,
        );

        return '8080f0${[crc, ...logical].map(nib).join()}f7';
      }(),
  ];
}
