/// One module's scene data on a CFW pedal (register 0x33). A preset has two
/// scenes, SC1 and SC2, on top of its BASE values: per scene, a module can
/// override knob values ([sc1] / [sc2], algId -> value) and its on/off state
/// ([sc1On] / [sc2On]; null = follow BASE).
class SceneRecord {
  const SceneRecord({
    required this.module,
    this.sc1On,
    this.sc2On,
    this.sc1 = const {},
    this.sc2 = const {},
  });

  /// Physical module id (0 NR … 8 RVB).
  final int module;
  final bool? sc1On;
  final bool? sc2On;
  final Map<int, double> sc1;
  final Map<int, double> sc2;

  /// The values of [scene] (1 or 2).
  Map<int, double> values(int scene) => scene == 2 ? sc2 : sc1;

  /// The on/off override of [scene] (1 or 2).
  bool? isOn(int scene) => scene == 2 ? sc2On : sc1On;

  SceneRecord withValue(int scene, int algId, double value) => scene == 2
      ? _copy(sc2: {...sc2, algId: value})
      : _copy(sc1: {...sc1, algId: value});

  SceneRecord withOn(int scene, bool? isOn) => scene == 2
      ? SceneRecord(
          module: module,
          sc1On: sc1On,
          sc2On: isOn,
          sc1: sc1,
          sc2: sc2,
        )
      : SceneRecord(
          module: module,
          sc1On: isOn,
          sc2On: sc2On,
          sc1: sc1,
          sc2: sc2,
        );

  SceneRecord _copy({Map<int, double>? sc1, Map<int, double>? sc2}) =>
      SceneRecord(
        module: module,
        sc1On: sc1On,
        sc2On: sc2On,
        sc1: sc1 ?? this.sc1,
        sc2: sc2 ?? this.sc2,
      );
}
