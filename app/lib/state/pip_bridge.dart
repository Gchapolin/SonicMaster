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

/// What the PiP window shows; recomputed when any of it changes.
final _pipInfoProvider = Provider<Map<String, Object?>>((ref) {
  ref.watch(paletteIdProvider); // the colors below follow the palette
  final preset = ref.watch(currentPresetProvider);
  final isConnected = ref.watch(connectionStateProvider);

  return {
    'label': preset?.label ?? '--',
    'name': preset == null ? '' : ref.watch(presetNamesProvider)[preset] ?? '',
    'device': isConnected
        ? ref.watch(connectedDeviceNameProvider) ?? ''
        : ConnectionText.current.disconnected,
    'connected': isConnected,
    'modified': ref.watch(presetModifiedProvider),
    'bg': Palette.background.toARGB32(),
    'fg': Palette.textPrimary.toARGB32(),
    'accent': Palette.accent.toARGB32(),
    'ok': Palette.ok.toARGB32(),
  };
});

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
      (_, info) => pipChannel.invokeMethod<void>('update', info),
      fireImmediately: true,
    );
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
    unawaited(
      loadPreset(
        ref,
        cur == null ? const PresetRef(.user, 1) : cur.neighbour(delta),
      ),
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
