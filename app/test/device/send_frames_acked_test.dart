import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/device/transport.dart';

const _ack = 'F00B02000100000003010400080000F7';

Uint8List _bytes(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

/// A pedal that acks a send only when [acks] says so (by send number).
class _FlakyTransport implements Transport {
  _FlakyTransport(this.acks);

  final bool Function(int sendNumber) acks;
  final sent = <String>[];
  final _packets = StreamController<Uint8List>.broadcast();

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
    sent.add(frameHex);
    if (acks(sent.length)) {
      scheduleMicrotask(() => _packets.add(_bytes(_ack)));
    }
  }
}

const _fast = Duration(milliseconds: 40);

void main() {
  test('every frame is sent after the previous one was acked', () async {
    final t = _FlakyTransport((_) => true);
    final service = DeviceService(t)..startListening();

    expect(await service.sendFramesAcked(['a1', 'b2', 'c3']), isTrue);
    expect(t.sent, ['a1', 'b2', 'c3']);
    await service.dispose();
  });

  test('a frame whose ack is lost is sent again', () async {
    final t = _FlakyTransport((n) => n != 2); // the first "b2" gets no ack
    final service = DeviceService(t)..startListening();

    expect(
      await service.sendFramesAcked(['a1', 'b2', 'c3'], ackTimeout: _fast),
      isTrue,
    );
    expect(t.sent, ['a1', 'b2', 'b2', 'c3']);
    await service.dispose();
  });

  test('a frame never acked stops the write', () async {
    final t = _FlakyTransport((n) => n == 1);
    final service = DeviceService(t)..startListening();

    expect(
      await service.sendFramesAcked(
        ['a1', 'b2', 'c3'],
        ackTimeout: _fast,
        ackRetries: 3,
      ),
      isFalse,
    );
    expect(t.sent, ['a1', 'b2', 'b2', 'b2']);
    await service.dispose();
  });

  test('a read asked for meanwhile waits for the whole write', () async {
    final t = _FlakyTransport((_) => true);
    final service = DeviceService(t)..startListening();
    final write = service.sendFramesAcked(['a1', 'b2', 'c3']);
    final read = service.requestDspLoad(timeout: _fast);

    await write;
    await read;

    expect(t.sent.sublist(0, 3), ['a1', 'b2', 'c3']);
    expect(t.sent, hasLength(4)); // the read's frame comes last
    await service.dispose();
  });
}
