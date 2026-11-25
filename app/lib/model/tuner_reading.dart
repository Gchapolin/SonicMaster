/// One reading of the CFW pedal's tuner (register 0x3F,
/// docs/cfw-protocol/capture-notes.md).
class TunerReading {
  const TunerReading({
    required this.flags,
    required this.cents,
    required this.hz,
    required this.a4,
    this.note,
    this.octave,
  });

  /// Note names by the pedal's index, which counts from A.
  static const noteNames = [
    'A', 'A#', 'B', 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', //
  ];

  /// bit0 tuner open, bit1 the pedal hears a note, bit5 output muted.
  final int flags;

  /// Note index from A (0..11), null with no note.
  final int? note;
  final int? octave;

  /// Distance from [note] in cents (negative = flat).
  final double cents;
  final double hz;

  /// Reference pitch in Hz (430..450).
  final int a4;

  bool get isOpen => flags & 0x01 != 0;

  bool get hasNote => flags & 0x02 != 0 && note != null && octave != null;

  bool get isMuted => flags & 0x20 != 0;

  String? get noteName => note == null ? null : noteNames[note!];
}
