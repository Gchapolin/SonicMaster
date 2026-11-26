/// The amp models from clean to high gain, as the real amps they are based on
/// sound with the gain at noon (a judgement, not a measurement: the data has
/// no gain figures), then the bass amps. Each band is ordered from cleanest to
/// most driven.
library;

enum AmpGain { clean, crunch, rockLead, highGain, bass }

const ampGainBands = <AmpGain, List<int>>{
  AmpGain.clean: [
    305, // Jazz 120 (Roland JC-120)
    303, // Dark Twin (Fender Twin Reverb)
    331, // Calif Star CL (Mesa Lone Star clean)
    327, // Bog SV CL (Bogner Shiva clean)
    323, // Doctor CL (Dr. Z clean)
    329, // Superb CL (Supro clean)
  ],
  AmpGain.crunch: [
    304, // Voks 30N (Vox AC30 normal)
    302, // B-Man N (Fender Bassman normal)
    301, // TWD Deluxe (Fender Tweed Deluxe)
    309, // B-Man B (Bassman bright)
    310, // Voks 30TB (AC30 Top Boost)
    306, // Brit 45 (Marshall JTM45)
    336, // Brit 50 (Marshall JTM50)
    307, // Brit 50JP (JTM50 jumped)
    337, // Superb OD (Supro overdrive)
    338, // Doctor OD (Dr. Z overdrive)
  ],
  AmpGain.rockLead: [
    326, // Supero 2 OD (Boss SD-2, a pedal)
    311, // Sol 100 OD (Soldano SLO crunch)
    308, // Brit 800 (Marshall JCM800)
    335, // Tanger R100 (Orange Rockerverb)
    330, // Brit 900 (Marshall JCM900)
    328, // Bog XT M (Bogner Ecstasy blue)
    324, // Flyman B1 (Friedman BE)
    325, // Calif IIC+ (Mesa Mark IIC+)
  ],
  AmpGain.highGain: [
    315, // Sol 100 LD (Soldano SLO lead)
    319, // Flyman B1+ (Friedman HBE)
    334, // Calif IV LD (Mesa Mark IV lead)
    320, // Bog XT V (Bogner Ecstasy red)
    316, // Calif DualV (Mesa Rectifier vintage)
    317, // Calif DualM (Rectifier modern)
    314, // Halen 51 (Peavey 5150)
    313, // Eng 120 (ENGL Savage)
    318, // Eng Power (ENGL Powerball)
    312, // Dizzy VH (Diezel VH4 ch. 3)
    332, // Dizzy VH+ (VH4 ch. 4)
  ],
  AmpGain.bass: [
    321, // A BassVT (Ampeg SVT)
    322, // Voks Bass (Vox AC100)
    333, // Calif Bass (Mesa Bass 400+)
  ],
};

final _rank = {
  for (final (i, id) in [for (final ids in ampGainBands.values) ...ids].indexed)
    id: i,
};

AmpGain? ampGainOf(int fxId) => [
  for (final e in ampGainBands.entries)
    if (e.value.contains(fxId)) e.key,
].firstOrNull;

/// [ids] in band order; ids in no band keep their order, last.
List<int> byAmpGain(List<int> ids) => [
  ...[
    for (final id in ids)
      if (_rank.containsKey(id)) id,
  ]..sort((a, b) => _rank[a]!.compareTo(_rank[b]!)),
  for (final id in ids)
    if (!_rank.containsKey(id)) id,
];

/// For a band-ordered list: the first id of each band, mapped to its band.
Map<int, AmpGain> ampBandStarts(List<int> ordered) {
  final starts = <int, AmpGain>{};
  AmpGain? last;

  for (final id in ordered) {
    final band = ampGainOf(id);

    if (band != null && band != last) starts[id] = band;
    last = band;
  }

  return starts;
}
