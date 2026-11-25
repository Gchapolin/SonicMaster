/// The CFW's Global EQ block (register 0x3A): one EQ after the whole chain,
/// for every preset. [slots] holds the model's 8 raw values, indexed by algId
/// (signed; dB knobs are in 0.5 dB steps — see CfwEqParam.toSlot).
class CfwGlobalEq {
  const CfwGlobalEq({
    required this.isOn,
    required this.model,
    required this.slots,
  });

  final bool isOn;

  /// Wire model index: 0 Studio EQ, 1 Parametric 3, 2 Cut 24, 3 Tilt EQ.
  final int model;
  final List<int> slots;

  CfwGlobalEq copyWith({bool? isOn, int? model, List<int>? slots}) =>
      CfwGlobalEq(
        isOn: isOn ?? this.isOn,
        model: model ?? this.model,
        slots: slots ?? this.slots,
      );

  CfwGlobalEq withSlot(int algId, int value) =>
      copyWith(slots: [...slots]..[algId] = value);
}
