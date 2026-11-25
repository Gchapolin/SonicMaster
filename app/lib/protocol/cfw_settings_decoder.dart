import '../model/cfw_info.dart';

/// The collapsed bytes of a `8080 F0 … F7` frame: every on-wire byte carries
/// one nibble (`0x0N`), and pairs make one real byte. Returns null when [hex]
/// is not a well-formed nibble-expanded frame.
List<int>? collapseFrame(String hex) {
  final h = hex.toUpperCase();

  if (!h.startsWith('8080F0') || !h.endsWith('F7')) return null;

  final inner = h.substring(6, h.length - 2);

  if (inner.length % 4 != 0) return null;

  final out = <int>[];

  for (var i = 0; i < inner.length; i += 4) {
    final hi = int.tryParse(inner.substring(i, i + 2), radix: 16);
    final lo = int.tryParse(inner.substring(i + 2, i + 4), radix: 16);

    if (hi == null || lo == null || hi > 0x0F || lo > 0x0F) return null;
    out.add((hi << 4) | lo);
  }

  return out;
}

/// Decodes the pedal's `12 2A` reply (CFW settings block). Layout after the
/// `<crc> 01 00 <len>` header: `12 2A 01`, a 16-byte ASCII version padded with
/// zeros, 4 capability bytes (u32 LE), one more byte, a pair count, then
/// `count` × `<key> <value>`. Returns null for anything else: another reply,
/// a truncated block, or a version that is not a CFW one (stock firmware).
CfwInfo? decodeCfwSettingsFrame(String frameHex) {
  final bytes = collapseFrame(frameHex);

  if (bytes == null || bytes.length < 4) return null;

  final p = bytes.sublist(4);
  const versionAt = 3;
  const capsAt = 19;
  const countAt = 24;
  const pairsAt = 25;

  if (p.length < pairsAt || p[0] != 0x12 || p[1] != 0x2A) return null;

  final versionBytes = p
      .sublist(versionAt, capsAt)
      .takeWhile((b) => b != 0)
      .toList();
  final version = String.fromCharCodes(versionBytes);

  if (!version.startsWith('CFW')) return null;

  final count = p[countAt];

  if (pairsAt + 2 * count > p.length) return null;

  return CfwInfo(
    version: version,
    capabilities:
        p[capsAt] |
        (p[capsAt + 1] << 8) |
        (p[capsAt + 2] << 16) |
        (p[capsAt + 3] << 24),
    settings: {
      for (var i = 0; i < count; i++)
        p[pairsAt + 2 * i]: p[pairsAt + 2 * i + 1],
    },
  );
}
