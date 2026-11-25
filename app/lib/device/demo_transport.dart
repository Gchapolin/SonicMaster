import 'dart:async';
import 'dart:typed_data';

import '../protocol/cfw_settings_decoder.dart';
import '../protocol/sysex_write_frame.dart';
import 'demo_data.dart';
import 'transport.dart';

/// A virtual pedal for the demo mode: nothing is sent to a device. It answers
/// the app's reads with real captured dumps (demo_data.dart), acks every
/// write, and behaves as a Pocket Master on the community custom firmware:
/// its CFW settings, Global EQ and scenes are kept in memory and read back.
///
/// Limits: the five captured presets repeat across the slots, and stock edits
/// (knobs, effect type, chain order, save) are acked but not stored — a
/// re-read shows the captured preset again.
class DemoTransport implements Transport {
  final _packets = StreamController<Uint8List>.broadcast();

  static const _ack = '8080F00B02000100000003010400080000F7';

  var _preset = 0;
  var _scene = 0;
  var _globalEq = <int>[0, 0, 0, 0, 0, 0, 0, 50, 0, 100];
  final _scenes = <int, List<int>>{}; // module -> record bytes after module

  /// CFW settings, key -> value (as a real CFW 1.0.2 reports them).
  final _settings = <int, int>{
    0x01: 3, 0x02: 100, 0x03: 1, 0x04: 0, 0x06: 0, 0x10: 0, //
    0x11: 0, 0x12: 0, 0x15: 0, 0x16: 0, 0x17: 0, 0x27: 0,
  };

  @override
  Stream<Uint8List> rawPackets() => _packets.stream;

  @override
  Future<void> connect({String? target}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<bool>? connectionEvents() => null;

  @override
  Future<void> sendFrame(String frameHex) async {
    final b = collapseFrame(frameHex);
    final p = b == null || b.length < 6 ? const <int>[] : b.sublist(4);

    if (p.isEmpty) {
      // Not a plain register frame (e.g. an upload chunk): just ack it.
      _emit(_ack);
    } else if (p[0] == 0x12) {
      final reply = _read(p[1]);

      if (reply != null) _emit(reply);
    } else {
      _write(p);
      _emit(_ack);
    }
  }

  String? _read(int register) => switch (register) {
    0x41 => demoStateDumps[_preset % demoStateDumps.length],
    0x10 => demoGlobalSettings,
    0x40 => demoPresetNames,
    0x24 => demoCloneNames,
    0x20 => demoIrNames,
    0x30 => buildSysexWriteFrame([0x11, 0x30, 0x00]),
    0x2A => buildSysexWriteFrame([
      0x12, 0x2A, 0x01, //
      ...'CFW1.0.2'.codeUnits, 0, 0, 0, 0, 0, 0, 0, 0, //
      0x7F, 0x8F, 0xFF, 0xCF, 0x1E, //
      _settings.length,
      for (final e in _settings.entries) ...[e.key, e.value],
    ]),
    0x2B => buildSysexWriteFrame([0x12, 0x2B, 0x01, 0x03, 42, 0, 0x10, 0x0E]),
    0x2C => buildSysexWriteFrame([0x12, 0x2C, 0x01, 0x00, 120, 0]),
    // On battery, 3 of 4 bars (3.85 V), like the CFW app's demo pedal.
    0x2D => buildSysexWriteFrame([
      0x12, 0x2D, 0x01, 0x01, 0x0A, 0x0F, 0, 2, 5, 3, 0xD4, 0x0D, //
    ]),
    0x3A => buildSysexWriteFrame([0x12, 0x3A, ..._globalEq]),
    0x32 => buildSysexWriteFrame([0x12, 0x32, 0x01, _scene, 0, 0, 0, 0]),
    0x33 => _sceneReply(),
    _ => null,
  };

  String _sceneReply() {
    final records = [
      for (final e in _scenes.entries)
        // module, flags, masks | 4 bytes the pedal fills in | floats
        [e.key, ...e.value.take(3), 0, 0, 0, 0, ...e.value.skip(3)],
    ];
    final length = 8 + records.fold<int>(0, (n, r) => n + r.length);

    return buildSysexWriteFrame([
      0x12, 0x33, 0x53, 0x43, 0x01, records.length, //
      length & 0xFF, length >> 8, 0xFF, 0xFF,
      for (final r in records) ...r,
    ]);
  }

  void _write(List<int> p) {
    if (p[0] != 0x11 || p.length < 3) return;

    switch (p[1]) {
      case 0x43: // preset select: any distinct slot picks one of the dumps
        _preset = p.skip(2).fold(0, (n, v) => n * 7 + v);
        _scene = 0;
        _scenes.clear();
      case 0x2A when p.length >= 4:
        _settings[p[2]] = p[3];
      case 0x11 when p.length >= 7 && p[2] == 0x03 && p[3] == 0x02:
        _settings[0x02] = p[6]; // brightness, a settings-dump record
      case 0x3A when p.length >= 12:
        _globalEq = p.sublist(2, 12);
      case 0x32:
        _scene = p[2];
        _settings[0x10] = p[2];
      case 0x33 when p.length >= 6:
        if (p[3] == 0) {
          _scenes.remove(p[2]);
        } else {
          _scenes[p[2]] = p.sublist(3);
        }
    }
  }

  void _emit(String frameHex) {
    final hex = frameHex.toUpperCase().replaceFirst(RegExp('^8080'), '');
    final bytes = Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);

    scheduleMicrotask(() {
      if (!_packets.isClosed) _packets.add(bytes);
    });
  }
}
