import 'dart:typed_data';

import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/model/cfw_info.dart';
import 'package:sonicmaster/protocol/cfw_backup.dart';

import 'backup_fixtures.dart';
import 'silent_transport.dart';

/// A frame as the pipeline hands over a reassembled reply: header
/// `<crc> 01 00 00`, then [payload], every byte nibble-expanded.
String replyFrame(List<int> payload) {
  final sb = StringBuffer('8080F0');

  for (final b in [0, 1, 0, 0, ...payload]) {
    sb.write('0${(b >> 4).toRadixString(16)}0${(b & 15).toRadixString(16)}');
  }

  return '${sb}F7'.toUpperCase();
}

/// The captured CFW 1.0.2 capability words (cfw_dumps.dart): bit 11 of the
/// second one is the one-write preset path (`11 34`).
const cfwCaps = 0xCFFF8F7F;
const cfwCaps2 = 0x9CF;

CfwInfo testCfwInfo({int caps2 = cfwCaps2}) => CfwInfo(
  version: 'CFW1.0.2',
  capabilities: cfwCaps,
  extraCapabilities: caps2,
  settings: const {1: 3, 2: 100, 3: 1, 4: 0, 6: 0, 16: 2, 21: 0, 23: 0},
);

/// An empty "SC" block, as the pedal answers for a preset with no scenes.
final emptyScenes = Uint8List.fromList([0x53, 0x43, 1, 0, 8, 0, 0xFF, 0xFF]);

/// A CFW Pocket Master in memory: answers the backup reads, applies the
/// restore writes and logs both. Every read of a slot in [deadSlots] times out.
class FakeCfwPedal extends DeviceService {
  FakeCfwPedal() : super(SilentTransport()) {
    for (var i = 0; i < 50; i++) {
      records[i] = testPresetRecord('Preset ${i + 1}');
      scenes[i] = emptyScenes;
      exp[i] = Uint8List.fromList([
        for (var s = 0; s < 4; s++) ...[255, 0, 0, 0, 0, 0],
      ]);
    }
  }

  final records = <int, Uint8List>{};
  final scenes = <int, Uint8List>{};
  final exp = <int, Uint8List>{};
  var settings = <int, int>{
    1: 3,
    2: 100,
    3: 1,
    4: 0,
    6: 0,
    16: 2,
    21: 0,
    23: 0,
  };
  var geq = [0, 0, 0, 0, 0, 0, 0, 50, 0, 100];
  var midiMap = Uint8List(0);
  var midiOptions = 0;

  /// 1-based Clone slot -> its .clo; the other slots are empty.
  final clones = <int, Uint8List>{};
  String? globalsHex;

  /// The map rows the pedal holds after a MIDI map write (the fake does not
  /// decode the frames).
  Uint8List? midiMapAfterWrite;
  final deadSlots = <int>{};

  /// What the restore writes, as `11 …` payloads (single frames for the MIDI
  /// map and the globals, as hex).
  final writes = <List<int>>[];
  final frames = <String>[];

  /// Every read, as the request payload's hex.
  final reads = <String>[];

  /// Status the pedal answers [writeCfwBlock] with, by register.
  final statusFor = <int, int>{};

  static String _h(List<int> b) =>
      b.map((v) => v.toRadixString(16).padLeft(2, '0')).join(' ');

  @override
  Future<String?> requestCfwBlock(
    List<int> request,
    List<int> replyPrefix, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    reads.add(_h(request));

    final reg = request[1];
    final List<int>? payload = switch (reg) {
      0x4F when !deadSlots.contains(request[2]) => [
        0x12,
        0x4F,
        ...records[request[2]]!,
      ],
      0x34 => [0x12, 0x34, request[2], ...scenes[request[2]]!],
      0x3D => [0x12, 0x3D, 1, 0x81, ...exp[request[2]]!],
      0x39 when request[2] == 0 => [
        0x12, 0x39, 0, 1, 1, 0, midiMap.length ~/ 8, 40, midiOptions, //
        0, 0, 0, 0, 0, 0,
      ],
      0x39 => [
        0x12,
        0x39,
        1,
        request[3],
        (midiMap.length ~/ 8 - request[3]).clamp(0, 8),
        ...midiMap.skip(request[3] * 8).take(64),
      ],
      0x2A => [
        0x12, 0x2A, 1, ...'CFW1.0.2'.codeUnits, ...List.filled(8, 0), //
        0x7F, 0x8F, 0xFF, 0xCF, 0, settings.length,
        for (final e in settings.entries) ...[e.key, e.value],
        4, 0xCF, 0x09, 0, 0,
      ],
      0x3A => [0x12, 0x3A, ...geq],
      0x37 => [0x12, 0x37, 1, 2, 0x83, ...List.generate(50, (i) => i)],
      0x28 || 0x29 => [
        0x12,
        reg,
        1,
        10,
        for (var s = 1; s <= 10; s++) ...[
          reg == 0x29 && clones.containsKey(s) ? 1 : 0,
          ...List.filled(31, 0),
        ],
      ],
      0x38 => _slotChunk(request[2], request[3] + 1, request[4]),
      _ => null,
    };

    return payload == null ? null : replyFrame(payload);
  }

  List<int> _slotChunk(int kind, int slot, int chunk) {
    final data = kind == 0 ? clones[slot] : null;
    final head = [0x12, 0x38, kind, slot - 1, chunk];

    if (data == null) return [...head, 1, 0, 0];

    final part = data.skip(chunk * 460).take(460).toList();

    return [...head, 0, part.length & 0xFF, part.length >> 8, ...part];
  }

  @override
  Future<String?> requestGlobalSettings({
    Duration timeout = const Duration(seconds: 1),
  }) async {
    reads.add('globals');

    return globalsHex;
  }

  @override
  Future<int?> writeCfwBlock(
    List<int> payload, {
    int? commitDomain,
    Duration ackTimeout = const Duration(milliseconds: 1200),
    int ackRetries = 4,
    Duration commitTimeout = const Duration(seconds: 3),
  }) async {
    writes.add(payload);

    final status = statusFor[payload[1]];

    if (status != null) return status;

    switch (payload[1]) {
      case 0x2A:
        settings = {...settings, payload[2]: payload[3]};
      case 0x3A:
        geq = payload.sublist(2, 12);
      case 0x4F:
        records[payload[2]] = Uint8List.fromList([
          0xFF, 0xFF, 0xFF, 0xFF, ...payload.sublist(6), //
        ]);
      case 0x34:
        final slot = payload[2];
        final recordEnd = 6 + presetRecordLength - 4;

        records[slot] = Uint8List.fromList([
          0xFF, 0xFF, 0xFF, 0xFF, ...payload.sublist(6, recordEnd), //
        ]);
        exp[slot] = Uint8List.fromList(
          payload.sublist(recordEnd, recordEnd + 24),
        );
        scenes[slot] = Uint8List.fromList(payload.sublist(recordEnd + 24));
    }

    return 0;
  }

  @override
  Future<bool> sendFramesAcked(
    List<String> frames, {
    Duration ackTimeout = const Duration(milliseconds: 1200),
    int ackRetries = 4,
  }) async {
    this.frames.addAll(frames.map((f) => f.toLowerCase()));
    if (midiMapAfterWrite case final m?) midiMap = m;

    return true;
  }

  @override
  Future<bool> sendAndAwaitAck(
    String frameHex, {
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    frames.add(frameHex.toLowerCase());

    return true;
  }
}
