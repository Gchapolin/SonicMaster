import 'dart:typed_data';

import '../model/tuner_reading.dart';
import 'cfw_settings_decoder.dart';
import 'sysex_write_frame.dart';

/// The CFW pedal's tuner: commands on register `0x3E`, readings polled from
/// `0x3F` while it is open (docs/cfw-protocol/capture-notes.md).

/// Opens or closes the pedal's tuner: `11 3E 01` / `11 3E 00`.
String tunerOpenFrame({required bool isOpen}) =>
    buildSysexWriteFrame([0x11, 0x3E, isOpen ? 1 : 0]);

/// Sets the reference pitch: `11 3E 02 <Hz u16 LE>` (430..450).
String tunerA4Frame(int hz) =>
    buildSysexWriteFrame([0x11, 0x3E, 0x02, hz & 0xFF, (hz >> 8) & 0xFF]);

/// What the output does while tuning: `11 3E 04 <0 mute | 1 bypass> 00`.
String tunerOutputFrame({required bool isMuted}) =>
    buildSysexWriteFrame([0x11, 0x3E, 0x04, isMuted ? 0 : 1, 0x00]);

/// Reads one tuner reading (`12 3F`).
String readTunerFrame() => buildSysexWriteFrame([0x12, 0x3F]);

/// Decodes a `12 3F` reply: `<version 1> <flags> <note, FF none> <octave i8,
/// 7F none> <cents f32> <Hz f32> <A4 u16> <seq u16> <age> 00`, little-endian.
/// Null for another reply, another version or a short frame.
TunerReading? decodeTunerFrame(String frameHex) {
  final bytes = collapseFrame(frameHex);

  if (bytes == null || bytes.length < 24) return null;

  final p = bytes.sublist(4);

  if (p[0] != 0x12 || p[1] != 0x3F || p[2] != 1) return null;

  final data = ByteData.sublistView(Uint8List.fromList(p));
  final note = p[4];
  final octave = data.getInt8(5);

  double finite(int at) {
    final v = data.getFloat32(at, Endian.little);

    return v.isFinite ? v : 0;
  }

  return TunerReading(
    flags: p[3],
    note: note < 12 ? note : null,
    octave: octave == 127 ? null : octave,
    cents: finite(6),
    hz: finite(10),
    a4: data.getUint16(14, Endian.little),
  );
}
