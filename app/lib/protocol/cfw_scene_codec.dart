import 'dart:typed_data';

import '../model/cfw_scenes.dart';
import 'cfw_settings_decoder.dart';
import 'sysex_write_frame.dart';

/// Scene frames of the CFW (registers 0x32 / 0x33), verified against captured
/// frames (docs/cfw-protocol/capture-notes.md).
///
/// Write: `11 33 [module] [flags] [sc1Mask] [sc2Mask] [float32 LE]…` — the
/// module's whole record on every change. flags: bit0 the module takes part,
/// bit1 SC1 overrides on/off (bit2 = on), bit3 SC2 overrides on/off (bit4 =
/// on). Mask bit n = the knob with algId n is overridden; one float per set
/// bit, SC1's in algId order, then SC2's.
String buildSceneRecordFrame(SceneRecord r) {
  var flags = 0x01;

  if (r.sc1On != null) flags |= 0x02 | (r.sc1On! ? 0x04 : 0);
  if (r.sc2On != null) flags |= 0x08 | (r.sc2On! ? 0x10 : 0);

  return buildSysexWriteFrame([
    0x11,
    0x33,
    r.module & 0xFF,
    flags,
    _mask(r.sc1),
    _mask(r.sc2),
    ..._floats(r.sc1),
    ..._floats(r.sc2),
  ]);
}

/// Takes [module] out of the scenes: its record with no flags and no values.
/// (Assumed from the record layout; the CFW app's own "scenes off" frame was
/// not captured.)
String clearSceneRecordFrame(int module) =>
    buildSysexWriteFrame([0x11, 0x33, module & 0xFF, 0x00, 0x00, 0x00]);

/// Selects the live scene: 0 BASE, 1 SC1, 2 SC2.
String selectSceneFrame(int scene) =>
    buildSysexWriteFrame([0x11, 0x32, scene & 0xFF]);

String readSceneRecordsFrame() => buildSysexWriteFrame([0x12, 0x33]);

String readCurrentSceneFrame() => buildSysexWriteFrame([0x12, 0x32]);

int _mask(Map<int, double> values) =>
    values.keys.where((k) => k >= 0 && k < 8).fold(0, (m, k) => m | (1 << k));

List<int> _floats(Map<int, double> values) {
  final keys = values.keys.where((k) => k >= 0 && k < 8).toList()..sort();
  final data = ByteData(4 * keys.length);

  for (final (i, k) in keys.indexed) {
    data.setFloat32(4 * i, values[k]!, Endian.little);
  }

  return data.buffer.asUint8List();
}

/// Decodes the `12 33` reply: `53 43 ("SC") [n] [count] [total len u16 LE]
/// [crc16]`, then per record `[module] [flags] [sc1Mask] [sc2Mask]`, 4 bytes
/// the pedal fills in (ignored) and one float32 per mask bit. Anything
/// malformed or truncated decodes to no records.
List<SceneRecord> decodeSceneRecordsFrame(String frameHex) {
  final b = collapseFrame(frameHex);

  if (b == null || b.length < 14 || b[4] != 0x12 || b[5] != 0x33) {
    return const [];
  }

  final p = b.sublist(6);

  if (p[0] != 0x53 || p[1] != 0x43) return const [];

  final count = p[3];
  final records = <SceneRecord>[];
  var at = 8;

  for (var i = 0; i < count; i++) {
    if (at + 8 > p.length) return const [];

    final flags = p[at + 1];
    final m1 = p[at + 2];
    final m2 = p[at + 3];
    final n = _bits(m1) + _bits(m2);

    if (at + 8 + 4 * n > p.length) return const [];

    final floats = ByteData.sublistView(
      Uint8List.fromList(p.sublist(at + 8, at + 8 + 4 * n)),
    );
    var f = 0;
    // Non-finite values (a wrong layout guess, garbage) are dropped: they
    // must never reach a knob.
    Map<int, double> take(int mask) {
      final out = <int, double>{};

      for (var k = 0; k < 8; k++) {
        if (mask & (1 << k) == 0) continue;

        final v = floats.getFloat32(4 * f++, Endian.little);

        if (v.isFinite) out[k] = v;
      }

      return out;
    }

    records.add(
      SceneRecord(
        module: p[at],
        sc1On: flags & 0x02 != 0 ? flags & 0x04 != 0 : null,
        sc2On: flags & 0x08 != 0 ? flags & 0x10 != 0 : null,
        sc1: take(m1),
        sc2: take(m2),
      ),
    );
    at += 8 + 4 * n;
  }

  return records;
}

/// Decodes the `12 32` reply (`01 [scene] …`): 0 BASE, 1 SC1, 2 SC2.
int? decodeCurrentSceneFrame(String frameHex) {
  final b = collapseFrame(frameHex);

  if (b == null || b.length < 8 || b[4] != 0x12 || b[5] != 0x32) return null;

  return b[7];
}

int _bits(int mask) {
  var n = 0;

  for (var k = 0; k < 8; k++) {
    if (mask & (1 << k) != 0) n++;
  }

  return n;
}
