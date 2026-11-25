import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../model/tuner_reading.dart';
import '../protocol/cfw_tuner_codec.dart';
import '../state/device_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'sonic_controls.dart';

/// The CFW pedal's tuner, mirrored: while this dialog is up the pedal's tuner
/// is open and polled for readings (note, cents, Hz); A4 and the output
/// (mute / bypass) are the pedal's own settings. Closing it closes the
/// pedal's tuner.
class TunerDialog extends HookConsumerWidget {
  const TunerDialog({super.key});

  /// How often the pedal is asked for a reading.
  static const pollEvery = Duration(milliseconds: 120);

  /// Within this many cents the note counts as in tune.
  static const inTuneCents = 3.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(deviceServiceProvider);
    final reading = useState<TunerReading?>(null);

    void send(String frame) =>
        unawaited(service.sendFrame(frame).catchError((_) {}));

    useEffect(() {
      var isBusy = false;
      var isDisposed = false;

      send(tunerOpenFrame(isOpen: true));

      final timer = Timer.periodic(pollEvery, (_) async {
        // One read at a time: a slow link must not queue reads on the IO gate.
        if (isBusy) return;

        isBusy = true;
        try {
          final hex = await service.requestTunerReading();
          final r = hex == null ? null : decodeTunerFrame(hex);

          if (isDisposed || r == null) return;

          reading.value = r;
          // The open frame may have been lost: ask again.
          if (!r.isOpen) send(tunerOpenFrame(isOpen: true));
        } catch (_) {
          // A missed read keeps the last reading.
        } finally {
          isBusy = false;
        }
      });

      return () {
        isDisposed = true;
        timer.cancel();
        send(tunerOpenFrame(isOpen: false));
      };
    }, [service]);

    // A dropped link leaves nothing to mirror (and the close frame could not
    // reach the pedal later): close with it.
    ref.listen(connectionStateProvider, (_, isConnected) {
      if (!isConnected) Navigator.maybePop(context);
    });

    final r = reading.value;
    final hasNote = r != null && r.hasNote;
    final cents = hasNote ? r.cents : 0.0;
    final isInTune = hasNote && cents.abs() <= inTuneCents;
    final status = r == null
        ? 'Opening the pedal\'s tuner…'
        : !hasNote
        ? 'Play a string'
        : isInTune
        ? 'IN TUNE'
        : (cents < 0 ? 'FLAT' : 'SHARP');
    final a4 = r?.a4 ?? 440;

    return SonicDialog(
      maxWidth: 420,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          const Text('Tuner', style: AppText.dialogTitle),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: .center,
            crossAxisAlignment: .baseline,
            textBaseline: .alphabetic,
            children: [
              Text(
                hasNote ? r.noteName! : '—',
                style: AppText.bpmDisplay.copyWith(
                  fontSize: 56,
                  color: isInTune ? Palette.accent : Palette.onSurface,
                ),
              ),
              if (hasNote) ...[
                const SizedBox(width: 4),
                Text(
                  '${r.octave}',
                  style: AppText.dialogTitle.copyWith(
                    color: Palette.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          Text(
            status,
            textAlign: .center,
            style: AppText.dialogBody.copyWith(
              color: isInTune ? Palette.accent : Palette.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _Needle(cents: hasNote ? cents : null, isInTune: isInTune),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: .center,
            children: [
              Text(
                hasNote
                    ? '${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(1)} ¢'
                    : '— ¢',
                style: AppText.dialogBody,
              ),
              const SizedBox(width: 16),
              Text(
                hasNote ? '${r.hz.toStringAsFixed(1)} Hz' : '— Hz',
                style: AppText.dialogBody,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: .center,
            crossAxisAlignment: .center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: .min,
                children: [
                  Text(
                    'A4',
                    style: AppText.dialogBody.copyWith(
                      color: Palette.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SonicDropdown<int>(
                    value: a4,
                    width: 104,
                    items: [
                      for (final hz in {
                        for (var hz = 430; hz <= 450; hz++) hz,
                        a4,
                      }.toList()..sort())
                        (value: hz, label: '$hz Hz'),
                    ],
                    onChanged: (hz) => send(tunerA4Frame(hz)),
                  ),
                ],
              ),
              SonicSegmented<bool>(
                value: r?.isMuted ?? false,
                segments: const [
                  (value: true, label: 'Mute'),
                  (value: false, label: 'Bypass'),
                ],
                onChanged: (v) => send(tunerOutputFrame(isMuted: v)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: SonicButton(
              label: 'Close',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// A flat cents scale, -50..+50 with a centre mark; the marker sits at
/// [cents] (null: no note, no marker).
class _Needle extends StatelessWidget {
  const _Needle({required this.cents, required this.isInTune});

  final double? cents;
  final bool isInTune;

  @override
  Widget build(BuildContext context) {
    final at = cents?.clamp(-50, 50);

    return SizedBox(
      height: 22,
      child: Stack(
        alignment: .center,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Palette.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(width: 2, height: 22, color: Palette.outline),
          if (at != null)
            Align(
              alignment: Alignment(at / 50, 0),
              child: Container(
                width: 8,
                height: 18,
                decoration: BoxDecoration(
                  color: isInTune ? Palette.accent : Palette.onSurface,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
