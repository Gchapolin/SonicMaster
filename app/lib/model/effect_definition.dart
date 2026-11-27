import '../l10n/lang.dart';
import 'effect_parameter.dart';

/// A single effect model and its parameters (e.g. "COMP 1").
class EffectDefinition {
  const EffectDefinition({
    required this.id,
    required this.name,
    required this.descriptionEn,
    this.descriptionPt = '',
    required this.params,
  });

  final int id;
  final String name;
  final String descriptionEn;

  /// Brazilian Portuguese; empty when the data has no translation.
  final String descriptionPt;

  /// The description in the app language ([appLang]), English when the
  /// Portuguese text is missing.
  String get description => appLang == Lang.pt && descriptionPt.isNotEmpty
      ? descriptionPt
      : descriptionEn;
  final List<EffectParameter> params;

  /// The knobs the pedal's firmware ([isCfw]) has.
  List<EffectParameter> paramsFor({required bool isCfw}) => [
    for (final p in params)
      if (p.isShownOn(isCfw: isCfw)) p,
  ];

  factory EffectDefinition.fromJson(int id, Map<String, dynamic> json) =>
      EffectDefinition(
        id: id,
        name: json['name'] as String,
        descriptionEn: (json['descriptionEn'] as String?) ?? '',
        descriptionPt: (json['descriptionPt'] as String?) ?? '',
        params: ((json['alg'] as List?) ?? const [])
            .map((e) => EffectParameter.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
