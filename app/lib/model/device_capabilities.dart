import '../device/device_model.dart';
import '../device/transport.dart';
import 'command_library.dart';

/// User IR slots 6-10 (422-426) and User Profile slots 6-10 (906-910): they
/// exist only on the community custom firmware, on every model.
const cfwOnlySlotIds = {422, 423, 424, 425, 426, 906, 907, 908, 909, 910};

/// Per-device effect/amp capability manifest, loaded from
/// `device_capabilities.json`. Holds, per model: the connection-name substrings
/// used to identify it, a display name, and (for subset models only) the set of
/// effect ids it supports per module. Smart Box and any unknown device carry no
/// effect restriction — they pass through the full library (fail-open).
class DeviceCapabilities {
  const DeviceCapabilities._(
    this._effects,
    this._matchers,
    this._displayNames,
    this._cfwEffects,
  );

  /// model -> (moduleId -> effect ids the community custom firmware (CFW)
  /// adds to that model).
  final Map<DeviceModel, Map<int, Set<int>>> _cfwEffects;

  /// model -> (moduleId -> allowed effect ids). A model absent here (Smart Box /
  /// unknown) is unrestricted; a module absent for a present model is
  /// unrestricted for that module.
  final Map<DeviceModel, Map<int, Set<int>>> _effects;
  final Map<DeviceModel, ({List<String> usb, List<String> ble})> _matchers;
  final Map<DeviceModel, String> _displayNames;

  factory DeviceCapabilities.fromJson(Map<String, dynamic> json) {
    final models = json['models'] as Map<String, dynamic>;
    final effects = <DeviceModel, Map<int, Set<int>>>{};
    final matchers = <DeviceModel, ({List<String> usb, List<String> ble})>{};
    final displayNames = <DeviceModel, String>{};
    final cfwEffects = <DeviceModel, Map<int, Set<int>>>{};

    for (final entry in models.entries) {
      final model = _modelFromKey(entry.key);

      if (model == null) continue;

      final m = entry.value as Map<String, dynamic>;
      final match = m['match'] as Map<String, dynamic>;
      final eff = m['effects'];

      displayNames[model] = m['displayName'] as String;
      matchers[model] = (usb: _lower(match['usb']), ble: _lower(match['ble']));

      final cfw = m['cfwModels'];

      if (cfw is Map<String, dynamic>) {
        cfwEffects[model] = {
          for (final e in cfw.entries)
            int.parse(e.key): {for (final id in e.value as List) id as int},
        };
      }

      if (eff is Map<String, dynamic>) {
        effects[model] = {
          for (final e in eff.entries)
            int.parse(e.key): {for (final id in e.value as List) id as int},
        };
      }
    }

    return DeviceCapabilities._(effects, matchers, displayNames, cfwEffects);
  }

  /// Classifies a connected device (by its transport name) into a [DeviceModel].
  /// Case-insensitive substring match; first model whose list hits wins. Fails
  /// open to [DeviceModel.unknown] when the name is null or unrecognized.
  ///
  /// This is the pluggable detection seam: a future SysEx-identity or VID:PID
  /// path can set the model provider directly and bypass this entirely.
  DeviceModel detect({required String? name, required TransportKind kind}) {
    if (name == null) return .unknown;

    final needle = name.toLowerCase();

    for (final entry in _matchers.entries) {
      final subs = kind == .usb ? entry.value.usb : entry.value.ble;

      if (subs.any(needle.contains)) return entry.key;
    }

    return .unknown;
  }

  String displayName(DeviceModel model) =>
      _displayNames[model] ??
      switch (model) {
        .pocketMaster => 'Pocket Master',
        .smartBox => 'Smart Box',
        .unknown => 'Unknown device',
      };

  /// The effect ids [model] can actually select in [moduleId]: the command
  /// library's pickable ids intersected with the model's allow-list, preserving
  /// the command library's sort order. Pass-through (the full pickable set) for
  /// Smart Box, unknown, or any module the model doesn't restrict.
  List<int> availableEffectIds(
    CommandLibrary commands,
    DeviceModel model,
    int moduleId, {
    bool isCfw = false,
  }) {
    final all = [
      for (final id in commands.effectIdsFor(moduleId))
        if (isCfw || !cfwOnlySlotIds.contains(id)) id,
    ];
    final allowed = _effects[model]?[moduleId];

    if (allowed == null) return all;

    // On the community custom firmware the model also runs the ids listed
    // under `cfwModels` (the Smart Box effects the CFW ports to it).
    final extra = isCfw ? (_cfwEffects[model] ?? const {})[moduleId] : null;

    return all
        .where(
          (id) =>
              allowed.contains(id) ||
              (extra?.contains(id) ?? false) ||
              cfwOnlySlotIds.contains(id),
        )
        .toList();
  }

  static DeviceModel? _modelFromKey(String key) => switch (key) {
    'pocketMaster' => .pocketMaster,
    'smartBox' => .smartBox,
    _ => null,
  };

  static List<String> _lower(dynamic list) => [
    for (final s in list as List) (s as String).toLowerCase(),
  ];
}
