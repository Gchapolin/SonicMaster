import 'lang.dart';

/// The editor shell: preset browser, rail and drawer, module editor, rotate
/// prompt, fullscreen and battery.
abstract class ShellText {
  const ShellText();

  static ShellText get current =>
      appLang == Lang.pt ? const _Pt() : const _En();

  String get noDeviceConnected;
  String get noPresetSelected;
  String get tryDemo;
  String get masterVol;
  String get presetVol;
  String get factory;
  String get user;
  String get byAuthor;
  String get searchPresets;
  String get rotatePrompt;
  String get rotateBody;
  String get fullscreen;
  String get exitFullscreen;
  String get rotateFullscreenHint;
  String get rotateLockHint;
  String noDecodedEffect(String module);
  String get blockOn;
  String get cloneMode;
  String get userSlots;
  String get footSwitch;
  String get none;
  String get batteryCharging;
  String get batteryCharged;
  String get battOnly;
  String batteryEmpty(String volts);
  String batteryLow(String volts);
  String battery(int bars, String volts);
}

class _En extends ShellText {
  const _En();

  @override
  String get noDeviceConnected => 'No device connected';
  @override
  String get noPresetSelected => 'No preset selected';
  @override
  String get tryDemo => 'Try demo';
  @override
  String get masterVol => 'Master Vol';
  @override
  String get presetVol => 'Preset Vol';
  @override
  String get factory => 'Factory';
  @override
  String get user => 'User';
  @override
  String get byAuthor => 'by Skyggedans';
  @override
  String get searchPresets => 'Search presets';
  @override
  String get rotatePrompt => 'Rotate your device to landscape';
  @override
  String get rotateBody =>
      'The SonicMaster editor is laid out for a landscape screen.';
  @override
  String get fullscreen => 'Fullscreen';
  @override
  String get exitFullscreen => 'Exit fullscreen';
  @override
  String get rotateFullscreenHint =>
      'Fullscreen also turns the screen when auto-rotate is off.';
  @override
  String get rotateLockHint =>
      'If the screen does not turn, switch off the rotation lock.';
  @override
  String noDecodedEffect(String module) => '$module — no decoded effect';
  @override
  String get blockOn => 'Block on';
  @override
  String get cloneMode => 'Clone Mode';
  @override
  String get userSlots => 'User slots';
  @override
  String get footSwitch => 'Foot Switch';
  @override
  String get none => 'None';
  @override
  String get batteryCharging => 'Charging (USB power)';
  @override
  String get batteryCharged => 'Charged (on USB power)';
  @override
  String get battOnly => ' · Batt Only: not charging from USB';
  @override
  String batteryEmpty(String volts) =>
      'Battery empty (below $volts): charge the pedal';
  @override
  String batteryLow(String volts) => 'Battery low: 1 of 4 · $volts';
  @override
  String battery(int bars, String volts) => 'Battery: $bars of 4 · $volts';
}

class _Pt extends ShellText {
  const _Pt();

  @override
  String get noDeviceConnected => 'Nenhuma pedaleira conectada';
  @override
  String get noPresetSelected => 'Nenhum preset selecionado';
  @override
  String get tryDemo => 'Testar demo';
  @override
  String get masterVol => 'Volume geral';
  @override
  String get presetVol => 'Vol. do preset';
  @override
  String get factory => 'Fábrica';
  @override
  String get user => 'Usuário';
  @override
  String get byAuthor => 'por Skyggedans';
  @override
  String get searchPresets => 'Buscar presets';
  @override
  String get rotatePrompt => 'Gire o aparelho para a horizontal';
  @override
  String get rotateBody =>
      'O editor SonicMaster foi feito para a tela na horizontal.';
  @override
  String get fullscreen => 'Tela cheia';
  @override
  String get exitFullscreen => 'Sair da tela cheia';
  @override
  String get rotateFullscreenHint =>
      'A tela cheia também gira a tela quando a rotação automática está '
      'desligada.';
  @override
  String get rotateLockHint =>
      'Se a tela não girar, desligue o bloqueio de rotação.';
  @override
  String noDecodedEffect(String module) =>
      '$module — nenhum efeito decodificado';
  @override
  String get blockOn => 'Bloco ligado';
  @override
  String get cloneMode => 'Modo Clone';
  @override
  String get userSlots => 'Slots do usuário';
  @override
  String get footSwitch => 'Footswitch';
  @override
  String get none => 'Nenhum';
  @override
  String get batteryCharging => 'Carregando (energia USB)';
  @override
  String get batteryCharged => 'Carregada (na energia USB)';
  @override
  String get battOnly => ' · Batt Only: sem carga pela USB';
  @override
  String batteryEmpty(String volts) =>
      'Bateria vazia (abaixo de $volts): carregue a pedaleira';
  @override
  String batteryLow(String volts) => 'Bateria fraca: 1 de 4 · $volts';
  @override
  String battery(int bars, String volts) => 'Bateria: $bars de 4 · $volts';
}
