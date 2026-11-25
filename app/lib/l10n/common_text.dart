import 'lang.dart';

/// Words used across the app (buttons of every dialog).
abstract class CommonText {
  const CommonText();

  static CommonText get current =>
      appLang == Lang.pt ? const _Pt() : const _En();

  String get cancel;
  String get close;
  String get save;
  String get retry;
}

class _En extends CommonText {
  const _En();

  @override
  String get cancel => 'Cancel';
  @override
  String get close => 'Close';
  @override
  String get save => 'Save';
  @override
  String get retry => 'Retry';
}

class _Pt extends CommonText {
  const _Pt();

  @override
  String get cancel => 'Cancelar';
  @override
  String get close => 'Fechar';
  @override
  String get save => 'Salvar';
  @override
  String get retry => 'Tentar de novo';
}
