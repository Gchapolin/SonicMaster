import 'lang.dart';

/// The tuner dialog.
abstract class TunerText {
  const TunerText();

  static TunerText get current =>
      appLang == Lang.pt ? const _Pt() : const _En();

  String get title;
  String get opening;
  String get playString;
  String get inTune;
  String get flat;
  String get sharp;
  String get mute;
}

class _En extends TunerText {
  const _En();

  @override
  String get title => 'Tuner';
  @override
  String get opening => 'Opening the pedal\'s tuner…';
  @override
  String get playString => 'Play a string';
  @override
  String get inTune => 'IN TUNE';
  @override
  String get flat => 'FLAT';
  @override
  String get sharp => 'SHARP';
  @override
  String get mute => 'Mute';
}

class _Pt extends TunerText {
  const _Pt();

  @override
  String get title => 'Afinador';
  @override
  String get opening => 'Abrindo o afinador da pedaleira…';
  @override
  String get playString => 'Toque uma corda';
  @override
  String get inTune => 'AFINADO';
  @override
  String get flat => 'BAIXO';
  @override
  String get sharp => 'ALTO';
  @override
  String get mute => 'Mudo';
}
