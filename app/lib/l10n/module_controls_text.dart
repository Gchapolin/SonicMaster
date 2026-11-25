import 'lang.dart';

/// The CFW controls under a module's knobs (scenes, EXP A-D) and the status
/// messages their edits leave.
abstract class ModuleControlsText {
  const ModuleControlsText();

  static ModuleControlsText get current =>
      appLang == Lang.pt ? const _Pt() : const _En();

  String get scenes;
  String get follow;
  String get on;
  String get off;
  String get none;
  String knob(int algId);
  String module(int id);
  String get continuous;
  String get toggle;
  String get momentary;
  String get expNotChanged;
  String editFailed(Object e);
}

class _En extends ModuleControlsText {
  const _En();

  @override
  String get scenes => 'SCENES';
  @override
  String get follow => 'Follow';
  @override
  String get on => 'On';
  @override
  String get off => 'Off';
  @override
  String get none => 'None';
  @override
  String knob(int algId) => 'Knob $algId';
  @override
  String module(int id) => 'Module $id';
  @override
  String get continuous => 'Cont';
  @override
  String get toggle => 'Toggle';
  @override
  String get momentary => 'Moment';
  @override
  String get expNotChanged => 'EXP not changed: the pedal did not answer';
  @override
  String editFailed(Object e) => 'edit failed: $e';
}

class _Pt extends ModuleControlsText {
  const _Pt();

  @override
  String get scenes => 'CENAS';
  @override
  String get follow => 'Seguir';
  @override
  String get on => 'Ligado';
  @override
  String get off => 'Desligado';
  @override
  String get none => 'Nenhum';
  @override
  String knob(int algId) => 'Knob $algId';
  @override
  String module(int id) => 'Módulo $id';
  @override
  String get continuous => 'Cont.';
  @override
  String get toggle => 'Alterna';
  @override
  String get momentary => 'Moment.';
  @override
  String get expNotChanged => 'EXP não mudou: a pedaleira não respondeu';
  @override
  String editFailed(Object e) => 'falha na edição: $e';
}
