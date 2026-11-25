import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/cfw_info.dart';
import '../protocol/cfw_setting_writer.dart';
import '../protocol/cfw_settings_decoder.dart';
import 'device_providers.dart';

/// What the connected pedal's community custom firmware (CFW) reports; null
/// for stock firmware (it never answers the `12 2A` read). Re-read on every
/// connect, so a stock pedal after a CFW one reads back null. The UI shows CFW
/// controls only while connected.
final cfwInfoProvider = StateProvider<CfwInfo?>((_) => null);

/// The CFW's DSP load in percent, polled by the connection heartbeat; null
/// until read (or on stock firmware).
final dspLoadProvider = StateProvider<int?>((_) => null);

/// Reads the CFW settings block into [cfwInfoProvider]. Fired unawaited on
/// connect, so it takes what it needs from [ref] before the read and only
/// writes back if the state is still alive.
Future<void> refreshCfwInfo(
  WidgetRef ref, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final service = ref.read(deviceServiceProvider);
  final info = ref.read(cfwInfoProvider.notifier);
  final hex = await service.requestCfwSettings(timeout: timeout);

  if (info.mounted) {
    info.state = hex == null ? null : decodeCfwSettingsFrame(hex);
  }
}

/// Reads the DSP load into [dspLoadProvider] (kept as is on a missed read).
Future<void> refreshDspLoad(WidgetRef ref) async {
  final service = ref.read(deviceServiceProvider);
  final dsp = ref.read(dspLoadProvider.notifier);
  final load = await service.requestDspLoad();

  if (load != null && dsp.mounted) dsp.state = load;
}

/// Sets one CFW setting: shows it at once, then sends it and waits for the
/// pedal's ack. Brightness ([CfwInfo.brightnessKey]) goes through its own
/// frame, like the CFW app does.
Future<void> setCfwSetting(WidgetRef ref, int key, int value) async {
  final info = ref.read(cfwInfoProvider.notifier);
  final service = ref.read(deviceServiceProvider);
  final current = info.state;

  if (current == null) return;

  info.state = current.copyWithSetting(key, value);
  await service.sendAndAwaitAck(
    key == CfwInfo.brightnessKey
        ? CfwSettingWriter.brightness(value)
        : CfwSettingWriter.setting(key, value),
  );
}

/// The CFW part of the connection heartbeat: on a CFW pedal, reads the DSP
/// load; a no-op on stock firmware.
Future<void> pollCfwStatus(WidgetRef ref) async {
  if (ref.read(cfwInfoProvider) == null) return;

  await refreshDspLoad(ref);
}
