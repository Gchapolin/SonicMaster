import 'lang.dart';

/// The Appearance dialog.
abstract class AppearanceText {
  const AppearanceText();

  static AppearanceText get current =>
      appLang == Lang.pt ? const _Pt() : const _En();

  String get title;
  String get appColor;
  String get appColorHint;
  String get close;
}

class _En extends AppearanceText {
  const _En();

  @override
  String get title => 'Appearance';
  @override
  String get appColor => 'App color';
  @override
  String get appColorHint =>
      'Adobe Color palettes (Neutral Vintage). Changes the editor interface; '
      'amps, cabs and pedals keep their own colors. Saved on this device.';
  @override
  String get close => 'Close';
}

class _Pt extends AppearanceText {
  const _Pt();

  @override
  String get title => 'Aparência';
  @override
  String get appColor => 'Cor do app';
  @override
  String get appColorHint =>
      'Paletas do Adobe Color (Neutral Vintage). Muda a interface do editor; '
      'os amps, gabinetes e pedais mantêm as cores deles. Fica salva neste '
      'aparelho.';
  @override
  String get close => 'Fechar';
}
