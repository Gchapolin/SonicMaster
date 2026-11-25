import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/cfw_global_eq.dart';
import 'package:sonicmaster/protocol/cfw_geq_codec.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';

/// Payloads captured from the CFW web app (docs/cfw-protocol/capture-notes.md).
List<int> payload(String frame) => collapseFrame(frame)!.sublist(4);

void main() {
  test('Studio EQ on, Bass +2 dB', () {
    const eq = CfwGlobalEq(
      isOn: true,
      model: 0,
      slots: [4, 0, 0, 0, 0, 50, 0, 100],
    );

    expect(payload(buildGlobalEqFrame(eq)), [
      0x11, 0x3a, 0x01, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x32, 0x00, 0x64, //
    ]);
  });

  test('Studio EQ with every knob moved', () {
    const eq = CfwGlobalEq(
      isOn: true,
      model: 0,
      slots: [4, 7, 3, 7, 3, 50, 7, 93],
    );

    expect(payload(buildGlobalEqFrame(eq)), [
      0x11, 0x3a, 0x01, 0x00, 0x04, 0x07, 0x03, 0x07, 0x03, 0x32, 0x07, 0x5d, //
    ]);
  });

  test('Parametric 3 defaults and the off block', () {
    expect(
      payload(
        buildGlobalEqFrame(
          const CfwGlobalEq(
            isOn: true,
            model: 1,
            slots: [0, 0, 0, 0, 0, 50, 33, 40],
          ),
        ),
      ),
      [0x11, 0x3a, 0x01, 0x01, 0, 0, 0, 0, 0, 0x32, 0x21, 0x28],
    );
    expect(
      payload(
        buildGlobalEqFrame(
          const CfwGlobalEq(
            isOn: false,
            model: 0,
            slots: [0, 0, 0, 0, 0, 50, 0, 100],
          ),
        ),
      ),
      [0x11, 0x3a, 0x00, 0x00, 0, 0, 0, 0, 0, 0x32, 0x00, 0x64],
    );
  });

  test('negative values are signed bytes and round-trip', () {
    const eq = CfwGlobalEq(
      isOn: true,
      model: 0,
      slots: [-24, -50, 0, 0, 0, 50, 0, 100],
    );
    final p = payload(buildGlobalEqFrame(eq));

    expect(p[4], 0xe8);
    expect(p[5], 0xce);

    final back = decodeGlobalEqFrame(
      buildSysexWriteFrame([0x12, 0x3a, ...p.sublist(2)]),
    )!;

    expect(back.slots, eq.slots);
    expect(back.isOn, isTrue);
    expect(back.model, 0);
  });

  test('short or foreign replies do not decode', () {
    expect(
      decodeGlobalEqFrame(buildSysexWriteFrame([0x12, 0x3a, 0x01])),
      isNull,
    );
    expect(
      decodeGlobalEqFrame(
        buildSysexWriteFrame([0x12, 0x2a, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
      ),
      isNull,
    );
    expect(decodeGlobalEqFrame('junk'), isNull);
  });

  test('the read frame is 12 3A', () {
    expect(payload(readGlobalEqFrame()), [0x12, 0x3a]);
  });
}
