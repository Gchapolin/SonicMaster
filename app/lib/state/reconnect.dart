import 'dart:async'; // unawaited

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device/device_model.dart';
import '../device/transport.dart';
import '../l10n/connection_text.dart';
import 'cfw_providers.dart';
import 'connection_prefs.dart';
import 'data_providers.dart';
import 'device_providers.dart';
import 'preset_providers.dart';

/// The connect-time reads still in flight (names, CFW block, slot names,
/// scenes), kept so a test can await the real tail instead of sleeping.
@visibleForTesting
Future<void> pendingConnectReads = Future.value();

/// Open [target] on the current transport and, unless the transport changed
/// mid-await, mark the connection live, set [statusOnSuccess], and sync device
/// state. Returns true on success, false if the transport switched during the
/// connect (caller should bail — the switch already reset state + rebuilt the
/// service). Throws on a connect failure (caller decides retry/status).
Future<bool> connectAndSync(
  WidgetRef ref, {
  String? target,
  required String statusOnSuccess,
}) async {
  final kind = ref.read(transportKindProvider);

  // A new connection may be another pedal: drop the last one's CFW state so
  // no CFW control or DSP reading outlives it.
  clearCfwState(ref);
  await ref.read(deviceServiceProvider).connect(target: target);

  if (ref.read(transportKindProvider) != kind) return false;

  ref.read(connectionStateProvider.notifier).state = true;

  final String resolvedName;

  if (kind == .ble) {
    final name = target ?? 'Smart Box BLE';

    ref.read(lastBleTargetProvider.notifier).state = name;
    resolvedName = name;
  } else {
    // The picked target is already the real MIDI device name (the picker lists
    // full device names), so use it directly.
    resolvedName = target ?? 'Smart Box';
  }

  ref.read(connectedDeviceNameProvider.notifier).state = resolvedName;

  // Identify the model from the connection name so the pickers can gate on it.
  // Fails open to unknown (full effect set) if the data isn't loaded yet.
  final caps = ref.read(dataAssetsProvider).valueOrNull?.capabilities;

  ref.read(detectedDeviceModelProvider.notifier).state =
      caps?.detect(name: resolvedName, kind: kind) ?? DeviceModel.unknown;

  ref.read(presetLoadStatusProvider.notifier).state = statusOnSuccess;
  // Enter the pedal's edit session (020300) first, exactly as the official tool
  // does on connect — required for it to commit User-IR writes to flash. Skipped
  // if a load is already in flight (matches the other connect-time reads, which
  // self-skip on the loading flag).
  if (!ref.read(presetLoadingProvider)) {
    await ref.read(deviceServiceProvider).enterEditSession();
  }

  await refreshGlobalSettings(ref);
  // Names first, then the community custom firmware (CFW) settings block:
  // stock firmware never answers it, so its timeout must not hold the IO gate
  // ahead of the names.
  unawaited(pendingConnectReads = refreshNamesThenCfw(ref));

  return true;
}

/// Connects to [target] over the current transport and, on success, persists
/// the intent for next-launch auto-connect. A prefs-write failure is swallowed:
/// a persistence error must not report the live connection as failed. Used by
/// the Connect button after the device picker returns a target.
Future<void> connectAndPersist(WidgetRef ref, {String? target}) async {
  // A real connection ends the demo.
  ref.read(demoModeProvider.notifier).state = false;

  final kind = ref.read(transportKindProvider);

  try {
    // false => the user flipped transport during connect; bail (nothing was
    // marked live, so don't arm a stale profile).
    if (!await connectAndSync(
      ref,
      target: target,
      statusOnSuccess: ConnectionText.current.statusConnected,
    )) {
      return;
    }
  } catch (e) {
    ref.read(presetLoadStatusProvider.notifier).state = ConnectionText.current
        .connectFailed(e);

    return;
  }

  try {
    await ref.read(connectionPrefsProvider).saveProfile(kind, target);
  } catch (_) {
    // best-effort persistence
  }
}

/// Reacts to a BLE connection-drop event and auto-reconnects to the last device
/// (bounded, backoff). The plugin only emits a drop (`false`) for an unexpected
/// disconnect — a user disconnect / transport switch / reconnect aborts the
/// monitor first — so this always attempts reconnection when BLE.
Future<void> handleConnectionDrop(WidgetRef ref) async {
  ref.read(connectionStateProvider.notifier).state = false;
  ref.read(detectedDeviceModelProvider.notifier).state = .unknown;
  final target = ref.read(lastBleTargetProvider);

  if (ref.read(transportKindProvider) != .ble || target == null) {
    ref.read(presetLoadStatusProvider.notifier).state =
        ConnectionText.current.statusDisconnected;

    return;
  }

  if (ref.read(reconnectingProvider)) return; // a retry loop is already running

  ref.read(reconnectingProvider.notifier).state = true;

  try {
    Object? lastError;

    for (var attempt = 1; attempt <= 3; attempt++) {
      // Bail if the user switched transport or reconnected another way.
      if (ref.read(transportKindProvider) != .ble) return;

      if (ref.read(connectionStateProvider)) return;

      ref.read(presetLoadStatusProvider.notifier).state = ConnectionText.current
          .reconnecting(attempt);
      await Future<void>.delayed(Duration(milliseconds: 400 * attempt));

      if (ref.read(transportKindProvider) != .ble) return;

      try {
        // Re-reads the service each iteration (rebuilt on transport switch). A
        // false return means the user switched transport mid-connect — bail
        // rather than mark a torn-down BLE service live.
        await connectAndSync(
          ref,
          target: target,
          statusOnSuccess: ConnectionText.current.statusReconnected,
        );

        return;
      } catch (e) {
        lastError = e;
      }
    }

    ref.read(presetLoadStatusProvider.notifier).state = ConnectionText.current
        .reconnectFailed(lastError);
  } finally {
    ref.read(reconnectingProvider.notifier).state = false;
  }
}

/// Provider-state effects of a user-initiated disconnect (no device I/O):
/// clears the BLE reconnect target so a resulting drop event won't
/// auto-reconnect (the `handleConnectionDrop` guard sees `target == null`),
/// and marks the UI disconnected. Extracted for unit-testing without a device.
void applyUserDisconnect(WidgetRef ref) {
  ref.read(lastBleTargetProvider.notifier).state = null;
  ref.read(connectionStateProvider.notifier).state = false;
  ref.read(detectedDeviceModelProvider.notifier).state = .unknown;
  ref.read(presetLoadStatusProvider.notifier).state =
      ConnectionText.current.statusDisconnected;
}

/// State effects of a DETECTED USB connection loss (cable pull, power-off, port
/// vanished): mark disconnected, reset the model + shown name, and prompt a
/// manual reconnect — USB has no auto-reconnect. A distinct status from a user
/// disconnect so the UI reads as an unexpected loss.
void handleUsbConnectionLost(WidgetRef ref) {
  ref.read(connectionStateProvider.notifier).state = false;
  ref.read(detectedDeviceModelProvider.notifier).state = .unknown;
  ref.read(connectedDeviceNameProvider.notifier).state = null;
  ref.read(presetLoadStatusProvider.notifier).state =
      ConnectionText.current.connectionLost;
}

/// Liveness check for the heartbeat: if the transport is USB and marked
/// connected but its port is no longer enumerable, flip to disconnected. Acts
/// only on a DEFINITIVE absence (enumeration succeeded, port gone) so a transient
/// enumeration failure can't false-trip a disconnect; re-checks the guards after
/// the async gap. [probe] is injectable for tests (defaults to the real USB port
/// enumeration).
Future<void> checkUsbLiveness(
  WidgetRef ref, {
  Future<bool?> Function(String match) probe = usbInputPortPresent,
}) async {
  if (ref.read(demoModeProvider) ||
      ref.read(transportKindProvider) != .usb ||
      !ref.read(connectionStateProvider)) {
    return;
  }

  final name = ref.read(connectedDeviceNameProvider);

  if (name == null) return;

  final present = await probe(name);

  if (present == false &&
      ref.read(transportKindProvider) == .usb &&
      ref.read(connectionStateProvider)) {
    handleUsbConnectionLost(ref);
  }
}

/// The connection heartbeat (driven by a periodic timer while connected): detect
/// a silent USB drop, then poll the pedal for on-device global-settings changes.
/// Skips the poll if the liveness check just disconnected.
Future<void> deviceHeartbeat(WidgetRef ref) async {
  if (!ref.read(connectionStateProvider)) return;

  await checkUsbLiveness(ref);

  if (ref.read(connectionStateProvider)) await pollGlobalSettings(ref);
  if (ref.read(connectionStateProvider)) await pollCfwStatus(ref);
}

/// Startup auto-connect: if the user's last intent was "connected", restore the
/// transport (+ BLE target) and reconnect. On failure, BLE retries via the
/// existing backoff ([handleConnectionDrop]); USB reports a status and stays
/// disconnected. No-op when the user disconnected manually last session.
Future<void> autoConnectOnStartup(WidgetRef ref) async {
  final profile = ref.read(connectionPrefsProvider).autoConnectProfile;

  if (profile == null) return;

  ref.read(transportKindProvider.notifier).state = profile.transport;

  if (profile.transport == .ble) {
    ref.read(lastBleTargetProvider.notifier).state = profile.bleName;
  }

  // Web MIDI / Web Bluetooth (re)connect requires a user gesture, so a silent
  // startup reconnect isn't possible on web — the last transport is pre-selected
  // above and the user taps Connect. Native reconnects silently.
  if (kIsWeb) {
    ref.read(presetLoadStatusProvider.notifier).state =
        ConnectionText.current.tapConnectToResume;

    return;
  }

  try {
    await connectAndSync(
      ref,
      target: profile.bleName,
      statusOnSuccess: ConnectionText.current.statusConnected,
    );
  } catch (_) {
    if (profile.transport == .ble) {
      await handleConnectionDrop(ref); // reuse the 3-attempt BLE backoff
    } else {
      ref.read(presetLoadStatusProvider.notifier).state =
          ConnectionText.current.autoConnectFailed;
    }
  }
}

/// User-initiated disconnect: disarm auto-connect (best-effort), apply the
/// state effects, then close the transport — a prefs-write failure must not
/// leave the transport open.
Future<void> disconnectDevice(WidgetRef ref) async {
  applyUserDisconnect(ref);

  try {
    await ref.read(connectionPrefsProvider).clearAutoConnect();
  } catch (_) {
    // best-effort persistence; still close the transport below
  }

  await ref.read(deviceServiceProvider).disconnect();
  ref.read(demoModeProvider.notifier).state = false;
}

/// The name the virtual pedal connects under (it classifies as a Pocket
/// Master).
const demoDeviceName = 'Pocket Master (demo)';

/// Starts the demo: connects to a virtual CFW Pocket Master. Nothing is sent
/// to a device and nothing is persisted, so the demo never auto-reconnects.
Future<void> startDemo(WidgetRef ref) async {
  ref.read(transportKindProvider.notifier).state = .usb;
  ref.read(demoModeProvider.notifier).state = true;
  await connectAndSync(ref, target: demoDeviceName, statusOnSuccess: 'demo');
}
