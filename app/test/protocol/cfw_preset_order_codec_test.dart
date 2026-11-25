import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/protocol/cfw_preset_order_codec.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';

final _identity = [for (var i = 0; i < 50; i++) i];

void main() {
  test('the read frame is 12 37', () {
    expect(readPresetOrderFrame(), buildSysexWriteFrame([0x12, 0x37]));
  });

  test('decodes the captured identity table', () {
    final order = decodePresetOrderFrame(
      buildSysexWriteFrame([0x12, 0x37, 0x01, 0x02, 0x83, ..._identity]),
    )!;

    expect(order.token, 0x83);
    expect(order.entries, _identity);
    expect(order.isIdentity, isTrue);
  });

  test('a truncated table, a repeated slot or another reply is null', () {
    expect(
      decodePresetOrderFrame(
        buildSysexWriteFrame([0x12, 0x37, 1, 2, 0x83, ..._identity.take(49)]),
      ),
      isNull,
    );
    expect(
      decodePresetOrderFrame(
        buildSysexWriteFrame([
          0x12,
          0x37,
          1,
          0,
          0x10,
          0,
          ..._identity.take(49),
        ]),
      ),
      isNull,
    );
    expect(
      decodePresetOrderFrame(
        buildSysexWriteFrame([0x12, 0x33, 1, 2, 0x83, ..._identity]),
      ),
      isNull,
    );
  });

  test('moving P18 to P17 writes the three captured packets', () {
    final moved = movePreset(_identity, from: 17, to: 16);

    expect(moved.sublist(15, 19), [15, 17, 16, 18]);
    expect(buildPresetOrderFrames(token: 0x83, entries: moved), [
      '8080f00e0100030000010301010307000108030000000100020003000400050006000700080009000a000b000c000d000ef7',
      '8080f00809000300010103000f0101010001020103010401050106010701080109010a010b010c010d010e010f02000201f7',
      '8080f0020400030002010002020203020402050206020702080209020a020b020c020d020e020f03000301f7',
    ]);
  });

  test('a move shifts the presets in between', () {
    expect(movePreset([0, 1, 2, 3, 4], from: 0, to: 3), [1, 2, 3, 0, 4]);
    expect(movePreset([0, 1, 2, 3, 4], from: 4, to: 1), [0, 4, 1, 2, 3]);
    expect(movePreset([0, 1, 2], from: 1, to: 1), [0, 1, 2]);
  });
}
