import 'lang.dart';

/// The custom MIDI map editor and the names of the map's functions.
abstract class MidiMapText {
  const MidiMapText();

  static MidiMapText get current =>
      appLang == Lang.pt ? const _Pt() : const _En();

  String get title;
  String get reading;
  String get notSent;
  String rows(int count, int max);
  String get notSavedYet;
  String get saved;
  String get refused;
  String get from;
  String get to;
  String function(int code);
  String option(int index);
  String get onAt64;
  String get toggle;
  String get momentary;
  String get addRow;
  String get updateRow;
  String get readAgain;
  String get saveToPedal;
  String get anyValue;
  String get colOrigin;
  String get colFunction;
  String get colOption;
  String get newRow;
  String get typeLabel;
  String get valueLabel;
  String get modeLabel;
  String get channelLabel;
  String get functionLabel;
  String get optionLabel;
  String get editRow;
  String removeRow(String source);

  /// Function code -> name.
  Map<int, String> get functions;

  /// The options that read differently in this language, by function code;
  /// the others are the pedal's own names.
  Map<int, List<String>> get options;
}

class _En extends MidiMapText {
  const _En();

  @override
  String get title => 'Custom MIDI map';
  @override
  String get reading => 'Reading the map from the pedal…';
  @override
  String get notSent => 'The pedal did not send its map';
  @override
  String rows(int count, int max) => '$count / $max rows';
  @override
  String get notSavedYet => 'Not saved yet';
  @override
  String get saved => 'Saved to the pedal';
  @override
  String get refused => 'The pedal did not take the map';
  @override
  String get from => 'from';
  @override
  String get to => 'to';
  @override
  String function(int code) => 'Function $code';
  @override
  String option(int index) => 'Option $index';
  @override
  String get onAt64 => '≥ 64 on';
  @override
  String get toggle => 'Toggle';
  @override
  String get momentary => 'Momentary';
  @override
  String get addRow => 'Add row';
  @override
  String get updateRow => 'Update row';
  @override
  String get readAgain => 'Read again';
  @override
  String get saveToPedal => 'Save to pedal';
  @override
  String get anyValue => 'any';
  @override
  String get colOrigin => 'SOURCE';
  @override
  String get colFunction => 'FUNCTION';
  @override
  String get colOption => 'OPTION';
  @override
  String get newRow => 'NEW ROW';
  @override
  String get typeLabel => 'Type';
  @override
  String get valueLabel => 'Value';
  @override
  String get modeLabel => 'Mode';
  @override
  String get channelLabel => 'MIDI CH';
  @override
  String get functionLabel => 'Function';
  @override
  String get optionLabel => 'Option';
  @override
  String get editRow => 'EDIT ROW';
  @override
  String removeRow(String source) => 'Remove row $source';
  @override
  Map<int, String> get functions => const {
    1: 'Select preset',
    2: 'Bank − / +',
    3: 'Preset − / +',
    4: 'Tuner on / off',
    5: 'Tap tempo',
    6: 'Tap + division',
    7: 'Looper window',
    8: 'Looper rec / play / clear',
    9: 'Looper volume',
    10: 'Looper Pre / Post',
    11: 'Drum',
    12: 'Block on / off',
    13: 'STOMP FS1 / FS2',
    14: 'Scene',
    15: 'Volume',
    16: 'Knob role',
    17: 'Freeze',
    18: 'EXP A–D',
    19: 'Global EQ on / off',
    20: 'Footswitch mode cycle',
    21: 'Ignored',
    22: 'Expression',
    23: 'Tempo set (range / value)',
    24: 'Sync on / off',
    25: 'Delay note − / +',
  };
  @override
  Map<int, List<String>> get options => const {
    2: ['Bank −', 'Bank +'],
    8: ['Rec / overdub', 'Play / stop', 'Clear', 'Rec / Play', 'Stop'],
    9: ['Rec volume', 'Play volume'],
    11: ['Window', 'Play / stop', 'Rhythm', 'Volume'],
    23: ['BPM range', 'BPM value'],
    25: ['Shorter', 'Longer', 'Back to the preset note'],
  };
}

class _Pt extends MidiMapText {
  const _Pt();

  @override
  String get title => 'Mapa MIDI personalizado';
  @override
  String get reading => 'Lendo o mapa da pedaleira…';
  @override
  String get notSent => 'A pedaleira não enviou o mapa';
  @override
  String rows(int count, int max) => '$count / $max linhas';
  @override
  String get notSavedYet => 'Ainda não salvo';
  @override
  String get saved => 'Salvo na pedaleira';
  @override
  String get refused => 'A pedaleira não aceitou o mapa';
  @override
  String get from => 'de';
  @override
  String get to => 'até';
  @override
  String function(int code) => 'Função $code';
  @override
  String option(int index) => 'Opção $index';
  @override
  String get onAt64 => '≥ 64 liga';
  @override
  String get toggle => 'Alterna';
  @override
  String get momentary => 'Momentâneo';
  @override
  String get addRow => 'Adicionar linha';
  @override
  String get updateRow => 'Atualizar linha';
  @override
  String get readAgain => 'Ler de novo';
  @override
  String get saveToPedal => 'Salvar na pedaleira';
  @override
  String get anyValue => 'qualquer';
  @override
  String get colOrigin => 'ORIGEM';
  @override
  String get colFunction => 'FUNÇÃO';
  @override
  String get colOption => 'OPÇÃO';
  @override
  String get newRow => 'NOVA LINHA';
  @override
  String get typeLabel => 'Tipo';
  @override
  String get valueLabel => 'Valor';
  @override
  String get modeLabel => 'Modo';
  @override
  String get channelLabel => 'MIDI CH';
  @override
  String get functionLabel => 'Função';
  @override
  String get optionLabel => 'Opção';
  @override
  String get editRow => 'EDITAR LINHA';
  @override
  String removeRow(String source) => 'Remover linha $source';
  @override
  Map<int, String> get functions => const {
    1: 'Escolher preset',
    2: 'Banco − / +',
    3: 'Preset − / +',
    4: 'Afinador liga / desliga',
    5: 'Tap tempo',
    6: 'Tap + divisão',
    7: 'Janela do looper',
    8: 'Looper grava / toca / limpa',
    9: 'Volume do looper',
    10: 'Looper Pre / Post',
    11: 'Drum',
    12: 'Bloco liga / desliga',
    13: 'STOMP FS1 / FS2',
    14: 'Cena',
    15: 'Volume',
    16: 'Papel do knob',
    17: 'Freeze',
    18: 'EXP A–D',
    19: 'EQ global liga / desliga',
    20: 'Ciclar modo do footswitch',
    21: 'Ignorado',
    22: 'Expressão',
    23: 'Definir tempo (faixa / valor)',
    24: 'Sync liga / desliga',
    25: 'Nota do delay − / +',
  };
  @override
  Map<int, List<String>> get options => const {
    2: ['Banco −', 'Banco +'],
    8: ['Grava / overdub', 'Toca / para', 'Limpa', 'Grava / toca', 'Para'],
    9: ['Volume de gravação', 'Volume de reprodução'],
    11: ['Janela', 'Toca / para', 'Ritmo', 'Volume'],
    23: ['Faixa de BPM', 'Valor de BPM'],
    25: ['Mais curta', 'Mais longa', 'Volta à nota do preset'],
  };
}
