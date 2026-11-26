import '../model/amp_gain.dart';
import 'lang.dart';

/// The amp list's band titles. Clean / Crunch / Rock / Lead / High gain are the
/// words Brazilian players use too; only the bass band changes.
abstract class AmpText {
  const AmpText();

  static AmpText get current => appLang == Lang.pt ? const _Pt() : const _En();

  String band(AmpGain band) => switch (band) {
    AmpGain.clean => 'Clean',
    AmpGain.crunch => 'Crunch',
    AmpGain.rockLead => 'Rock / Lead',
    AmpGain.highGain => 'High gain',
    AmpGain.bass => bass,
  };

  String get bass;
}

class _En extends AmpText {
  const _En();

  @override
  String get bass => 'Bass';
}

class _Pt extends AmpText {
  const _Pt();

  @override
  String get bass => 'Baixo';
}
