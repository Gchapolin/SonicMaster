import 'dart:typed_data';

/// A Pocket Master preset record (494 bytes) in the layout the CFW app checks:
/// `FF FF FF FF`, a 16-byte name, then groups `<id u16> <len u16>` of tags
/// `<tag u16> <len u16> <data>` (group 3 is 8 raw bytes: the STOMP groups).
Uint8List testPresetRecord(
  String name, {
  List<int> effectIds = const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  int fs1 = 0,
  int fs2 = 0,
  double firstParam = 0,
}) {
  final out = BytesBuilder();
  void u16(int v) => out.add([v & 0xFF, v >> 8]);
  void u32(int v) =>
      out.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
  void tag(int t, List<int> data) {
    u16(t);
    u16(data.length);
    out.add(data);
  }

  List<int> le32(int v) => [
    v & 0xFF,
    (v >> 8) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 24) & 0xFF,
  ];

  out.add([0xFF, 0xFF, 0xFF, 0xFF]);
  out.add([...name.codeUnits.take(16), ...List.filled(16 - name.length, 0)]);
  // Group 1: header tags.
  final g1 = BytesBuilder();
  void g1tag(int t, List<int> d) => g1
    ..add([t & 0xFF, t >> 8, d.length & 0xFF, d.length >> 8])
    ..add(d);
  g1tag(0x0001, le32(1));
  g1tag(0x0002, le32(0x514D450A));
  g1tag(0x1001, le32(10));
  g1tag(0x1002, le32(8));
  g1tag(0x2001, le32(75));
  g1tag(0x2002, le32(120));
  u16(1);
  u16(g1.length);
  out.add(g1.takeBytes());
  // Group 3: STOMP groups.
  u16(3);
  u16(8);
  u32(fs1);
  u32(fs2);
  // Group 2: modules.
  final params = ByteData(320)..setFloat32(0, firstParam, Endian.little);
  final g2 = [
    ..._tagBytes(0x3001, le32(0x3FF)),
    ..._tagBytes(0x3002, List.generate(10, (i) => i)),
    ..._tagBytes(0x3003, [for (final id in effectIds) ...le32(id)]),
    ..._tagBytes(0x3004, params.buffer.asUint8List()),
  ];
  u16(2);
  u16(g2.length);
  out.add(g2);

  final bytes = out.takeBytes();
  // Pad with a filler group up to the stock size.
  final pad = 494 - bytes.length - 4;
  final b = BytesBuilder()
    ..add(bytes)
    ..add([5, 0, pad & 0xFF, pad >> 8]);
  if (pad > 0) {
    b.add([0x7F, 0x00, (pad - 4) & 0xFF, (pad - 4) >> 8]);
    b.add(List.filled(pad - 4, 0));
  }

  return b.takeBytes();
}

List<int> _tagBytes(int t, List<int> d) => [
  t & 0xFF,
  t >> 8,
  d.length & 0xFF,
  d.length >> 8,
  ...d,
];
