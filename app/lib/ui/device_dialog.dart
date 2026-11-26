import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart'; // Icons glyph font only
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../device/transport.dart';
import '../device/transport_factory.dart';
import '../device/web_capabilities.dart';
import '../l10n/common_text.dart';
import '../l10n/connection_text.dart';
import '../state/device_providers.dart';
import '../state/reconnect.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'sonic_controls.dart';

/// The shortest the picker's content (title, toggle, list area, actions) may
/// get before it scrolls as a whole: the pinned chrome (about 146 px in
/// Oswald) plus a 74-px list area. Only a transient case gets below it: a soft
/// keyboard still closing after Connect was tapped from a focused field.
const double _minPickerContentHeight = 220;

/// Connect target popped for a web BLE pick. The browser chooser returns the
/// actual device (the transport takes the first result), so this is only the
/// persisted/displayed label — the pedal's default BLE name.
const _webBleTarget = 'Smart Box BLE';

/// What the device picker says when the browser has no Web MIDI (with SysEx),
/// by the browser's OS: on web, [defaultTargetPlatform] follows the user agent
/// (iPadOS counts as iOS; Android in desktop-site mode counts as Linux).
String webMidiUnsupportedMessage(TargetPlatform platform) => switch (platform) {
  .android => ConnectionText.current.webMidiAndroid,
  .iOS => ConnectionText.current.iosCannotConnect,
  _ => ConnectionText.current.webMidiOther,
};

/// What the device picker says when the browser has no Web Bluetooth, by the
/// browser's OS. Only desktop Linux gets the flag hint: Chrome ships the API
/// switched off there.
String webBluetoothUnsupportedMessage(TargetPlatform platform) =>
    switch (platform) {
      .android => ConnectionText.current.webBluetoothAndroid,
      .iOS => ConnectionText.current.iosCannotConnect,
      .linux => ConnectionText.current.webBluetoothLinux,
      _ => ConnectionText.current.webBluetoothOther,
    };

/// Opens the device picker; if the user picks a device, connects over the
/// chosen transport and persists the intent. No-op on cancel.
Future<void> pickAndConnect(BuildContext context, WidgetRef ref) async {
  final target = await showSonicDialog<String>(
    context: context,
    builder: (_) => const DeviceDialog(),
  );

  if (target == null) return; // cancelled

  await connectAndPersist(ref, target: target);
}

/// Transport-aware device picker: a USB/BLE toggle plus the matching device
/// list (USB-MIDI ports, or scanned BLE devices). Sets [transportKindProvider]
/// to the toggled transport, and pops the chosen device name (the connect
/// target) — or null on cancel.
class DeviceDialog extends HookConsumerWidget {
  /// [scanner] replaces the platform scan (tests).
  const DeviceDialog({super.key, this.scanner});

  final Future<List<DeviceEntry>> Function(TransportKind kind)? scanner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = useState<List<DeviceEntry>?>(null); // null = scanning
    final selected = useState<String?>(null);
    final error = useState<String?>(null);

    Future<void> scan() async {
      rows.value = null;
      error.value = null;
      selected.value = null;

      final kind = ref.read(transportKindProvider);

      if (kind == .usb && !isWebMidiSupported) {
        rows.value = const [];
        error.value = webMidiUnsupportedMessage(defaultTargetPlatform);

        return;
      }

      if (kind == .ble && !isWebBluetoothSupported) {
        rows.value = const [];
        error.value = webBluetoothUnsupportedMessage(defaultTargetPlatform);

        return;
      }

      // Web Bluetooth has no passive scan — the browser exposes its own device
      // chooser (shown as a button below), so there is nothing to enumerate.
      if (kIsWeb && kind == .ble) {
        rows.value = const [];

        return;
      }

      try {
        final scanned = scanner != null
            ? await scanner!(kind)
            : kind == .usb
            ? [
                for (final d in await enumerateMidiDevices())
                  DeviceEntry(
                    name: d.name,
                    subtitle: d.connectable
                        ? ConnectionText.current.usbInOut
                        : d.hasInput
                        ? ConnectionText.current.inputOnly
                        : ConnectionText.current.outputOnly,
                    isEnabled: d.connectable,
                  ),
              ]
            : [
                for (final d in await enumerateBleDevices())
                  DeviceEntry(
                    name: d.name,
                    subtitle: '${d.address}   rssi ${d.rssi}',
                    isEnabled: d.name.isNotEmpty,
                  ),
              ];

        if (context.mounted) rows.value = scanned;
      } catch (e) {
        // e.g. the Bluetooth adapter is off, or MIDI enumeration failed.
        if (context.mounted) {
          rows.value = const [];
          error.value = ConnectionText.current.scanFailed(e);
        }
      }
    }

    void setKind(TransportKind k) {
      if (k == ref.read(transportKindProvider)) return;

      // Switching transport rebuilds DeviceService; it starts disconnected.
      ref.read(transportKindProvider.notifier).state = k;
      ref.read(connectionStateProvider.notifier).state = false;
      scan();
    }

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) => scan());

      return null;
    }, const []);

    final kind = ref.watch(transportKindProvider);
    final currentRows = rows.value;
    final errorText = error.value;

    final isWebBle = kIsWeb && kind == .ble;

    final Widget content = isWebBle && isWebBluetoothSupported
        ? WebBleChooser(onSelect: () => Navigator.pop(context, _webBleTarget))
        : currentRows == null
        ? const Center(child: SonicSpinner())
        : errorText != null
        ? DeviceStateMessage(errorText)
        : currentRows.isEmpty
        ? DeviceStateMessage(
            kind == .usb
                ? ConnectionText.current.noUsbDevices
                : ConnectionText.current.noBleDevices,
          )
        : ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final r in currentRows)
                _DeviceRow(
                  r,
                  isSelected: r.name == selected.value,
                  onTap: () => selected.value = r.name,
                ),
            ],
          );

    return DeviceDialogShell(
      content: content,
      transport: kind,
      onTransport: setKind,
      onRescan: isWebBle || currentRows == null ? null : scan,
      onConnect: selected.value == null
          ? null
          : () => Navigator.pop(context, selected.value),
    );
  }
}

/// The picker chrome (title, USB/BLE toggle, a content area, and Rescan/Cancel
/// actions) around a caller-provided [content].
///
/// The content area flexes: 300 px when there is room (the desktop look),
/// whatever a phone leaves otherwise, while the title, the toggle and the
/// actions stay pinned. Below [_minPickerContentHeight] the whole content
/// scrolls instead. One structure at every height, so a keyboard opening or
/// closing never remounts [content].
class DeviceDialogShell extends StatelessWidget {
  const DeviceDialogShell({
    super.key,
    required this.content,
    required this.transport,
    required this.onTransport,
    required this.onRescan,
    this.onConnect,
  });

  final Widget content;
  final TransportKind transport;
  final ValueChanged<TransportKind> onTransport;
  final VoidCallback? onRescan;

  /// Null (nothing selected) dims the Connect button.
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    return SonicDialog(
      maxWidth: 460,
      isScrollable: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.max(
                constraints.maxHeight,
                _minPickerContentHeight,
              ),
            ),
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                Text(
                  ConnectionText.current.selectDevice,
                  style: AppText.title.copyWith(color: Palette.onSurface),
                ),
                const SizedBox(height: 16),
                SonicSegmented<TransportKind>(
                  value: transport,
                  isExpanded: true,
                  height: 40,
                  segments: const [
                    (value: .ble, label: 'Bluetooth'),
                    (value: .usb, label: 'USB'),
                  ],
                  onChanged: onTransport,
                ),
                const SizedBox(height: 16),
                Flexible(child: SizedBox(height: 300, child: content)),
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _RescanLink(onTap: onRescan),
                        ),
                      ),
                      SonicButton(
                        label: CommonText.current.cancel,
                        height: 40,
                        minWidth: 100,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      SonicButton(
                        label: ConnectionText.current.connect,
                        height: 40,
                        minWidth: 100,
                        isAccent: true,
                        onPressed: onConnect,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A centred status line in the picker's content area ("No USB MIDI devices
/// found", a scan error, an unsupported-browser hint). It scrolls when a phone
/// leaves the area shorter than the text.
class DeviceStateMessage extends StatelessWidget {
  const DeviceStateMessage(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    // ponytail: solid border; the prototype's dashed one needs a custom painter.
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Palette.line2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox.expand(
        child: _CenteredScroll(
          child: Text(
            text,
            textAlign: .center,
            style: AppText.ui.copyWith(color: Palette.outline),
          ),
        ),
      ),
    );
  }
}

/// Web BLE content: a prompt plus a button that hands off to the browser's own
/// device chooser. Web Bluetooth has no passive scan and `requestDevice` needs a
/// user gesture, so the button tap both starts the chooser and carries the
/// transient activation into the connect flow.
class WebBleChooser extends StatelessWidget {
  const WebBleChooser({super.key, required this.onSelect});

  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    // Only the explanation scrolls: on a short phone it gives way, and the
    // button, the only way on, stays in view.
    return Center(
      child: Column(
        mainAxisSize: .min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: .min,
                children: [
                  Icon(
                    Icons.bluetooth_searching,
                    color: Palette.onSurfaceVariant,
                    size: 40,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ConnectionText.current.browserPicksBluetooth,
                    textAlign: .center,
                    style: AppText.ui.copyWith(color: Palette.outline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SonicButton(
            label: ConnectionText.current.selectBluetoothDevice,
            onPressed: onSelect,
          ),
        ],
      ),
    );
  }
}

/// Centres [child] in the picker's content area and lets it scroll when a
/// phone leaves the area shorter than it.
class _CenteredScroll extends StatelessWidget {
  const _CenteredScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(child: SingleChildScrollView(child: child));
  }
}

/// The "search again" text button, left of the actions.
class _RescanLink extends StatelessWidget {
  const _RescanLink({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: .opaque,
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisSize: .min,
              children: [
                Icon(Icons.refresh, size: 16, color: Palette.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    ConnectionText.current.rescan,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: AppText.ui.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Palette.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A selectable device entry in the picker list.
class _DeviceRow extends StatelessWidget {
  const _DeviceRow(this.row, {required this.isSelected, required this.onTap});

  final DeviceEntry row;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        behavior: .opaque,
        onTap: row.isEnabled ? onTap : null,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Opacity(
            opacity: row.isEnabled ? 1 : 0.5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Palette.primary.withValues(alpha: 0.10)
                    : Palette.field,
                border: Border.all(
                  color: isSelected ? Palette.primary : Palette.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        Text(
                          row.name.isEmpty
                              ? ConnectionText.current.unnamed
                              : row.name,
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: AppText.uiStrong.copyWith(
                            color: Palette.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.subtitle,
                          style: AppText.ui.copyWith(
                            fontSize: 12,
                            color: Palette.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.signal_cellular_alt,
                    size: 18,
                    color: row.isEnabled ? Palette.ok : Palette.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One scanned device in the picker.
class DeviceEntry {
  const DeviceEntry({
    required this.name,
    required this.subtitle,
    required this.isEnabled,
  });

  final String name;
  final String subtitle;
  final bool isEnabled;
}
