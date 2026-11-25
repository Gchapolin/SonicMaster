import 'dart:typed_data';

import '../model/midi_map.dart';
import 'cfw_settings_decoder.dart';
import 'crc16_modbus.dart';
import 'sysex_chunk_upload.dart';
import 'sysex_write_frame.dart';

/// The CFW's custom MIDI map lives in register `0x39`: a header, the rows in
/// batches of eight, a commit. Verified against the maps the CFW web app
/// saved (docs/cfw-protocol/capture-notes.md, capture session 5).
const _magic = [0x50, 0x4D, 0x4D, 0x4D]; // "PMMM"
const _version = 1;
const _batch = 8;
const _entryLength = 8;

/// CRC-16/MODBUS over `"PMMM" <version> <options> <count u16 LE>` + the rows.
int midiMapCrc(int options, List<MidiMapEntry> entries) => Crc16Modbus.ofBytes([
  ..._magic,
  _version,
  options & 0xFF,
  entries.length & 0xFF,
  entries.length >> 8,
  for (final e in entries) ...e.toBytes(),
]);

/// The frames that replace the pedal's custom map, to be sent one by one,
/// each after the pedal's ack. [options]: bit0 the first PC is PC 1, bit1
/// level CCs span 0..127.
List<String> buildMidiMapFrames({
  required int options,
  required List<MidiMapEntry> entries,
}) {
  final crc = midiMapCrc(options, entries);
  final crcBytes = [crc & 0xFF, crc >> 8];

  return [
    buildSysexWriteFrame([
      0x11,
      0x39,
      0x00,
      ..._magic,
      _version,
      options & 0xFF,
      entries.length & 0xFF,
      entries.length >> 8,
      0,
      0,
      0,
      0,
      ...crcBytes,
      0,
      0,
    ]),
    for (var i = 0; i < entries.length; i += _batch)
      ...SysexChunkUpload.buildChunks(
        Uint8List.fromList([
          0x11,
          0x39,
          0x01,
          i,
          (entries.length - i).clamp(0, _batch),
          for (final e in entries.skip(i).take(_batch)) ...e.toBytes(),
        ]),
      ).map((f) => f.toLowerCase()),
    buildSysexWriteFrame([0x11, 0x39, 0x02, ...crcBytes]),
  ];
}

/// Reads the map's summary (`12 39 00`).
String readMidiMapInfoFrame() => buildSysexWriteFrame([0x12, 0x39, 0x00]);

/// Reads the rows from [first] on, eight at most (`12 39 01 <first>`).
String readMidiMapPageFrame(int first) =>
    buildSysexWriteFrame([0x12, 0x39, 0x01, first & 0xFF]);

/// Decodes `12 39 00 01 01 <flags> <count> <max> <options> .. .. .. ..
/// <crc16 LE> ...`. Null for another reply or a short one.
({int count, int options, int crc})? decodeMidiMapInfo(String frameHex) {
  final bytes = collapseFrame(frameHex);

  if (bytes == null || bytes.length < 4 + 15) return null;

  final p = bytes.sublist(4);

  if (p[0] != 0x12 || p[1] != 0x39 || p[2] != 0x00) return null;

  return (count: p[6], options: p[8], crc: p[13] | (p[14] << 8));
}

/// Decodes `12 39 01 <first> <n> <n x 8 bytes>`. Null for another reply or a
/// truncated page.
({int first, List<MidiMapEntry> entries})? decodeMidiMapPage(String frameHex) {
  final bytes = collapseFrame(frameHex);

  if (bytes == null || bytes.length < 4 + 5) return null;

  final p = bytes.sublist(4);

  if (p[0] != 0x12 || p[1] != 0x39 || p[2] != 0x01) return null;

  final n = p[4];

  if (p.length < 5 + n * _entryLength) return null;

  return (
    first: p[3],
    entries: [
      for (var i = 0; i < n; i++)
        MidiMapEntry.fromBytes(
          p.sublist(5 + i * _entryLength, 13 + i * _entryLength),
        ),
    ],
  );
}
