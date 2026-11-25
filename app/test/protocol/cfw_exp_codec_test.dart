import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/cfw_exp.dart';
import 'package:sonicmaster/protocol/cfw_exp_codec.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';

const _free = [0xff, 0, 0, 0, 0, 0];

void main() {
  // Captured: EXP A -> NR THRE, continuous, 0..35 %; B-D free.
  const nrThre = ExpAssign(module: 0, algId: 0, mode: 0, min: 0, max: 35);

  test('writes the four slots as captured', () {
    expect(
      buildExpFrame(const [nrThre, null, null, null]),
      buildSysexWriteFrame([
        0x11, 0x3d, 0x00, 0x00, 0x00, 0x00, 0x23, 0x00, //
        ..._free, ..._free, ..._free,
      ]),
    );
  });

  test('a slot keeps its module, knob, mode and range', () {
    const dly = ExpAssign(module: 7, algId: 2, mode: 2, min: 10, max: 90);

    expect(
      buildExpFrame(const [null, null, null, dly]),
      buildSysexWriteFrame([
        0x11, 0x3d, ..._free, ..._free, ..._free, //
        0x07, 0x02, 0x02, 0x0a, 0x5a, 0x00,
      ]),
    );
  });

  test('the read frame is 12 3D', () {
    expect(readExpFrame(), buildSysexWriteFrame([0x12, 0x3d]));
  });

  test('decodes the reply into four slots', () {
    final reply = buildSysexWriteFrame([
      0x12, 0x3d, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x23, 0x00, //
      ..._free, ..._free, 0x03, 0x01, 0x01, 0x00, 0x64, 0x00,
    ]);

    expect(decodeExpFrame(reply), const [
      nrThre,
      null,
      null,
      ExpAssign(module: 3, algId: 1, mode: 1, min: 0, max: 100),
    ]);
  });

  test('a truncated or foreign reply decodes to null', () {
    expect(
      decodeExpFrame(buildSysexWriteFrame([0x12, 0x3d, 1, 1, 0, 0, 0])),
      isNull,
    );
    expect(
      decodeExpFrame(
        buildSysexWriteFrame([0x12, 0x33, 1, 1, ...List.filled(24, 0)]),
      ),
      isNull,
    );
    expect(decodeExpFrame('nope'), isNull);
  });

  test('out-of-range bytes from the pedal are clamped, not trusted', () {
    final reply = buildSysexWriteFrame([
      0x12, 0x3d, 0x01, 0x01, 0x00, 0x00, 0x09, 0x00, 0xc8, 0x00, //
      ..._free, ..._free, ..._free,
    ]);

    expect(decodeExpFrame(reply)!.first, nrThre.copyWith(mode: 0, max: 100));
  });
}
