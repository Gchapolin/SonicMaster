import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/amp_gain.dart';

import '../support/test_assets.dart';

void main() {
  final data = loadTestDataAssets();
  final amps = [
    for (final id in data.effects.effects.keys)
      if (id > 300 && id < 400) id,
  ];

  test('every amp model is in exactly one band', () {
    final banded = [for (final ids in ampGainBands.values) ...ids];

    expect(banded.toSet(), amps.toSet());
    expect(banded.length, banded.toSet().length);
  });

  test('clean to high gain, then bass', () {
    expect(AmpGain.values, [
      AmpGain.clean,
      AmpGain.crunch,
      AmpGain.rockLead,
      AmpGain.highGain,
      AmpGain.bass,
    ]);
    expect(ampGainOf(305), AmpGain.clean); // Jazz 120
    expect(ampGainOf(308), AmpGain.rockLead); // Brit 800
    expect(ampGainOf(332), AmpGain.highGain); // Dizzy VH+
    expect(ampGainOf(321), AmpGain.bass); // A BassVT
  });

  test('a list of offered amps comes back in band order', () {
    // Shuffled stock ids plus one unknown id, which goes last.
    final sorted = byAmpGain([332, 321, 308, 999, 305, 301]);

    expect(sorted, [305, 301, 308, 332, 321, 999]);
  });

  test('the first id of each band present starts a section', () {
    expect(ampBandStarts([305, 301, 308, 332, 321]), {
      305: AmpGain.clean,
      301: AmpGain.crunch,
      308: AmpGain.rockLead,
      332: AmpGain.highGain,
      321: AmpGain.bass,
    });
  });
}
