import 'lang.dart';

/// The Settings dialog and its preset order section.
abstract class SettingsText {
  const SettingsText();

  static SettingsText get current =>
      appLang == Lang.pt ? const _Pt() : const _En();

  String get title;
  String get reading;

  // Section headers.
  String get levels;
  String get globalEq;
  String get display;
  String get footswitches;
  String get presetOrder;
  String get wholePedal;
  String get power;
  String get reset;

  // Rows and options.
  String get input;
  String get mode;
  String get directMonitor;
  String get target;
  String get func1;
  String get func2;
  String get theme;
  String get themeDefault;
  String get backlight;
  String get brightness;
  String get pedalMode;
  String get scene;
  String get confirm;
  String get battOnly;
  String get model;
  String get tuner;

  // MIDI.
  String get midiMap;
  String get mapStock;
  String get mapGeneric;
  String get mapCustom;
  String get firstPc;
  String get levelCcRange;
  String get customMapRows;
  String get editMap;
  String get midiChannel;
  String get allChannels;
  String channel(int ch);
  String get sameAgain;
  String get off;
  String get cycle;
  String get back;
  String get tempoScope;
  String get drumSync;

  // Factory reset.
  String get resetButton;
  String get resetTitle;
  String get resetBody;
  String get resetConfirm;

  // Device model.
  String get deviceModel;
  String get detecting;
  String get auto;
  String get unknownDevice;

  // Preset order.
  String get move;
  String get toPosition;
  String movedTo(String label);
  String get orderRefused;
  String get orderHint;
  String get movePreset;

  // Whole-pedal backup rows.
  String get backupRow;
  String get restoreRow;
  String get usbRecommended;
}

class _En extends SettingsText {
  const _En();

  @override
  String get title => 'Settings';
  @override
  String get reading => 'Reading settings…';
  @override
  String get levels => 'Levels';
  @override
  String get globalEq => 'Global EQ';
  @override
  String get display => 'Display';
  @override
  String get footswitches => 'Footswitches';
  @override
  String get presetOrder => 'Preset order';
  @override
  String get wholePedal => 'Whole pedal';
  @override
  String get power => 'Power';
  @override
  String get reset => 'Reset';
  @override
  String get input => 'Input';
  @override
  String get mode => 'Mode';
  @override
  String get directMonitor => 'Direct Monitor';
  @override
  String get target => 'Target';
  @override
  String get func1 => 'Func 1';
  @override
  String get func2 => 'Func 2';
  @override
  String get theme => 'Theme';
  @override
  String get themeDefault => 'Default';
  @override
  String get backlight => 'Backlight';
  @override
  String get brightness => 'Brightness';
  @override
  String get pedalMode => 'Pedal mode';
  @override
  String get scene => 'Scene';
  @override
  String get confirm => 'Confirm';
  @override
  String get battOnly => 'Batt Only';
  @override
  String get model => 'Model';
  @override
  String get tuner => 'Tuner';
  @override
  String get midiMap => 'MIDI map';
  @override
  String get mapStock => 'Stock';
  @override
  String get mapGeneric => 'Generic MIDI';
  @override
  String get mapCustom => 'Custom';
  @override
  String get firstPc => 'First PC';
  @override
  String get levelCcRange => 'Level CC range';
  @override
  String get customMapRows => 'Custom map rows';
  @override
  String get editMap => 'Edit map';
  @override
  String get midiChannel => 'MIDI channel';
  @override
  String get allChannels => 'All channels';
  @override
  String channel(int ch) => 'Channel $ch';
  @override
  String get sameAgain => 'Same preset again';
  @override
  String get off => 'Off';
  @override
  String get cycle => 'Cycle';
  @override
  String get back => 'Back';
  @override
  String get tempoScope => 'Tempo scope';
  @override
  String get drumSync => 'Drum Sync';
  @override
  String get resetButton => 'Reset to factory settings';
  @override
  String get resetTitle => 'Reset to factory settings?';
  @override
  String get resetBody =>
      'This restores all presets and settings to factory defaults. '
      'The pedal will reboot and disconnect.';
  @override
  String get resetConfirm => 'Reset';
  @override
  String get deviceModel => 'Device model';
  @override
  String get detecting => 'detecting…';
  @override
  String get auto => 'Auto';
  @override
  String get unknownDevice => 'Unknown device';
  @override
  String get move => 'Move';
  @override
  String get toPosition => 'To position';
  @override
  String movedTo(String label) => 'Moved to $label';
  @override
  String get orderRefused => 'The pedal did not take the new order';
  @override
  String get orderHint => 'MIDI and footswitches follow the new order.';
  @override
  String get movePreset => 'Move preset';
  @override
  String get backupRow => 'Backup';
  @override
  String get restoreRow => 'Restore from a file';
  @override
  String get usbRecommended => 'USB recommended (Bluetooth is slow).';
}

class _Pt extends SettingsText {
  const _Pt();

  @override
  String get title => 'Ajustes';
  @override
  String get reading => 'Lendo os ajustes…';
  @override
  String get levels => 'Níveis';
  @override
  String get globalEq => 'EQ global';
  @override
  String get display => 'Tela';
  @override
  String get footswitches => 'Footswitches';
  @override
  String get presetOrder => 'Ordem dos presets';
  @override
  String get wholePedal => 'Pedaleira inteira';
  @override
  String get power => 'Energia';
  @override
  String get reset => 'Redefinir';
  @override
  String get input => 'Entrada';
  @override
  String get mode => 'Modo';
  @override
  String get directMonitor => 'Monitor direto';
  @override
  String get target => 'Destino';
  @override
  String get func1 => 'Função 1';
  @override
  String get func2 => 'Função 2';
  @override
  String get theme => 'Tema';
  @override
  String get themeDefault => 'Padrão';
  @override
  String get backlight => 'Luz';
  @override
  String get brightness => 'Brilho';
  @override
  String get pedalMode => 'Modo da pedaleira';
  @override
  String get scene => 'Cena';
  @override
  String get confirm => 'Confirmar';
  @override
  String get battOnly => 'Só bateria';
  @override
  String get model => 'Modelo';
  @override
  String get tuner => 'Afinador';
  @override
  String get midiMap => 'Mapa MIDI';
  @override
  String get mapStock => 'Original';
  @override
  String get mapGeneric => 'MIDI genérico';
  @override
  String get mapCustom => 'Personalizado';
  @override
  String get firstPc => 'Primeiro PC';
  @override
  String get levelCcRange => 'Faixa do CC de nível';
  @override
  String get customMapRows => 'Linhas do mapa personalizado';
  @override
  String get editMap => 'Editar mapa';
  @override
  String get midiChannel => 'Canal MIDI';
  @override
  String get allChannels => 'Todos os canais';
  @override
  String channel(int ch) => 'Canal $ch';
  @override
  String get sameAgain => 'Preset repetido';
  @override
  String get off => 'Desligado';
  @override
  String get cycle => 'Ciclar';
  @override
  String get back => 'Voltar';
  @override
  String get tempoScope => 'Alcance do tempo';
  @override
  String get drumSync => 'Sincronizar bateria';
  @override
  String get resetButton => 'Redefinir para o padrão de fábrica';
  @override
  String get resetTitle => 'Redefinir para o padrão de fábrica?';
  @override
  String get resetBody =>
      'Isso volta todos os presets e ajustes ao padrão de fábrica. '
      'A pedaleira vai reiniciar e desconectar.';
  @override
  String get resetConfirm => 'Redefinir';
  @override
  String get deviceModel => 'Modelo do aparelho';
  @override
  String get detecting => 'detectando…';
  @override
  String get auto => 'Auto';
  @override
  String get unknownDevice => 'Aparelho desconhecido';
  @override
  String get move => 'Mover';
  @override
  String get toPosition => 'Para a posição';
  @override
  String movedTo(String label) => 'Movido para $label';
  @override
  String get orderRefused => 'A pedaleira não aceitou a nova ordem';
  @override
  String get orderHint => 'MIDI e footswitches seguem a nova ordem.';
  @override
  String get movePreset => 'Mover preset';
  @override
  String get backupRow => 'Backup';
  @override
  String get restoreRow => 'Restaurar de um arquivo';
  @override
  String get usbRecommended => 'USB recomendado (o Bluetooth é lento).';
}
