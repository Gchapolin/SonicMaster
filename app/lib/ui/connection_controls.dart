import 'package:flutter/material.dart'; // Icons glyph font only
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/common_text.dart';
import '../l10n/connection_text.dart';
import '../state/device_providers.dart';
import '../state/reconnect.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'device_dialog.dart';
import 'sonic_controls.dart';

/// The Connect action for the current state: opens the device picker and
/// connects to the pick. Null when there is nothing to connect: a pedal is
/// connected, or an auto-reconnect retry is in flight. It never disconnects,
/// so a stray tap can't drop a live pedal (reconnecting needs the picker
/// again, and a fresh Bluetooth chooser on the web). Shared by the well's
/// Connect button and the compact title bar's whole-well target.
VoidCallback? connectAction(BuildContext context, WidgetRef ref) {
  if (ref.watch(connectionStateProvider) || ref.watch(reconnectingProvider)) {
    return null;
  }

  return () => pickAndConnect(context, ref);
}

/// The regular title bar's device status target: while connected, a small
/// menu naming the pedal with Desconectar; otherwise [connectAction].
VoidCallback? deviceStatusAction(BuildContext context, WidgetRef ref) {
  if (!ref.watch(connectionStateProvider)) return connectAction(context, ref);

  return () => showSonicDialog<void>(
    context: context,
    builder: (dialogContext) => SonicDialog(
      maxWidth: 340,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Text(
            ref.read(connectedDeviceNameProvider) ??
                ConnectionText.current.connected,
            style: AppText.uiStrong.copyWith(color: Palette.onSurface),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: .end,
            spacing: 8,
            children: [
              SonicButton(
                label: CommonText.current.close,
                height: 40,
                minWidth: 0,
                onPressed: () => Navigator.pop(dialogContext),
              ),
              SonicButton(
                label: ConnectionText.current.disconnect,
                height: 40,
                minWidth: 0,
                isAccent: true,
                onPressed: () {
                  Navigator.pop(dialogContext);
                  disconnectDevice(ref);
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// The top bar's device well: the device name (when connected) or
/// "Disconnected", a colour-coded status dot, and a compact Connect/Disconnect
/// push-button to its right. The USB/BLE picker lives inside [pickAndConnect].
class ConnectionControls extends ConsumerWidget {
  const ConnectionControls({
    super.key,
    this.hasStatusLabel = true,
    this.isStatusOnly = false,
  });

  /// The regular title bar's prototype status: a status dot and the device
  /// name (Inter 13), no Disconnect button (the bar's [deviceStatusAction]
  /// offers it). Connect stays while disconnected.
  final bool isStatusOnly;

  /// Whether the device name / "Disconnected" label leads the well. The
  /// compact title bar drops it (and its gap): the green glyph or the red dot
  /// already tells connected from not, and the bar has no room for a name.
  final bool hasStatusLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(connectionStateProvider);
    final deviceName = ref.watch(connectedDeviceNameProvider);
    final transport = ref.watch(transportKindProvider);

    final statusLabel = isConnected
        ? (deviceName ?? ConnectionText.current.connected)
        : ConnectionText.current.disconnected;

    if (isStatusOnly) {
      return Row(
        mainAxisSize: .min,
        spacing: 8,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: .circle,
              color: isConnected ? Palette.ok : Palette.ledDisconnected,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              statusLabel,
              maxLines: 1,
              overflow: .ellipsis,
              style: AppText.ui.copyWith(
                fontWeight: FontWeight.w400,
                color: Palette.onSurfaceVariant,
              ),
            ),
          ),
          if (!isConnected)
            SonicButton(
              label: ConnectionText.current.connect,
              height: 26,
              minWidth: 0,
              isAccent: true,
              onPressed: connectAction(context, ref),
            ),
        ],
      );
    }

    return Row(
      mainAxisSize: .min,
      children: [
        if (hasStatusLabel) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              statusLabel,
              maxLines: 1,
              overflow: .ellipsis,
              style: AppText.connectionLabel,
            ),
          ),
          const SizedBox(width: 8),
        ],
        // Connected: a green interface glyph (USB fork / Bluetooth "B").
        // Disconnected: a red dot.
        if (isConnected)
          Icon(
            transport == .ble ? Icons.bluetooth : Icons.usb,
            size: 15,
            color: Palette.ledConnected,
          )
        else
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: .circle,
              color: Palette.ledDisconnected,
            ),
          ),
        const SizedBox(width: 10),
        // Compact Connect / Disconnect, right of the dot.
        SonicButton(
          label: isConnected
              ? ConnectionText.current.disconnect
              : ConnectionText.current.connect,
          height: 26,
          minWidth: 0,
          isAccent: !isConnected,
          onPressed: isConnected
              ? () => disconnectDevice(ref)
              : connectAction(context, ref),
        ),
      ],
    );
  }
}
