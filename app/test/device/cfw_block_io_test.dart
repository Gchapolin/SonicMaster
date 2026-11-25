import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/device/transport.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/sysex_chunk_upload.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';

Uint8List _bytes(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

/// The raw packet (no 8080 header) of a single-packet reply carrying [payload].
Uint8List _packet(List<int> payload) =>
    _bytes(buildSysexWriteFrame(payload).substring(4));

/// Answers each sent frame with [reply] (raw packets), by send number.
class _Pedal implements Transport {
  _Pedal(this.reply);

  final List<Uint8List> Function(int n, String frame) reply;
  final sent = <String>[];
  final _packets = StreamController<Uint8List>.broadcast();

  void push(Uint8List p) => _packets.add(p);

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
    sent.add(frameHex.toLowerCase());
    final out = reply(sent.length, frameHex);

    scheduleMicrotask(() => out.forEach(_packets.add));
  }
}

const _fast = Duration(milliseconds: 40);

void main() {
  test('a read returns the reply that starts with the prefix', () async {
    final t = _Pedal(
      (_, _) => [
        _packet([0x12, 0x2B, 1]), // another register first: ignored
        _packet([0x12, 0x34, 5, 0x53, 0x43]),
      ],
    );
    final service = DeviceService(t)..startListening();
    final hex = await service.requestCfwBlock([0x12, 0x34, 5], [0x12, 0x34, 5]);

    expect(t.sent, [
      buildSysexWriteFrame([0x12, 0x34, 5]),
    ]);
    expect(collapseFrame(hex!)!.sublist(4), [0x12, 0x34, 5, 0x53, 0x43]);
    await service.dispose();
  });

  test('a read with no reply is null', () async {
    final service = DeviceService(_Pedal((_, _) => []))..startListening();

    expect(
      await service.requestCfwBlock([0x12, 0x4F], [0x12, 0x4F], timeout: _fast),
      isNull,
    );
    await service.dispose();
  });

  test('a write goes in 19-byte packets, each after its ack', () async {
    final t = _Pedal(
      (_, _) => [
        _packet([0x14, 0x08, 0x00]),
      ],
    );
    final service = DeviceService(t)..startListening();
    final payload = List.generate(40, (i) => i);

    expect(await service.writeCfwBlock(payload, ackTimeout: _fast), 0);
    expect(
      t.sent,
      SysexChunkUpload.buildChunks(
        Uint8List.fromList(payload),
      ).map((f) => f.toLowerCase()),
    );
    await service.dispose();
  });

  test('a refused packet stops the write with its status', () async {
    final t = _Pedal(
      (n, _) => [
        _packet([0x14, 0x08, n == 2 ? 5 : 0]),
      ],
    );
    final service = DeviceService(t)..startListening();

    expect(
      await service.writeCfwBlock(List.filled(60, 1), ackTimeout: _fast),
      5,
    );
    expect(t.sent, hasLength(2));
    await service.dispose();
  });

  test('no ack after the retries is null', () async {
    final t = _Pedal((_, _) => []);
    final service = DeviceService(t)..startListening();

    expect(
      await service.writeCfwBlock([0x11, 0x2A, 1, 2], ackTimeout: _fast),
      isNull,
    );
    expect(t.sent, hasLength(4));
    await service.dispose();
  });

  test('a preset write waits for the 12 1B 02 notification', () async {
    late _Pedal t;
    t = _Pedal((_, _) {
      // The commit arrives a moment after the ack.
      Timer(
        const Duration(milliseconds: 20),
        () => t.push(_packet([0x12, 0x1B, 0x02, 0, 0, 0])),
      );

      return [
        _packet([0x14, 0x08, 0x00]),
      ];
    });

    final service = DeviceService(t)..startListening();
    final watch = Stopwatch()..start();

    expect(
      await service.writeCfwBlock(
        [0x11, 0x4F, 0],
        ackTimeout: _fast,
        commitDomain: 2,
      ),
      0,
    );
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    await service.dispose();
  });
}
