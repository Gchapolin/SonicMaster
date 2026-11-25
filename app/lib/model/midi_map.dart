/// One row of the CFW's custom MIDI map (register 0x39): a MIDI message (CC or
/// PC, a number range, a channel, a value condition) and the pedal function it
/// fires. Layout and names from docs/cfw-protocol/capture-notes.md.
class MidiMapEntry {
  const MidiMapEntry({
    this.trigger = cc,
    this.channel = 0,
    this.from = 0,
    this.to = 0,
    this.value = 0,
    this.function = 5,
    this.which = 0,
    this.switchMode = 0,
  });

  factory MidiMapEntry.fromBytes(List<int> b) => MidiMapEntry(
    trigger: b[0],
    channel: b[1],
    from: b[2],
    to: b[3],
    value: b[4],
    function: b[5],
    which: b[6],
    switchMode: b[7],
  );

  static const cc = 1;
  static const pc = 2;

  /// The most rows a map holds.
  static const maxEntries = 64;

  /// Function code -> name.
  static const functions = <int, String>{
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

  static const _options = <int, List<String>>{
    2: ['Bank −', 'Bank +'],
    3: ['Preset −', 'Preset +'],
    6: ['1/4', '1/8·', '1/8', '1/2', '1/16', '1/8T', '1/4·', '1/4T', '1/16T'],
    8: ['Rec / overdub', 'Play / stop', 'Clear', 'Rec / Play', 'Stop'],
    9: ['Rec volume', 'Play volume'],
    11: ['Window', 'Play / stop', 'Rhythm', 'Volume'],
    12: ['NR', 'FX1', 'DRV', 'AMP', 'IR', 'EQ', 'FX2', 'DLY', 'RVB'],
    13: ['FS1', 'FS2'],
    14: ['SC1', 'SC2', 'BASE'],
    15: ['Master', 'Preset'],
    16: [
      'IR Vol',
      'EQ Vol',
      'DRV Gain',
      'DRV Vol',
      'AMP Gain',
      'AMP Vol',
      'DLY Mix',
      'RVB Mix',
    ],
    18: ['EXP A', 'EXP B', 'EXP C', 'EXP D'],
    23: ['BPM range', 'BPM value'],
    24: ['DLY', 'FX1', 'FX2'],
    25: ['Shorter', 'Longer', 'Back to the preset note'],
  };

  /// The functions whose switch byte matters (they turn something on / off).
  static const _switched = {4, 7, 8, 10, 11, 12, 17, 19};

  /// [cc] or [pc].
  final int trigger;

  /// 0 follows the pedal's MIDI channel, 1..16 a fixed channel.
  final int channel;

  /// The CC / PC numbers this row answers to, [from]..[to].
  final int from;
  final int to;

  /// 0 any, 1 ">= 64", 2 "< 64", 0x80 | n "= n".
  final int value;

  /// Key of [functions].
  final int function;

  /// Index of the first option of [function]; a number range walks the
  /// options from there.
  final int which;

  /// 0 ">= 64 on", 1 toggle, 2 momentary.
  final int switchMode;

  /// What [function] can act on (empty: nothing to choose).
  static List<String> optionsOf(int function) => function == 1
      ? [
          for (var i = 0; i < 100; i++)
            '${i < 50 ? 'P' : 'F'}${(i % 50 + 1).toString().padLeft(2, '0')}',
        ]
      : _options[function] ?? const [];

  static String valueLabel(int value) => switch (value) {
    1 => '≥ 64',
    2 => '< 64',
    >= 0x80 => '= ${value & 0x7F}',
    _ => 'any',
  };

  bool get hasSwitch => _switched.contains(function);

  List<int> toBytes() => [
    trigger,
    channel,
    from,
    to,
    value,
    function,
    which,
    switchMode,
  ];

  /// "PC 101–102 → Bank −, Bank +".
  String describe() {
    final message =
        '${trigger == pc ? 'PC' : 'CC'} $from${to == from ? '' : '–$to'}';
    final name = functions[function] ?? 'Function $function';
    final options = optionsOf(function);
    final count = to - from + 1;

    if (options.isEmpty || which >= options.length) return '$message → $name';

    final last = (which + count - 1).clamp(which, options.length - 1);
    final picked = last == which
        ? options[which]
        : last - which == 1
        ? '${options[which]}, ${options[last]}'
        : '${options[which]} … ${options[last]}';

    // "Bank − / +" already says what its two options are.
    return picked.startsWith(name.split(' ').first) && last > which
        ? '$message → $picked'
        : '$message → $name: $picked';
  }

  MidiMapEntry copyWith({
    int? trigger,
    int? channel,
    int? from,
    int? to,
    int? value,
    int? function,
    int? which,
    int? switchMode,
  }) => MidiMapEntry(
    trigger: trigger ?? this.trigger,
    channel: channel ?? this.channel,
    from: from ?? this.from,
    to: to ?? this.to,
    value: value ?? this.value,
    function: function ?? this.function,
    which: which ?? this.which,
    switchMode: switchMode ?? this.switchMode,
  );

  @override
  bool operator ==(Object other) =>
      other is MidiMapEntry && '${other.toBytes()}' == '${toBytes()}';

  @override
  int get hashCode => Object.hashAll(toBytes());

  @override
  String toString() => 'MidiMapEntry(${toBytes()})';
}
