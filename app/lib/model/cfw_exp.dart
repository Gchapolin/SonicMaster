/// What one of the CFW's four expression controllers (EXP A-D) moves in the
/// loaded preset: one knob of one module, between [min] and [max] percent of
/// its range (register 0x3D, docs/cfw-protocol/capture-notes.md).
class ExpAssign {
  const ExpAssign({
    required this.module,
    required this.algId,
    this.mode = continuous,
    this.min = 0,
    this.max = 100,
  });

  static const continuous = 0;
  static const toggle = 1;
  static const momentary = 2;

  /// Physical module id (0 NR … 8 RVB).
  final int module;
  final int algId;

  /// [continuous], [toggle] or [momentary].
  final int mode;

  /// Range ends, 0..100 %.
  final int min;
  final int max;

  ExpAssign copyWith({int? mode, int? min, int? max}) => ExpAssign(
    module: module,
    algId: algId,
    mode: mode ?? this.mode,
    min: min ?? this.min,
    max: max ?? this.max,
  );

  @override
  bool operator ==(Object other) =>
      other is ExpAssign &&
      other.module == module &&
      other.algId == algId &&
      other.mode == mode &&
      other.min == min &&
      other.max == max;

  @override
  int get hashCode => Object.hash(module, algId, mode, min, max);

  @override
  String toString() => 'ExpAssign($module/$algId mode $mode $min..$max)';
}
