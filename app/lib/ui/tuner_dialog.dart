import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/common_text.dart';
import '../l10n/tuner_text.dart';
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
  static const inTuneCents = 5.0;

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
    final t = TunerText.current;
    final a4 = r?.a4 ?? 440;
    final info = r == null
        ? t.opening
        : !hasNote
        ? t.playString
        : '${r.hz.toStringAsFixed(1)} Hz · '
              '${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(1)} cents';
    Color labelColor(bool isActive) => isActive
        ? (isInTune ? Palette.ok : Palette.onSurface)
        : Palette.outline;
    final labelStyle = AppText.section.copyWith(fontSize: 12);

    return SonicDialog(
      maxWidth: 420,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              t.title,
              style: AppText.title.copyWith(color: Palette.onSurface),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: .center,
            crossAxisAlignment: .baseline,
            textBaseline: .alphabetic,
            children: [
              Text(
                hasNote ? r.noteName! : '—',
                style: AppText.title.copyWith(
                  fontSize: 96,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: isInTune ? Palette.ok : Palette.onSurface,
                ),
              ),
              if (hasNote) ...[
                const SizedBox(width: 4),
                Text(
                  '${r.octave}',
                  style: AppText.title.copyWith(
                    color: Palette.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            info,
            textAlign: .center,
            style: AppText.mono.copyWith(
              fontSize: 14,
              color: Palette.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TunerGauge(cents: hasNote ? cents : null),
          const SizedBox(height: 12),
          SizedBox(
            width: 320,
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text(
                  t.flat,
                  style: labelStyle.copyWith(
                    color: labelColor(hasNote && cents < -inTuneCents),
                  ),
                ),
                Text(t.inTune, style: labelStyle.copyWith(color: Palette.ok)),
                Text(
                  t.sharp,
                  style: labelStyle.copyWith(
                    color: labelColor(hasNote && cents > inTuneCents),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: Palette.outlineVariant),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'A4',
                style: AppText.ui.copyWith(color: Palette.onSurfaceVariant),
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
              const Spacer(),
              SonicToggle(
                value: r?.isMuted ?? false,
                onChanged: (v) => send(tunerOutputFrame(isMuted: v)),
              ),
              const SizedBox(width: 10),
              Text(
                t.mute,
                style: AppText.uiStrong.copyWith(color: Palette.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: SonicButton(
              label: CommonText.current.close,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Needle angle from straight up, in radians: -50..+50 cents over
/// -60..+60 degrees; beyond the scale it stops at the end.
double tunerNeedleAngle(double cents) =>
    cents.clamp(-50.0, 50.0) * 1.2 * pi / 180;

/// The arc meter: -50..+50 cents, ticks every 5 (long every 10), the
/// in-tune zone, and the needle at [cents] (null: no note, needle at rest).
class TunerGauge extends StatelessWidget {
  const TunerGauge({super.key, required this.cents});

  final double? cents;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 340,
    height: 172,
    child: CustomPaint(
      painter: _GaugePainter(
        cents: cents,
        track: Palette.line2,
        zone: Palette.ok,
        minor: Palette.outlineVariant,
        major: Palette.outline,
        needle: Palette.onSurface,
        hub: Palette.secondaryContainer,
      ),
    ),
  );
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.cents,
    required this.track,
    required this.zone,
    required this.minor,
    required this.major,
    required this.needle,
    required this.hub,
  });

  final double? cents;
  final Color track, zone, minor, major, needle, hub;

  static const _pivot = Offset(170, 160);

  Offset _at(double c, double r) {
    final a = tunerNeedleAngle(c);

    return _pivot + Offset(r * sin(a), -r * cos(a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    void arc(double from, double to, Paint paint) => canvas.drawArc(
      Rect.fromCircle(center: _pivot, radius: 148),
      tunerNeedleAngle(from) - pi / 2,
      tunerNeedleAngle(to) - tunerNeedleAngle(from),
      false,
      paint,
    );

    arc(-50, 50, stroke(track, 6));
    arc(-5, 5, stroke(zone, 6));

    for (var c = -50; c <= 50; c += 5) {
      final isMajor = c % 10 == 0;

      canvas.drawLine(
        _at(c.toDouble(), isMajor ? 124 : 130),
        _at(c.toDouble(), 138),
        isMajor ? stroke(major, 2.5) : stroke(minor, 2),
      );
    }

    canvas.drawLine(_pivot, _at(cents ?? 0, 132), stroke(needle, 3));
    canvas.drawCircle(_pivot, 8, Paint()..color = hub);
    canvas.drawCircle(_pivot, 8, stroke(needle, 2));
  }

  @override
  bool shouldRepaint(_GaugePainter o) =>
      o.cents != cents ||
      o.track != track ||
      o.zone != zone ||
      o.minor != minor ||
      o.major != major ||
      o.needle != needle ||
      o.hub != hub;
}
