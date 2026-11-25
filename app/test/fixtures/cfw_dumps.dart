/// Real `12 2A` (CFW settings) replies captured from a Pocket Master running
/// CFW 1.0.2 over Bluetooth on 2026-11-24 (docs/cfw-protocol/capture-notes.md).
library;

const _payload =
    '0102020a00010403040605070301020e0300020e0302000000000000000000000000000000'
    '00070f080f0f0f0c0f010e000c00010003000206040003000100040000000600000100000'
    '201010000010200000105000001060000010700000207000000040c0f000900000000';

/// Theme Synthwave (3), brightness 100, Direct Monitor on, USB Rec WET, pedal
/// mode PRESET, scene SC2, every MIDI key 0.
const cfwSettingsOriginal = '8080f00306000100000306${_payload}f7';

/// Same, brightness 90.
final cfwSettingsBrightness90 =
    '8080f0020f000100000306'
    '${_payload.replaceFirst('000c00010003000206040003', '000c000100030002050a0003')}f7';

/// Same, theme Default (0).
final cfwSettingsThemeDefault =
    '8080f00f0f000100000306'
    '${_payload.replaceFirst('000c00010003000206040003', '000c00010000000206040003')}f7';

/// Same, scene SC1.
final cfwSettingsSceneSc1 =
    '8080f00408000100000306'
    '${_payload.replaceFirst('0100000201010000', '0100000101010000')}f7';
