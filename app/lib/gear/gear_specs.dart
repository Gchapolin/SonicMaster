import 'package:flutter/painting.dart';

// Tables transcribed from docs/design/prototipo/Peca.dc.html (P, KN, A, AK, C
// plus the tolex, grille and panel colour tables). Gradients and weaves of the
// prototype are reduced to their base colour; drawing adds the texture.

/// What a model is drawn as.
enum GearKind { pedal, amp, cab }

enum PedalFamily {
  std,
  compact,
  ts,
  mxr,
  wide,
  round,
  wedge,
  rat,
  graphic,
  studio,
  rack,
  tape,
  wah,
  modern,
}

enum KnobStyle {
  boss,
  black,
  mxr,
  chickenBlack,
  chickenCream,
  chickenBrown,
  skirt,
  goldcap,
  chrome,
  blackFlat,
  silvercap,
  cream,
  alu,
  white,
}

sealed class GearSpec {
  const GearSpec();
}

class PedalSpec extends GearSpec {
  const PedalSpec(
    this.family,
    this.body,
    this.label,
    this.knob,
    this.knobNames,
  );
  final PedalFamily family;
  final Color body;
  final Color label;
  final KnobStyle knob;
  final List<String> knobNames;
}

/// The prototype's TOLEX table: [color] is the base, the weave is drawn per kind.
enum Tolex {
  black(Color(0xFF1C1C1C)),
  tweed(Color(0xFFD2B47A)),
  blonde(Color(0xFFE9DCC0)),
  orange(Color(0xFFE8761E)),
  blue(Color(0xFF2F5D8A)),
  grey(Color(0xFF3A3D42));

  const Tolex(this.color);
  final Color color;
}

/// The prototype's GRILLE table: [color] is the base, the weave is drawn per
/// kind. [lightAmp] is the amp badge's `lightGrille` list, [goldBadgeCab] the
/// cab badge's (they differ in the prototype).
enum Grille {
  silver(Color(0xFFA9ABAE)),
  oxblood(Color(0xFF5A261D)),
  diamond(Color(0xFF2A1D13)),
  saltpepper(Color(0xFF5C5C5C)),
  black(Color(0xFF222222)),
  jc(Color(0xFFB9BBBE)),
  tan(Color(0xFFB59B74)),
  cream(Color(0xFFE3D9C2)),
  basket(Color(0xFFC1AC82)),
  plate(Color(0xFFA2A6AC)),
  metal(Color(0xFF2E2F31)),
  check(Color(0xFF1E2638));

  const Grille(this.color);
  final Color color;

  bool get lightAmp =>
      const {silver, saltpepper, basket, tan, cream, jc, plate}.contains(this);

  bool get goldBadgeCab =>
      const {silver, saltpepper, basket, tan, cream, jc, check}.contains(this);
}

class AmpSpec extends GearSpec {
  const AmpSpec(
    this.isHead,
    this.tolex,
    this.grille,
    this.panel,
    this.knob,
    this.piping,
    this.knobNames,
  );
  final bool isHead;
  final Tolex tolex;
  final Grille grille;
  final AmpPanel panel;
  final KnobStyle knob;
  final bool piping;
  final List<String> knobNames;
}

/// The prototype's PANEL table: a vertical gradient [top] to [bottom], the
/// [ink] of the knob labels, a lower [band] (the two-tone bass panel, from 70%
/// down) and whether it shows [worn] wear (gold and copper only).
class AmpPanel {
  const AmpPanel(
    this.top,
    this.bottom,
    this.ink, {
    this.band,
    this.worn = false,
  });
  final Color top;
  final Color bottom;
  final Color ink;
  final Color? band;
  final bool worn;

  static const _dark = Color(0xFF1A1A1A);
  static const gold = AmpPanel(
    Color(0xFFDCC27F),
    Color(0xFFC2A35C),
    _dark,
    worn: true,
  );
  static const brass = AmpPanel(
    Color(0xFF2A2621),
    Color(0xFF1C1915),
    Color(0xFFD7B76A),
  );
  static const chrome = AmpPanel(Color(0xFFE4E6E8), Color(0xFFA9ACB0), _dark);
  static const silver = AmpPanel(Color(0xFFCFD2D5), Color(0xFF9DA1A6), _dark);
  static const alu = AmpPanel(Color(0xFFD8DADD), Color(0xFFB3B7BC), _dark);
  static const copper = AmpPanel(
    Color(0xFFC98B5A),
    Color(0xFF9C6338),
    _dark,
    worn: true,
  );
  static const blackface = AmpPanel(
    Color(0xFF1A1A1A),
    Color(0xFF0F0F0F),
    Color(0xFFEDEDED),
  );
  static const black = AmpPanel(
    Color(0xFF202124),
    Color(0xFF141517),
    Color(0xFFD8D8D8),
  );
  static const white = AmpPanel(Color(0xFFF2F0EA), Color(0xFFDDD9CF), _dark);
  static const svt = AmpPanel(
    Color(0xFFC9CDD2),
    Color(0xFFC9CDD2),
    Color(0xFFF2F2F2), // the labels sit on the blue band
    band: Color(0xFF2C4F8C),
  );
}

class CabSpec extends GearSpec {
  const CabSpec(
    this.speakers,
    this.inch,
    this.tolex,
    this.grille,
    this.slant,
    this.piping,
    this.corners,
  );
  final int speakers;
  final int inch;
  final Tolex tolex;
  final Grille grille;
  final bool slant;
  final bool piping;
  final bool corners;
}

/// Fallback for models with no table entry.
class GenericSpec extends GearSpec {
  const GenericSpec(this.kind);
  final GearKind kind;
}

const Map<String, PedalSpec> pedalSpecs = {
  'Gate': PedalSpec(
    PedalFamily.std,
    Color(0xFF2B2D31),
    Color(0xFFE9E9E9),
    KnobStyle.black,
    ['THRE'],
  ),
  'COMP 1': PedalSpec(
    PedalFamily.std,
    Color(0xFF9AA0A6),
    Color(0xFF1E1E1E),
    KnobStyle.black,
    ['Sustain', 'Vol'],
  ),
  'COMP 2': PedalSpec(
    PedalFamily.std,
    Color(0xFF2E4A7A),
    Color(0xFFF2F2F2),
    KnobStyle.black,
    ['Sustain', 'Attack', 'Vol', 'Clip'],
  ),
  'Touch Wah': PedalSpec(
    PedalFamily.std,
    Color(0xFF7A3E9D),
    Color(0xFFFFFFFF),
    KnobStyle.black,
    ['Sense', 'Range', 'Q', 'Mix'],
  ),
  'Auto Wah': PedalSpec(
    PedalFamily.std,
    Color(0xFFC7452F),
    Color(0xFFFFFFFF),
    KnobStyle.alu,
    ['Depth', 'Rate', 'Vol', 'Low', 'Q', 'High'],
  ),
  'Boost': PedalSpec(
    PedalFamily.mxr,
    Color(0xFFE9E1CF),
    Color(0xFF2A2A2A),
    KnobStyle.black,
    ['Gain'],
  ),
  'A-Chorus': PedalSpec(
    PedalFamily.compact,
    Color(0xFFA9B4BE),
    Color(0xFF1E2A36),
    KnobStyle.boss,
    ['Depth', 'Rate', 'Tone'],
  ),
  'B-Chorus': PedalSpec(
    PedalFamily.std,
    Color(0xFF2F8F95),
    Color(0xFFFFFFFF),
    KnobStyle.black,
    ['Depth', 'Rate', 'Vol'],
  ),
  'Flanger': PedalSpec(
    PedalFamily.std,
    Color(0xFF5C4A8E),
    Color(0xFFFFFFFF),
    KnobStyle.black,
    ['Depth', 'Rate', 'P.Delay', 'F.Back'],
  ),
  'Phaser': PedalSpec(
    PedalFamily.mxr,
    Color(0xFFF05A28),
    Color(0xFF2A1306),
    KnobStyle.mxr,
    ['Rate'],
  ),
  'Vibe': PedalSpec(
    PedalFamily.std,
    Color(0xFF2E5E3E),
    Color(0xFFF1E7C8),
    KnobStyle.chickenBlack,
    ['Depth', 'Rate'],
  ),
  'Vibrato': PedalSpec(
    PedalFamily.compact,
    Color(0xFF3C3A8C),
    Color(0xFFFFFFFF),
    KnobStyle.boss,
    ['Depth', 'Rate'],
  ),
  'Tremolo': PedalSpec(
    PedalFamily.std,
    Color(0xFF21385F),
    Color(0xFFE8E8E8),
    KnobStyle.chrome,
    ['Depth', 'Rate'],
  ),
  'Sine Trem': PedalSpec(
    PedalFamily.std,
    Color(0xFFE07A1F),
    Color(0xFF1E1406),
    KnobStyle.alu,
    ['Depth', 'Rate', 'Vol'],
  ),
  'Bias Trem': PedalSpec(
    PedalFamily.std,
    Color(0xFF7E2430),
    Color(0xFFF5E6C8),
    KnobStyle.cream,
    ['Depth', 'Rate', 'Vol', 'Bias'],
  ),
  'AC G': PedalSpec(
    PedalFamily.std,
    Color(0xFFB88A55),
    Color(0xFF2A1A08),
    KnobStyle.black,
    ['Body', 'Top', 'Vol'],
  ),
  'Octave': PedalSpec(
    PedalFamily.std,
    Color(0xFFC9C9C2),
    Color(0xFF1E1E1E),
    KnobStyle.black,
    ['Low', 'High', 'Dry'],
  ),
  'Pitch': PedalSpec(
    PedalFamily.std,
    Color(0xFFD9B92E),
    Color(0xFF1E1E1E),
    KnobStyle.black,
    ['High', 'Low Pitch', 'Dry', 'H-Vol', 'L-Vol'],
  ),
  'Detune': PedalSpec(
    PedalFamily.std,
    Color(0xFF4E7FA8),
    Color(0xFFFFFFFF),
    KnobStyle.black,
    ['Detune', 'Wet', 'Dry'],
  ),
  'Fullchor': PedalSpec(
    PedalFamily.wide,
    Color(0xFF2F5D9B),
    Color(0xFFFFFFFF),
    KnobStyle.black,
    ['Depth', 'Rate'],
  ),
  'Phaser ST': PedalSpec(
    PedalFamily.mxr,
    Color(0xFFF05A28),
    Color(0xFF2A1306),
    KnobStyle.mxr,
    ['Depth', 'Rate'],
  ),
  'Crystal Chorus': PedalSpec(
    PedalFamily.compact,
    Color(0xFF5BB8E8),
    Color(0xFF10324A),
    KnobStyle.boss,
    ['Depth', 'Rate'],
  ),
  'C-Wah': PedalSpec(
    PedalFamily.wah,
    Color(0xFF1A1A1A),
    Color(0xFFD9D9D9),
    KnobStyle.black,
    ['Range', 'Q', 'Vol'],
  ),
  'Whirlcho': PedalSpec(
    PedalFamily.std,
    Color(0xFF6B3B26),
    Color(0xFFF1E3C4),
    KnobStyle.chickenCream,
    ['Depth', 'Rate'],
  ),
  'Jet': PedalSpec(
    PedalFamily.wide,
    Color(0xFFB8BCC2),
    Color(0xFF1C1C1C),
    KnobStyle.black,
    ['Depth', 'Rate', 'F.Back'],
  ),
  'Flanser': PedalSpec(
    PedalFamily.compact,
    Color(0xFF7B4FA0),
    Color(0xFFFFFFFF),
    KnobStyle.boss,
    ['Rate', 'F-Depth', 'P-Depth'],
  ),
  'Phaser M': PedalSpec(
    PedalFamily.mxr,
    Color(0xFFF37A21),
    Color(0xFF2A1306),
    KnobStyle.mxr,
    ['Depth', 'Rate', 'F.Back'],
  ),
  'Vibrato ST': PedalSpec(
    PedalFamily.compact,
    Color(0xFF3C3A8C),
    Color(0xFFFFFFFF),
    KnobStyle.boss,
    ['Depth', 'Rate'],
  ),
  'BBD Phaser': PedalSpec(
    PedalFamily.wide,
    Color(0xFFC8CBCE),
    Color(0xFF1C1C1C),
    KnobStyle.black,
    ['Depth', 'Rate'],
  ),
  'Lofi Vibrato': PedalSpec(
    PedalFamily.compact,
    Color(0xFF4A4799),
    Color(0xFFFFFFFF),
    KnobStyle.boss,
    ['Depth', 'Rate'],
  ),
  'Flanger ST': PedalSpec(
    PedalFamily.compact,
    Color(0xFF7B4FA0),
    Color(0xFFFFFFFF),
    KnobStyle.boss,
    ['Depth', 'Rate', 'P.Delay', 'F.Back', 'Vol'],
  ),
  'Scream': PedalSpec(
    PedalFamily.ts,
    Color(0xFF3E8E4A),
    Color(0xFFF0F0F0),
    KnobStyle.black,
    ['Gain', 'Tone', 'Vol'],
  ),
  'Butter OD': PedalSpec(
    PedalFamily.mxr,
    Color(0xFFF2C230),
    Color(0xFF2A1E06),
    KnobStyle.mxr,
    ['Gain', 'Vol'],
  ),
  'JP Dist': PedalSpec(
    PedalFamily.compact,
    Color(0xFFF07A1E),
    Color(0xFF1E1E1E),
    KnobStyle.boss,
    ['Gain', 'Tone', 'Vol'],
  ),
  'Shark': PedalSpec(
    PedalFamily.std,
    Color(0xFF8E1F24),
    Color(0xFFF2F2F2),
    KnobStyle.alu,
    ['Gain', 'Tone', 'Vol'],
  ),
  'Dark Mouse': PedalSpec(
    PedalFamily.rat,
    Color(0xFF151515),
    Color(0xFFF4F4F4),
    KnobStyle.blackFlat,
    ['Gain', 'Filter', 'Vol'],
  ),
  'Grey Fuzz': PedalSpec(
    PedalFamily.wedge,
    Color(0xFF8E9196),
    Color(0xFF1E1E1E),
    KnobStyle.chickenBlack,
    ['Fuzz', 'Vol'],
  ),
  'Red Fuzz': PedalSpec(
    PedalFamily.round,
    Color(0xFFC8282A),
    Color(0xFFFFFFFF),
    KnobStyle.black,
    ['Fuzz', 'Vol'],
  ),
  'Bass Drive': PedalSpec(
    PedalFamily.std,
    Color(0xFF3A3F46),
    Color(0xFFE9E9E9),
    KnobStyle.alu,
    ['Gain', 'Blend', 'Vol', 'Bass', 'Treble'],
  ),
  'GT EQ 1': PedalSpec(
    PedalFamily.graphic,
    Color(0xFFECEAE3),
    Color(0xFF1E1E1E),
    KnobStyle.boss,
    ['125Hz', '400Hz', '800Hz', '1.6kHz', '4kHz', 'Vol'],
  ),
  'GT EQ 2': PedalSpec(
    PedalFamily.graphic,
    Color(0xFFD8DCDF),
    Color(0xFF1E1E1E),
    KnobStyle.boss,
    ['100Hz', '500Hz', '1kHz', '3kHz', '6kHz', 'Vol'],
  ),
  'Bass EQ': PedalSpec(
    PedalFamily.graphic,
    Color(0xFF2B4F86),
    Color(0xFFFFFFFF),
    KnobStyle.boss,
    ['50Hz', '120Hz', '400Hz', '800Hz', '4.5kHz', 'Vol'],
  ),
  'Studio EQ': PedalSpec(
    PedalFamily.studio,
    Color(0xFF2A2C30),
    Color(0xFFD8D8D8),
    KnobStyle.silvercap,
    ['Low Cut', 'Bass', 'Mid Freq', 'Mid', 'Q', 'Treble', 'High Cut', 'Vol'],
  ),
  'Cut 24': PedalSpec(
    PedalFamily.studio,
    Color(0xFF3A3D42),
    Color(0xFFD8D8D8),
    KnobStyle.silvercap,
    ['Low Cut', 'High Cut', 'Vol'],
  ),
  'Parametric 3': PedalSpec(
    PedalFamily.studio,
    Color(0xFF22262C),
    Color(0xFFD8D8D8),
    KnobStyle.silvercap,
    ['Low F', 'Low', 'Mid F', 'Mid', 'High F', 'High', 'Q', 'Vol'],
  ),
  'Tilt EQ': PedalSpec(
    PedalFamily.studio,
    Color(0xFF4A4D52),
    Color(0xFFE8E8E8),
    KnobStyle.silvercap,
    ['Tilt', 'Pivot', 'Low Cut', 'High Cut', 'Vol'],
  ),
  'Pure': PedalSpec(
    PedalFamily.compact,
    Color(0xFFEDEDED),
    Color(0xFF1E1E1E),
    KnobStyle.boss,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Slap': PedalSpec(
    PedalFamily.std,
    Color(0xFFE2D6B8),
    Color(0xFF2A2416),
    KnobStyle.black,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Warm': PedalSpec(
    PedalFamily.std,
    Color(0xFF2F5A3A),
    Color(0xFFE9E2C9),
    KnobStyle.black,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Mag': PedalSpec(
    PedalFamily.std,
    Color(0xFF5E6064),
    Color(0xFFEDEDED),
    KnobStyle.chrome,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Tube': PedalSpec(
    PedalFamily.std,
    Color(0xFF6E2A2A),
    Color(0xFFF2E0C4),
    KnobStyle.chickenCream,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Reverse': PedalSpec(
    PedalFamily.std,
    Color(0xFF1D1F24),
    Color(0xFFE85A4F),
    KnobStyle.black,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Analog': PedalSpec(
    PedalFamily.rack,
    Color(0xFFC9C9C4),
    Color(0xFF2A2A2A),
    KnobStyle.black,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Sweep': PedalSpec(
    PedalFamily.std,
    Color(0xFF2B5FA8),
    Color(0xFFFFFFFF),
    KnobStyle.alu,
    ['Mix', 'Time', 'F.Back', 'S-Depth', 'S-Rate'],
  ),
  'Ping Pong': PedalSpec(
    PedalFamily.std,
    Color(0xFFE7E7E7),
    Color(0xFF1E1E1E),
    KnobStyle.black,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Flash': PedalSpec(
    PedalFamily.std,
    Color(0xFFE4E9EE),
    Color(0xFF1E3A5A),
    KnobStyle.black,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Damage': PedalSpec(
    PedalFamily.std,
    Color(0xFF3F3F3F),
    Color(0xFFF2C230),
    KnobStyle.black,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Flutter': PedalSpec(
    PedalFamily.std,
    Color(0xFF8A6A4A),
    Color(0xFFF5EBD8),
    KnobStyle.cream,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Glost': PedalSpec(
    PedalFamily.std,
    Color(0xFF8FA3B8),
    Color(0xFF122233),
    KnobStyle.white,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Dark': PedalSpec(
    PedalFamily.std,
    Color(0xFF141517),
    Color(0xFF9AA0A6),
    KnobStyle.black,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Shiny': PedalSpec(
    PedalFamily.std,
    Color(0xFFD3D7DB),
    Color(0xFF1E1E1E),
    KnobStyle.chrome,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Echo': PedalSpec(
    PedalFamily.tape,
    Color(0xFF5A5D60),
    Color(0xFFEDEDED),
    KnobStyle.chickenBlack,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Float': PedalSpec(
    PedalFamily.std,
    Color(0xFF9FC7D9),
    Color(0xFF10324A),
    KnobStyle.black,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Shake': PedalSpec(
    PedalFamily.std,
    Color(0xFFB23A48),
    Color(0xFFFFFFFF),
    KnobStyle.black,
    ['Mix', 'Time', 'F.Back'],
  ),
  'Studio Delay': PedalSpec(
    PedalFamily.modern,
    Color(0xFF1C5F94),
    Color(0xFFFFFFFF),
    KnobStyle.black,
    ['Mix', 'Time', 'F.Back', 'Low Cut', 'High Cut', 'Mod', 'Duck'],
  ),
  'Tape Echo': PedalSpec(
    PedalFamily.modern,
    Color(0xFF8A6B47),
    Color(0xFFFFF4E0),
    KnobStyle.cream,
    ['Mix', 'Time', 'F.Back', 'Age', 'Wow', 'Tone', 'Duck'],
  ),
  'Dual Delay': PedalSpec(
    PedalFamily.modern,
    Color(0xFF1F8A8A),
    Color(0xFFFFFFFF),
    KnobStyle.black,
    ['Mix', 'Time', 'F.Back', 'Tap 2', 'Balance', 'Tone', 'Duck'],
  ),
  'Shimmer Delay': PedalSpec(
    PedalFamily.modern,
    Color(0xFF9C8CD9),
    Color(0xFF1C1640),
    KnobStyle.white,
    ['Mix', 'Time', 'F.Back', 'Shimmer', 'Mod', 'Tone', 'Duck'],
  ),
  'Swell Delay': PedalSpec(
    PedalFamily.modern,
    Color(0xFFC76B98),
    Color(0xFFFFFFFF),
    KnobStyle.black,
    ['Mix', 'Time', 'F.Back', 'Swell', 'Mod', 'Tone', 'Duck'],
  ),
  'Lo-Fi Delay': PedalSpec(
    PedalFamily.modern,
    Color(0xFF6E7340),
    Color(0xFFF2EFD9),
    KnobStyle.black,
    ['Mix', 'Time', 'F.Back', 'Crush', 'Mod', 'Tone', 'Duck'],
  ),
  'Air': PedalSpec(
    PedalFamily.std,
    Color(0xFFD9E6EE),
    Color(0xFF1E3A5A),
    KnobStyle.black,
    ['Mix', 'Decay', 'Damp'],
  ),
  'Room': PedalSpec(
    PedalFamily.std,
    Color(0xFF6B6E73),
    Color(0xFFFFFFFF),
    KnobStyle.alu,
    ['Mix', 'Decay'],
  ),
  'Hall': PedalSpec(
    PedalFamily.std,
    Color(0xFF23345C),
    Color(0xFFE8E8E8),
    KnobStyle.black,
    ['Mix', 'Decay'],
  ),
  'Church': PedalSpec(
    PedalFamily.std,
    Color(0xFF4A2E6B),
    Color(0xFFE8DDF5),
    KnobStyle.black,
    ['Mix', 'Decay'],
  ),
  'Plate 1': PedalSpec(
    PedalFamily.std,
    Color(0xFF6B3FB5),
    Color(0xFFFFFFFF),
    KnobStyle.black,
    ['Mix', 'Decay'],
  ),
  'Plate 2': PedalSpec(
    PedalFamily.std,
    Color(0xFF5A4632),
    Color(0xFFF1E3C4),
    KnobStyle.chickenCream,
    ['Mix', 'Decay', 'Damp'],
  ),
  'Spring': PedalSpec(
    PedalFamily.std,
    Color(0xFFB9BCC0),
    Color(0xFF8E1F24),
    KnobStyle.chrome,
    ['Mix', 'Decay'],
  ),
  'Light': PedalSpec(
    PedalFamily.std,
    Color(0xFFF1E9C9),
    Color(0xFF2A2416),
    KnobStyle.black,
    ['Mix', 'Decay'],
  ),
  'Ocean': PedalSpec(
    PedalFamily.std,
    Color(0xFF155E75),
    Color(0xFFDFF6FF),
    KnobStyle.black,
    ['Mix', 'Decay'],
  ),
  'Dream': PedalSpec(
    PedalFamily.std,
    Color(0xFFC8A2D8),
    Color(0xFF2A1440),
    KnobStyle.white,
    ['Mix', 'Decay', 'Damp', 'Mod'],
  ),
  'Studio Verb': PedalSpec(
    PedalFamily.modern,
    Color(0xFF7A2430),
    Color(0xFFFFFFFF),
    KnobStyle.black,
    ['Mix', 'Mod', 'Decay', 'High Cut', 'Damp', 'Low Cut'],
  ),
  'Ambient': PedalSpec(
    PedalFamily.modern,
    Color(0xFF1E5E66),
    Color(0xFFE8FBFF),
    KnobStyle.black,
    ['Mix', 'Mod', 'Decay', 'Tone', 'Damp', 'Low Cut'],
  ),
  'Freeze': PedalSpec(
    PedalFamily.modern,
    Color(0xFFBFD9EA),
    Color(0xFF10324A),
    KnobStyle.white,
    ['Mix', 'Decay', 'Tone', 'Damp', 'Low Cut'],
  ),
  'Duck Verb': PedalSpec(
    PedalFamily.modern,
    Color(0xFFC98A2B),
    Color(0xFF1E1406),
    KnobStyle.black,
    ['Mix', 'Duck', 'Decay', 'High Cut', 'Damp', 'Sens', 'Release'],
  ),
  'Gated': PedalSpec(
    PedalFamily.modern,
    Color(0xFF4A4D52),
    Color(0xFFF2F2F2),
    KnobStyle.black,
    ['Mix', 'Sens', 'Decay', 'High Cut', 'Damp', 'Gate', 'Low Cut'],
  ),
  'Supero 2 OD': PedalSpec(
    PedalFamily.compact,
    Color(0xFF3B5BA5),
    Color(0xFFFFFFFF),
    KnobStyle.boss,
    ['Level'],
  ),
};

const Map<String, AmpSpec> ampSpecs = {
  'TWD Deluxe': AmpSpec(
    false,
    Tolex.tweed,
    Grille.oxblood,
    AmpPanel.chrome,
    KnobStyle.chickenBrown,
    false,
    ['Gain', 'Tone', 'Vol'],
  ),
  'B-Man N': AmpSpec(
    false,
    Tolex.tweed,
    Grille.oxblood,
    AmpPanel.chrome,
    KnobStyle.chickenBrown,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'B-Man B': AmpSpec(
    false,
    Tolex.tweed,
    Grille.oxblood,
    AmpPanel.chrome,
    KnobStyle.chickenBrown,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Dark Twin': AmpSpec(
    false,
    Tolex.black,
    Grille.silver,
    AmpPanel.blackface,
    KnobStyle.skirt,
    true,
    ['Gain', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Voks 30N': AmpSpec(
    false,
    Tolex.black,
    Grille.diamond,
    AmpPanel.copper,
    KnobStyle.chickenCream,
    true,
    ['Gain', 'Cut', 'Vol'],
  ),
  'Voks 30TB': AmpSpec(
    false,
    Tolex.black,
    Grille.diamond,
    AmpPanel.copper,
    KnobStyle.chickenCream,
    true,
    ['Gain', 'Cut', 'Vol', 'Bass', 'Treble'],
  ),
  'Jazz 120': AmpSpec(
    false,
    Tolex.black,
    Grille.jc,
    AmpPanel.silver,
    KnobStyle.blackFlat,
    false,
    ['Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Calif Star CL': AmpSpec(
    false,
    Tolex.black,
    Grille.tan,
    AmpPanel.blackface,
    KnobStyle.chrome,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Calif IIC+': AmpSpec(
    false,
    Tolex.black,
    Grille.black,
    AmpPanel.blackface,
    KnobStyle.chrome,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Calif IV LD': AmpSpec(
    false,
    Tolex.black,
    Grille.black,
    AmpPanel.blackface,
    KnobStyle.chrome,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Superb CL': AmpSpec(
    false,
    Tolex.blue,
    Grille.cream,
    AmpPanel.chrome,
    KnobStyle.cream,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Superb OD': AmpSpec(
    false,
    Tolex.blue,
    Grille.cream,
    AmpPanel.chrome,
    KnobStyle.cream,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Doctor CL': AmpSpec(
    false,
    Tolex.blonde,
    Grille.oxblood,
    AmpPanel.chrome,
    KnobStyle.chickenBlack,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Doctor OD': AmpSpec(
    false,
    Tolex.blonde,
    Grille.oxblood,
    AmpPanel.chrome,
    KnobStyle.chickenBlack,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Brit 45': AmpSpec(
    true,
    Tolex.black,
    Grille.saltpepper,
    AmpPanel.gold,
    KnobStyle.goldcap,
    true,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Brit 50': AmpSpec(
    true,
    Tolex.black,
    Grille.saltpepper,
    AmpPanel.gold,
    KnobStyle.goldcap,
    true,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Brit 50JP': AmpSpec(
    true,
    Tolex.black,
    Grille.saltpepper,
    AmpPanel.gold,
    KnobStyle.goldcap,
    true,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Brit 800': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.gold,
    KnobStyle.goldcap,
    true,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Brit 900': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.gold,
    KnobStyle.goldcap,
    true,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Sol 100 OD': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.chrome,
    KnobStyle.blackFlat,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Supero 2 OD': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.chrome,
    KnobStyle.blackFlat,
    false,
    ['Gain1', 'Tone1', 'Gain2', 'Tone2', 'Vol'],
  ),
  'Sol 100 LD': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.chrome,
    KnobStyle.blackFlat,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Dizzy VH': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.alu,
    KnobStyle.blackFlat,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Dizzy VH+': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.alu,
    KnobStyle.blackFlat,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Eng 120': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.black,
    KnobStyle.silvercap,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Eng Power': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.black,
    KnobStyle.silvercap,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Halen 51': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.black,
    KnobStyle.blackFlat,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Calif DualV': AmpSpec(
    true,
    Tolex.black,
    Grille.plate,
    AmpPanel.black,
    KnobStyle.chrome,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Calif DualM': AmpSpec(
    true,
    Tolex.black,
    Grille.plate,
    AmpPanel.black,
    KnobStyle.chrome,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Flyman B1': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.brass,
    KnobStyle.goldcap,
    true,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Flyman B1+': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.brass,
    KnobStyle.goldcap,
    true,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Bog XT V': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.chrome,
    KnobStyle.blackFlat,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Bog XT M': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.chrome,
    KnobStyle.blackFlat,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Bog SV CL': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.silver,
    KnobStyle.blackFlat,
    false,
    ['Gain', 'Pres', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'Tanger R100': AmpSpec(
    true,
    Tolex.orange,
    Grille.basket,
    AmpPanel.white,
    KnobStyle.blackFlat,
    false,
    ['Gain', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
  'A BassVT': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.svt,
    KnobStyle.blackFlat,
    false,
    ['Gain', 'Bass', 'Middle', 'Treble', 'Vol'],
  ),
  'Voks Bass': AmpSpec(
    true,
    Tolex.black,
    Grille.diamond,
    AmpPanel.copper,
    KnobStyle.chickenCream,
    true,
    ['Vol', 'Bass', 'Treble'],
  ),
  'Calif Bass': AmpSpec(
    true,
    Tolex.black,
    Grille.black,
    AmpPanel.blackface,
    KnobStyle.chrome,
    false,
    ['Gain', 'Vol', 'Bass', 'Middle', 'Treble'],
  ),
};

const Map<String, CabSpec> cabSpecs = {
  'TWD 1x8': CabSpec(1, 8, Tolex.tweed, Grille.oxblood, false, false, false),
  'TWD-P 1x10': CabSpec(1, 10, Tolex.black, Grille.silver, false, true, false),
  'Viblux 1x12': CabSpec(1, 12, Tolex.black, Grille.silver, false, true, false),
  'Voks 1x12': CabSpec(1, 12, Tolex.black, Grille.diamond, false, true, false),
  'TWD 2x12': CabSpec(2, 12, Tolex.tweed, Grille.oxblood, false, false, false),
  'Double 2x12': CabSpec(2, 12, Tolex.black, Grille.silver, false, true, false),
  'Star 2x12': CabSpec(2, 12, Tolex.black, Grille.tan, false, false, true),
  'Jazz 2x12': CabSpec(2, 12, Tolex.black, Grille.jc, false, false, false),
  'BritGN 2x12': CabSpec(
    2,
    12,
    Tolex.black,
    Grille.saltpepper,
    false,
    true,
    true,
  ),
  'BritGN 4x12': CabSpec(
    4,
    12,
    Tolex.black,
    Grille.saltpepper,
    true,
    true,
    true,
  ),
  'Bog 4x12': CabSpec(4, 12, Tolex.black, Grille.black, false, false, true),
  'Dizzy 4x12': CabSpec(4, 12, Tolex.black, Grille.black, false, false, true),
  'Halen 4x12': CabSpec(4, 12, Tolex.black, Grille.black, true, false, true),
  'Sol 4x12': CabSpec(4, 12, Tolex.black, Grille.black, false, false, true),
  'Dual 4x12': CabSpec(4, 12, Tolex.black, Grille.metal, false, false, true),
  'Bass 4x10': CabSpec(4, 10, Tolex.black, Grille.check, false, false, true),
  'Mark 2x10': CabSpec(2, 10, Tolex.black, Grille.black, false, false, true),
  'Ampg 4x10': CabSpec(4, 10, Tolex.black, Grille.check, false, false, true),
  'User IR 1': CabSpec(1, 12, Tolex.grey, Grille.black, false, false, true),
  'User IR 2': CabSpec(1, 12, Tolex.grey, Grille.black, false, false, true),
  'User IR 3': CabSpec(1, 12, Tolex.grey, Grille.black, false, false, true),
  'User IR 4': CabSpec(1, 12, Tolex.grey, Grille.black, false, false, true),
  'User IR 5': CabSpec(1, 12, Tolex.grey, Grille.black, false, false, true),
  'User IR 6': CabSpec(1, 12, Tolex.grey, Grille.black, false, false, true),
  'User IR 7': CabSpec(1, 12, Tolex.grey, Grille.black, false, false, true),
  'User IR 8': CabSpec(1, 12, Tolex.grey, Grille.black, false, false, true),
  'User IR 9': CabSpec(1, 12, Tolex.grey, Grille.black, false, false, true),
  'User IR 10': CabSpec(1, 12, Tolex.grey, Grille.black, false, false, true),
};
