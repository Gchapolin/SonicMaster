import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/connection_text.dart';
import '../model/preset_ref.dart';
import '../theme/app_colors.dart';
import 'device_providers.dart';
import 'names_providers.dart';
import 'palette_providers.dart';
import 'preset_providers.dart';

/// The channel to the iOS Picture-in-Picture window (Runner/AppDelegate.swift).
/// Dart -> native: `setEnabled(bool)`, `update(map)`; native -> Dart: `next`,
/// `previous` (the PiP skip buttons).
const pipChannel = MethodChannel('sonicmaster/pip');

/// What the PiP window shows, read through [get] (a provider's `ref.watch`,
/// or a widget ref's `ref.read` to take it on the spot).
Map<String, Object?> _pipInfo(T Function<T>(ProviderListenable<T>) get) {
  get(paletteIdProvider); // the colors below follow the palette
  final preset = get(currentPresetProvider);
  final isConnected = get(connectionStateProvider);
  final names = get(presetNamesProvider);
  // Where the skip buttons go (with nothing loaded, both load P01).
  final prev = preset?.neighbour(-1);
  final next = preset?.neighbour(1) ?? const PresetRef(.user, 1);

  return {
    'label': preset?.label ?? '--',
    'name': preset == null ? '' : names[preset] ?? '',
    'prevLabel': prev?.label ?? '',
    'prevName': prev == null ? '' : names[prev] ?? '',
    'nextLabel': next.label,
    'nextName': names[next] ?? '',
    'device': isConnected
        ? get(connectedDeviceNameProvider) ?? ''
        : ConnectionText.current.disconnected,
    'connected': isConnected,
    'modified': get(presetModifiedProvider),
    'bg': Palette.background.toARGB32(),
    'fg': Palette.textPrimary.toARGB32(),
    'accent': Palette.accent.toARGB32(),
    'ok': Palette.ok.toARGB32(),
  };
}

/// [_pipInfo], recomputed when any of it changes (in the foreground).
final _pipInfoProvider = Provider<Map<String, Object?>>(
  (ref) => _pipInfo(ref.watch),
);

/// Keeps the iOS PiP window in sync with the current preset and runs its
/// skip buttons. Mounted once above the app; a no-op off iOS.
///
/// A skip loads the next/previous preset straight away, like the pedal's
/// footswitch: the app is in the background, so there is no unsaved-changes
/// dialog and pending edits are dropped. It runs on this widget's ref, which
/// lives as long as the app ([loadPreset] reads its ref after every await).
class PipBridge extends ConsumerStatefulWidget {
  const PipBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PipBridge> createState() => _PipBridgeState();
}

class _PipBridgeState extends ConsumerState<PipBridge> {
  final _isOn = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();

    if (!_isOn) return;

    pipChannel.setMethodCallHandler(_onNative);
    pipChannel.invokeMethod<void>('setEnabled', true);
    ref.listenManual(
      _pipInfoProvider,
      (_, info) => _send(info),
      fireImmediately: true,
    );
  }

  Map<String, Object?>? _sent;

  void _send(Map<String, Object?> info) {
    if (mapEquals(info, _sent)) return;
    _sent = info;
    pipChannel.invokeMethod<void>('update', info);
  }

  Future<void> _onNative(MethodCall call) async {
    final delta = switch (call.method) {
      'next' => 1,
      'previous' => -1,
      _ => 0,
    };
    if (delta == 0) return;

    final cur = ref.read(currentPresetProvider);

    // Nothing loaded yet (fresh connection): either button starts at P01.
    // Not awaited: the skip button needs no answer, only the load.
    // In the background the app draws no frames, and Riverpod only tells
    // listeners about changes at the end of a frame: the window would keep
    // the old preset until the app came back. So once the load is done,
    // read the info on the spot and send it.
    unawaited(
      loadPreset(
        ref,
        cur == null ? const PresetRef(.user, 1) : cur.neighbour(delta),
      ).then((_) {
        if (mounted) _send(_pipInfo(ref.read));
      }),
    );
  }

  @override
  void dispose() {
    if (_isOn) pipChannel.setMethodCallHandler(null);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
