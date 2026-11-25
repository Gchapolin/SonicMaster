/// The CFW models as the connected firmware has them. The CFW app fits its
/// model data to the pedal (main.dart.js, `AW.kC` with flags `jw` built from
/// the capabilities): on a Pocket Master whose capability word carries bit 31
/// (`sbModels097`, CFW 0.9.7 on) Swell Delay's slot 6 is Sens (`B.NM`), not
/// the data's Duck; a NAM build (extra capability bit 4096, or "-NAM" in the
/// version) never has it. The flags' other uses (display order, the stock
/// models' extra knobs) are Smart Box only.
library;

import 'cfw_info.dart';
import 'effect_definition.dart';
import 'effect_library.dart';
import 'effect_parameter.dart';
import 'widget_type.dart';

const swellDelayId = 755;

const _sens = EffectParameter(
  name: 'Sens',
  algId: 6,
  defaultValue: 0,
  widgetType: WidgetType.knob,
  min: -50,
  max: 50,
  step: 1,
);

bool _hasSwellSens(CfwInfo? info) =>
    info != null &&
    info.capabilities & 0x80000000 != 0 &&
    info.extraCapabilities & 0x1000 == 0 &&
    !info.version.toUpperCase().contains('-NAM');

/// Swell Delay as the data has it, per library.
final _swellData = Expando<EffectDefinition>();

/// Sets Swell Delay in [effects] to the variant of the pedal [info] describes
/// (null: stock firmware or no pedal, the data's model). Every reader of the
/// library (module editor, preset import / export, knob frames) then sees it.
void fitCfwModels(EffectLibrary effects, CfwInfo? info) {
  final data = _swellData[effects] ??= effects.effects[swellDelayId];

  if (data == null) return;

  effects.effects[swellDelayId] = _hasSwellSens(info)
      ? EffectDefinition(
          id: data.id,
          name: data.name,
          descriptionEn: data.descriptionEn,
          params: [for (final p in data.params) p.algId == 6 ? _sens : p],
        )
      : data;
}
