import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/protocol/cfw_slot_names_codec.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';

/// A multi-packet reply as the reassembler hands it over: a synthetic
/// `<crc> 01 00 00` header, then the nibble-expanded payload.
String _reassembled(List<int> payload) => [
  '8080f0', '0000', '0001', '0000', '0000', //
  for (final b in payload)
    '0${(b >> 4).toRadixString(16)}0${(b & 0xF).toRadixString(16)}',
  'f7',
].join();

/// A `12 <register>` reply as captured: `01 0a <kind>` + 10 x 32-byte names.
String _reply(int register, List<String> names, {int? cut}) {
  final body = <int>[
    for (final n in names) ...[
      ...n.codeUnits,
      ...List.filled(32 - n.length, 0),
    ],
  ];

  return _reassembled([
    0x12,
    register,
    0x01,
    names.length,
    register == 0x28 ? 0 : 1,
    ...body.take(cut ?? body.length),
  ]);
}

void main() {
  test('the read frames are 12 28 (IRs) and 12 29 (profiles)', () {
    expect(readCfwSlotNamesFrame(0x28), buildSysexWriteFrame([0x12, 0x28]));
    expect(readCfwSlotNamesFrame(0x29), buildSysexWriteFrame([0x12, 0x29]));
  });

  test('decodes the ten zero-padded names', () {
    final names = [
      'Randall SATAN 50 Mic Center',
      for (var i = 2; i <= 10; i++) 'Empty',
    ];

    expect(decodeCfwSlotNames(_reply(0x29, names), 0x29), names);
  });

  test('a 32-character name uses the whole field', () {
    final long = 'A' * 32;
    final names = [long, for (var i = 2; i <= 10; i++) 'User IR $i'];

    expect(decodeCfwSlotNames(_reply(0x28, names), 0x28)!.first, long);
  });

  test('another register, a truncated block or garbage decode to null', () {
    final names = [for (var i = 1; i <= 10; i++) 'User IR $i'];

    expect(decodeCfwSlotNames(_reply(0x28, names), 0x29), isNull);
    expect(decodeCfwSlotNames(_reply(0x28, names, cut: 300), 0x28), isNull);
    expect(decodeCfwSlotNames('zz', 0x28), isNull);
  });

  test('a count above ten is cut to the ten slots', () {
    final names = [for (var i = 1; i <= 12; i++) 'N$i'];

    expect(decodeCfwSlotNames(_reply(0x28, names), 0x28), names.take(10));
  });

  test('effect ids: IRs 416-420 then 422-426, profiles 901-910', () {
    expect(
      [for (var i = 0; i < 10; i++) cfwIrEffectId(i)],
      [
        416, 417, 418, 419, 420, 422, 423, 424, 425, 426, //
      ],
    );
    expect(cfwProfileEffectId(0), 901);
    expect(cfwProfileEffectId(9), 910);
  });
}
