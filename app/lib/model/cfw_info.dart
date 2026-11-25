/// What a pedal running the community custom firmware (CFW) reports in its
/// `12 2A` settings block: the firmware version, its capability bits and the
/// CFW settings as `key -> value` (keys documented in
/// docs/cfw-protocol/capture-notes.md). Null in the app means stock firmware.
class CfwInfo {
  const CfwInfo({
    required this.version,
    required this.capabilities,
    required this.settings,
  });

  static const themeKey = 0x01;
  static const brightnessKey = 0x02;
  static const directMonitorKey = 0x03;
  static const usbRecKey = 0x04;
  static const pedalModeKey = 0x06;
  static const sceneKey = 0x10;
  static const sameAgainKey = 0x11;
  static const midiChannelKey = 0x12;
  static const midiMapKey = 0x15;
  static const tempoScopeKey = 0x16;
  static const customMapOptionsKey = 0x17;
  static const drumSyncKey = 0x27;

  /// MIDI map value of the user's own (Custom) map.
  static const customMap = 1;

  /// e.g. `CFW1.0.2`.
  final String version;

  /// Capability bits (little-endian u32 from the block).
  final int capabilities;

  /// Every `key -> value` pair the pedal sent.
  final Map<int, int> settings;

  /// 0 Default, 1 Amber CRT, 2 Tube Amp, 3 Synthwave, 4 Stage Hi-Contrast,
  /// 5 Game Boy.
  int get theme => settings[themeKey] ?? 0;

  /// Screen brightness, 10..100 %.
  int get brightness => settings[brightnessKey] ?? 100;

  bool get directMonitor => (settings[directMonitorKey] ?? 1) != 0;

  /// 0 WET, 1 DRY DI, 2 DI L + WET R.
  int get usbRec => settings[usbRecKey] ?? 0;

  /// 0 PRESET, 1 STOMP, 2 SCENE.
  int get pedalMode => settings[pedalModeKey] ?? 0;

  /// 0 Stock, 1 Custom, 2 Generic MIDI, 3 Chocolate.
  int get midiMap => settings[midiMapKey] ?? 0;

  /// 0 all channels, 1..16 one channel.
  int get midiChannel => settings[midiChannelKey] ?? 0;

  /// What a MIDI message for the already-loaded preset does: 0 off, 1 cycle
  /// (BASE -> SC1 -> SC2), 2 back to the previous preset.
  int get sameAgain => settings[sameAgainKey] ?? 0;

  /// 0 per preset, 1 global.
  int get tempoScope => settings[tempoScopeKey] ?? 0;

  bool get drumSync => (settings[drumSyncKey] ?? 0) != 0;

  /// Custom-map options bitfield: bit0 first PC is PC 1 (else PC 0), bit1
  /// level CCs span 0..127 (else 0..100).
  int get customMapOptions => settings[customMapOptionsKey] ?? 0;

  CfwInfo copyWithSetting(int key, int value) => CfwInfo(
    version: version,
    capabilities: capabilities,
    settings: {...settings, key: value},
  );
}
