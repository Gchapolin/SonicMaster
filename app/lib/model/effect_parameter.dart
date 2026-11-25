import 'widget_type.dart';

/// One tweakable parameter of an effect (a knob, toggle, or selector).
class EffectParameter {
  const EffectParameter({
    required this.name,
    required this.algId,
    required this.defaultValue,
    required this.widgetType,
    this.min,
    this.max,
    this.step,
    this.unit,
    this.options,
    this.syncToggleAlgId,
    this.texts = const {},
    this.syncMask = 1,
    this.onlyOnCfw,
  });

  final String name;
  final int algId;
  final num defaultValue;
  final WidgetType widgetType;
  final num? min;
  final num? max;
  final num? step;
  final String? unit;
  final List<String>? options;

  /// When non-null, this (Hz) knob is tempo-sync-capable: while the toggle at
  /// this algId is on, the pedal reinterprets the value as a note-division
  /// index (see `syncDivisions`) and the editor shows a division selector
  /// instead of the Hz knob.
  final int? syncToggleAlgId;

  /// The bit of the [syncToggleAlgId] value that means "synced": 1 for the
  /// stock Sync toggles, 2 for the CFW delays' Off/Trail/Sync/Both cell.
  final int syncMask;

  /// Whether this tempo knob holds a note division given the effect's
  /// [values] (algId -> value).
  bool isSynced(Map<int, num> values) =>
      syncToggleAlgId != null &&
      ((values[syncToggleAlgId] ?? 0).round() & syncMask) != 0;

  /// Which firmware has this knob: null both, true only the CFW (its extra
  /// knobs on the stock delays and reverbs), false only stock (the knob the
  /// CFW moves away from that slot).
  final bool? onlyOnCfw;

  /// Whether the pedal's firmware ([isCfw]) has this knob.
  bool isShownOn({required bool isCfw}) =>
      onlyOnCfw == null || onlyOnCfw == isCfw;

  /// This knob, kept to the stock firmware.
  EffectParameter get stockOnly => EffectParameter(
    name: name,
    algId: algId,
    defaultValue: defaultValue,
    widgetType: widgetType,
    min: min,
    max: max,
    step: step,
    unit: unit,
    options: options,
    syncToggleAlgId: syncToggleAlgId,
    texts: texts,
    syncMask: syncMask,
    onlyOnCfw: false,
  );

  /// Display text per value ("21Hz", "-3.5dB"), keyed like the CFW app's data
  /// ("12", "-3.5"); empty for the stock effects.
  final Map<String, String> texts;

  /// The text for [value], or null when the data has none.
  String? textFor(num value) =>
      texts[value == value.roundToDouble()
          ? value.round().toString()
          : value.toString()];

  factory EffectParameter.fromJson(Map<String, dynamic> json) =>
      EffectParameter(
        name: json['name'] as String,
        algId: json['algId'] as int,
        defaultValue: json['defaultValue'] as num,
        widgetType: WidgetType.fromCode(json['widgetType'] as int),
        min: json['min'] as num?,
        max: json['max'] as num?,
        step: json['step'] as num?,
        unit: json['unit'] as String?,
        options: (json['options'] as List?)?.cast<String>(),
        syncToggleAlgId: json['syncToggleAlgId'] as int?,
      );
}
