import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/cfw_eq_models.dart';
import '../model/cfw_global_eq.dart';

import '../model/cfw_info.dart';
import '../protocol/cfw_geq_codec.dart';
import '../protocol/cfw_setting_writer.dart';
import '../protocol/cfw_settings_decoder.dart';
import 'device_providers.dart';
import 'preset_providers.dart';

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

/// Reads the DSP load into [dspLoadProvider]; a missed read clears it, so the
/// chip disappears instead of freezing at a stale value.
Future<void> refreshDspLoad(WidgetRef ref) async {
  final service = ref.read(deviceServiceProvider);
  final dsp = ref.read(dspLoadProvider.notifier);
  final load = await service.requestDspLoad();

  if (dsp.mounted) dsp.state = load;
}

/// Drops the CFW state, at the start of every connection.
void clearCfwState(WidgetRef ref) {
  ref.read(globalEqProvider.notifier).state = null;
  ref.read(cfwInfoProvider.notifier).state = null;
  ref.read(dspLoadProvider.notifier).state = null;
}

/// The connect-time reads, in order: preset names first, then the CFW block.
/// On stock firmware the CFW read only times out, so it goes last and never
/// delays the names on the serialized IO gate.
Future<void> refreshNamesThenCfw(WidgetRef ref) async {
  await refreshNames(ref);
  await refreshCfwInfo(ref);
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

bool _statusPollInFlight = false;

/// The CFW part of the connection heartbeat: on a CFW pedal, reads the DSP
/// load. Like pollGlobalSettings it stays quiet while a load or an upload
/// holds the pedal ([presetLoadingProvider]), never stacks a second read on
/// the serialized IO gate behind a stalled one, and swallows a send error
/// (the chip then disappears). A no-op on stock firmware.
Future<void> pollCfwStatus(WidgetRef ref) async {
  if (_statusPollInFlight ||
      ref.read(cfwInfoProvider) == null ||
      ref.read(presetLoadingProvider)) {
    return;
  }

  final dsp = ref.read(dspLoadProvider.notifier);

  _statusPollInFlight = true;
  try {
    await refreshDspLoad(ref);
  } catch (_) {
    if (dsp.mounted) dsp.state = null;
  } finally {
    _statusPollInFlight = false;
  }
}

/// The CFW Global EQ models (bundled data).
final cfwEqModelsProvider = FutureProvider<List<CfwEqModel>>(
  (_) async => parseCfwEqModels(
    jsonDecode(await rootBundle.loadString('assets/data/cfw_eq_models.json'))
        as Map<String, dynamic>,
  ),
);

/// The pedal's Global EQ block; null until read (or on stock firmware).
final globalEqProvider = StateProvider<CfwGlobalEq?>((_) => null);

/// Reads the Global EQ block into [globalEqProvider]; a missed read keeps the
/// last value. A no-op on stock firmware.
Future<void> refreshGlobalEq(WidgetRef ref) async {
  if (ref.read(cfwInfoProvider) == null) return;

  final service = ref.read(deviceServiceProvider);
  final eq = ref.read(globalEqProvider.notifier);

  try {
    final hex = await service.requestGlobalEq();
    final decoded = hex == null ? null : decodeGlobalEqFrame(hex);

    if (decoded != null && eq.mounted) eq.state = decoded;
  } catch (_) {
    // Best-effort: the section keeps what it had.
  }
}

/// Sets the Global EQ: shows it at once and sends the whole block.
Future<void> setGlobalEq(WidgetRef ref, CfwGlobalEq value) async {
  final service = ref.read(deviceServiceProvider);

  ref.read(globalEqProvider.notifier).state = value;
  try {
    await service.sendAndAwaitAck(buildGlobalEqFrame(value));
  } catch (_) {
    // A failed send leaves the shown value; the next read corrects it.
  }
}
