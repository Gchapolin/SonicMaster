/// The effect models the community custom firmware adds to the Pocket Master:
/// 6 delays and 5 reverbs (assets/data/cfw_fx_models.json) and 4 EQs
/// (assets/data/cfw_eq_models.json; the module EQ takes the same models as
/// the Global EQ). Data shipped by the Sonicake CFW app (MIT).
library;

import 'command_library.dart';
import 'effect_definition.dart';
import 'effect_library.dart';
import 'effect_parameter.dart';
import 'widget_type.dart';

/// Every CFW model's effect id: offered only on a CFW pedal.
const cfwModelIds = {
  504, 505, 506, 507, // EQ
  751, 752, 753, 754, 755, 756, // DLY
  851, 852, 853, 854, 855, // RVB
};

/// The module EQ (the CFW EQ models carry no block of their own).
const _eqModule = 5;

class CfwModel {
  const CfwModel({
    required this.module,
    required this.effectId,
    required this.def,
  });

  /// Physical module id (5 EQ, 7 DLY, 8 RVB).
  final int module;

  /// The pedal's 32-bit effect id, sent by the select frame.
  final int effectId;
  final EffectDefinition def;
}

List<CfwModel> parseCfwModels(
  Map<String, dynamic> fxJson,
  Map<String, dynamic> eqJson,
) => [
  for (final (json, module) in [(fxJson, null), (eqJson, _eqModule)])
    for (final m in (json['models'] as List).cast<Map<String, dynamic>>())
      // Entries with stockExtraParams describe the stock models, not new ones.
      if (m['fxId'] is int)
        CfwModel(
          module: module ?? m['block'] as int,
          effectId: int.parse(
            (m['effectId'] as String).substring(2),
            radix: 16,
          ),
          def: EffectDefinition(
            id: m['fxId'] as int,
            name: m['name'] as String,
            descriptionEn: (m['descriptionEn'] as String?) ?? '',
            params: [
              for (final p
                  in (m['params'] as List).cast<Map<String, dynamic>>())
                _param(p, module == null ? _delaySync(fxJson, m) : null),
            ],
          ),
        ),
];

/// The CFW delays' sync cell (data `tempo094.cfwDelaySync`, CFW 0.9.4 on):
/// its slot and its options by value; null for the other blocks.
({int slot, List<String> options})? _delaySync(
  Map<String, dynamic> fxJson,
  Map<String, dynamic> model,
) {
  final sync = (fxJson['tempo094'] as Map?)?['cfwDelaySync'] as Map?;

  if (model['block'] != 7 || sync == null) return null;

  final values = (sync['values'] as Map).cast<String, String>();

  return (
    slot: sync['slot'] as int,
    options: [for (var i = 0; i < values.length; i++) values['$i']!],
  );
}

/// As the CFW app converts them: on/off kinds are toggles, the rest knobs;
/// the slot-7 "Trail" is named "Trails", as in its preset files, and an "off"
/// kind reads Off at 0. On a delay, [sync] makes that slot the
/// Off/Trail/Sync/Both list and Time a note division while its Sync bit (2)
/// is set.
EffectParameter _param(
  Map<String, dynamic> p,
  ({int slot, List<String> options})? sync, {
  bool? onlyOnCfw,
}) {
  final kind = p['kind'] as String?;
  final algId = p['algId'] as int;
  final name = p['name'] as String;
  final isSyncCell = sync != null && algId == sync.slot;

  return EffectParameter(
    name: name == 'Trail' && algId == 7 ? 'Trails' : name,
    algId: algId,
    defaultValue: p['defaultValue'] as num,
    widgetType: isSyncCell
        ? WidgetType.select
        : kind == 'onoff' || kind == 'stereo'
        ? WidgetType.toggle
        : WidgetType.knob,
    options: isSyncCell ? sync.options : null,
    syncToggleAlgId: sync != null && kind == 'ms' ? sync.slot : null,
    syncMask: 2,
    min: isSyncCell ? 0 : p['min'] as num?,
    max: isSyncCell ? sync.options.length - 1 : p['max'] as num?,
    step: p['step'] as num?,
    unit: kind == 'ms' ? 'ms' : null,
    texts: {
      if (kind == 'off') '0': 'Off',
      for (final e in ((p['texts'] as Map?) ?? const {}).entries)
        e.key as String: e.value as String,
    },
    onlyOnCfw: onlyOnCfw,
  );
}

/// The stock delays whose Trail toggle (slot 4) the CFW replaces with its
/// slot-7 Trails (the CFW app's `bqd`, CFW 0.9.4 on).
const _stockTrail4Delays = {701, 702, 703, 704, 705, 706, 707, 709};

/// Sweep: on the CFW, slots 5 / 6 are its S-Sync / D-Sync toggles, so it
/// takes no Tone / Duck there (the CFW app's `bqd`), only Trails.
const _sweep = 708;

/// Adds the knobs the CFW gives the stock delays and reverbs (cfw_fx_models
/// `stockExtraParams`: DLY Tone / Duck / Trails at 5 / 6 / 7, RVB High Cut /
/// Low Cut / Trails at 3 / 6 / 7) to [effects], shown only on a CFW pedal. A
/// stock knob in a slot the CFW takes over is kept to the stock firmware, as
/// the CFW app's `Qz` drops it.
void addCfwStockExtras(EffectLibrary effects, Map<String, dynamic> fxJson) {
  for (final m in (fxJson['models'] as List).cast<Map<String, dynamic>>()) {
    if (m['stockExtraParams'] is! List) continue;

    final extras = [
      for (final p
          in (m['stockExtraParams'] as List).cast<Map<String, dynamic>>())
        _param(p, null, onlyOnCfw: true),
    ];

    for (final fxId in (m['stockFxIds'] as List).cast<int>()) {
      final def = effects.byId(fxId);

      if (def == null) continue;

      final added = [
        for (final p in extras)
          if (fxId != _sweep || p.algId == 7) p,
      ];
      final taken = {for (final p in added) p.algId};

      effects.effects[fxId] = EffectDefinition(
        id: def.id,
        name: def.name,
        descriptionEn: def.descriptionEn,
        params: [
          for (final p in def.params)
            taken.contains(p.algId) ||
                    (p.algId == 4 && _stockTrail4Delays.contains(fxId))
                ? p.stockOnly
                : p,
          ...added,
        ],
      );
    }
  }
}

/// Adds [models] to [effects] and their select frames to [commands].
void addCfwModels(
  EffectLibrary effects,
  CommandLibrary commands,
  List<CfwModel> models,
) {
  for (final m in models) {
    effects.effects[m.def.id] = m.def;
    (commands.effectTypes[m.module] ??= {})[m.def.id] =
        CommandLibrary.effectTypeFrame(m.module, m.effectId);
  }
}
