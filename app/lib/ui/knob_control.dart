import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'; // re-exports Matrix4 (vector_math)
import 'package:flutter_hooks/flutter_hooks.dart';

import '../model/slider_nudge.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'sonic_field.dart';
import 'sonic_metrics.dart';

/// A rotary knob drawn as a flat Material arc dial. Vertical
/// drag / scroll / double-tap-to-type edit the [value]; reports via [onChanged].
///
/// Pointer kinds get their own recognizers, so a knob shares input with the
/// scroll views around it: a mouse or trackpad pans it as on desktop, a touch
/// or stylus drag turns it (see [isHoldToTurnOnTouch]), and a mouse-wheel tick
/// over it nudges it without also scrolling the page. A trackpad swipe on the
/// web scrolls the page and nudges the knob, as before.
class KnobControl extends HookWidget {
  const KnobControl({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.label,
    required this.onChanged,
    this.unit,
    this.valueText,
    this.isEnabled = true,
    this.size = 120,
    this.isHoldToTurnOnTouch = false,
    this.isDense = false,
    this.isInline = false,
  });

  // Pixels of vertical drag that span the whole [min,max] range. One tunable:
  // lower = more sensitive. Shift multiplies it (fine-tune).
  static const double _travelPx = 250;

  /// The pointers that turn a knob by a vertical drag (or a hold, then a drag)
  /// instead of a pan: fingers and pens, plus unknown kinds.
  static const Set<PointerDeviceKind> _touchDevices = {
    .touch,
    .stylus,
    .invertedStylus,
    .unknown,
  };

  /// How long a finger rests on a hold-to-turn knob before it turns.
  static const Duration _holdToTurnDelay = Duration(milliseconds: 200);

  final num value;
  final num min;
  final num max;
  final num step;
  final String label;
  final String? unit;

  /// Replaces the readout (value + unit) with a ready-made text, e.g. "26Hz".
  final String? valueText;
  final ValueChanged<num> onChanged;
  final bool isEnabled;
  final double size;

  /// Touch only: the knob turns after a 200-ms hold instead of on the first
  /// drag, so a flick that starts on it scrolls the list it sits in. For knobs
  /// inside scrolling lists that drive live output levels (the drawer's Master
  /// Vol, the Settings knobs). Mouse and trackpad are unaffected.
  final bool isHoldToTurnOnTouch;

  /// Draws the readout and caption with the compact faces and a tighter cell,
  /// for dense panels; input behaviour still follows the layout.
  final bool isDense;

  /// The prototype's compact row (the rail's Volume geral): the dial, then
  /// the caption over the value (JetBrains Mono), left-aligned beside it.
  final bool isInline;

  @override
  Widget build(BuildContext context) {
    final isEditing = useState(false);
    final dragValue = useState<double>(0); // unsnapped accumulator (no drift)
    // The hold-to-turn drag's last offset (dy); null until its first move.
    final holdDy = useRef<double?>(null);
    final controller = useTextEditingController();
    final editorFocus = useFocusNode();
    final metrics = SonicMetrics.of(context);
    final valueStyle = isInline
        ? AppText.mono.copyWith(fontSize: 15, color: Palette.textPrimary)
        : isDense
        ? AppText.knobValueCompact
        : metrics.knobValueStyle;
    final readoutWidth = isInline ? 56.0 : size;
    final readoutAlignment = isInline ? Alignment.centerLeft : Alignment.center;

    // One step of vertical travel, shared by every pointer kind: up increases
    // ([dy] is +down, so negate). Shift = fine-tune (~4× slower); read
    // per-update so mid-drag toggling is smooth.
    void turnBy(double dy) {
      if (!isEnabled) return;

      final travel = HardwareKeyboard.instance.isShiftPressed
          ? _travelPx * 4
          : _travelPx;

      dragValue.value = dragLinearStep(dragValue.value, -dy, min, max, travel);
      onChanged(snapToStep(dragValue.value, step));
    }

    void dragStart(DragStartDetails d) => dragValue.value = value.toDouble();

    void dragUpdate(DragUpdateDetails d) => turnBy(d.delta.dy);

    void holdStart(LongPressStartDetails d) {
      dragValue.value = value.toDouble();
      holdDy.value = null;
    }

    // A long press reports its offset from the press point, not a delta. That
    // offset includes the finger's drift while it rested (up to the touch
    // slop), so the first move after the hold only sets the baseline: the
    // drift never turns the knob.
    void holdUpdate(LongPressMoveUpdateDetails d) {
      final dy = d.offsetFromOrigin.dy;
      final last = holdDy.value;

      holdDy.value = dy;

      if (last != null) turnBy(dy - last);
    }

    void onSignal(PointerSignalEvent e) {
      if (!isEnabled || e is! PointerScrollEvent || e.scrollDelta.dy == 0) {
        return;
      }

      final direction = e.scrollDelta.dy < 0 ? 1 : -1;

      // The web sends a trackpad two-finger swipe as scroll signals (native
      // sends pan-zoom). Keep today's path for it: nudge without claiming the
      // signal, so a scroll view that can move still scrolls. Firefox reports
      // a trackpad as a mouse, so there a swipe acts as a wheel.
      if (e.kind == .trackpad) {
        onChanged(nudge(value, step, direction, min, max));

        return;
      }

      // Through the resolver: the knob is the innermost claimant, so it wins
      // the tick and an enclosing scroll view (the work area, the drawer or
      // Settings list) no longer scrolls on the same tick.
      GestureBinding.instance.pointerSignalResolver.register(
        e,
        (_) => onChanged(nudge(value, step, direction, min, max)),
      );
    }

    // Touch, stylus and unknown pointers. Default: a vertical drag. It has the
    // scroll view's own 18-px slop, and the knob, the innermost recognizer,
    // sees each move first, so a drag that starts on the knob turns it instead
    // of scrolling the page (the pan needs 36 px and always lost on touch).
    // Hold-to-turn: a 200-ms long press instead; a quick flick moves past the
    // slop first and goes to the scroll view. Only the recognizer differs.
    final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    final touchGestures = <Type, GestureRecognizerFactory>{
      if (isHoldToTurnOnTouch)
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: _holdToTurnDelay,
                supportedDevices: _touchDevices,
              ),
              (recognizer) => recognizer
                ..gestureSettings = gestureSettings
                ..onLongPressStart = isEnabled ? holdStart : null
                ..onLongPressMoveUpdate = isEnabled ? holdUpdate : null,
            )
      else
        VerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
              () => VerticalDragGestureRecognizer(
                supportedDevices: _touchDevices,
              ),
              (recognizer) => recognizer
                ..gestureSettings = gestureSettings
                ..onStart = isEnabled ? dragStart : null
                ..onUpdate = isEnabled ? dragUpdate : null,
            ),
    };

    void startEdit() {
      final text = '$value';

      // Compact (phones): open with the whole value selected, so the first
      // keystroke replaces it; a phone has no mouse and no selection toolbar
      // to select it by hand. selectAllOnFocus can't do it: the editor
      // autofocuses, and the SDK skips select-all for that internal focus.
      // Regular keeps today's caret after the value.
      controller.value = TextEditingValue(
        text: text,
        selection: metrics.isCompact
            ? TextSelection(baseOffset: 0, extentOffset: text.length)
            : TextSelection.collapsed(offset: text.length),
      );
      isEditing.value = true;
    }

    void commit() {
      // Compact (phones): a decimal comma from the keyboard reads as a point.
      final v = parseSliderValue(
        controller.text,
        min,
        max,
        step,
        isDecimalCommaAccepted: true,
      );

      if (isEditing.value) isEditing.value = false;

      if (v != null) onChanged(v);
    }

    void cancel() {
      if (isEditing.value) isEditing.value = false;
    }

    // Compact (phones): an editor that loses its focus commits. Closing the
    // drawer or showing the rotate prompt takes focus away without a tap, so
    // the tap-outside commit never fires. Regular keeps today's behaviour.
    // Re-subscribed every build, so it calls the current commit; isEditing
    // guards the blur that follows a Done (which committed already).
    useEffect(() {
      void onFocusChange() {
        if (metrics.isCompact && isEditing.value && !editorFocus.hasFocus) {
          commit();
        }
      }

      editorFocus.addListener(onFocusChange);

      return () => editorFocus.removeListener(onFocusChange);
    });

    final knob = MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: SizedBox(
        key: const Key('knob'),
        width: size,
        height: size,
        child: Listener(
          onPointerSignal: onSignal,
          // Mouse and trackpad keep today's pan: a precise pointer turns the
          // knob after 2 px, and a native trackpad two-finger swipe (pan-zoom,
          // 36-px pan slop) still loses to the scroll view's 18 px, so it
          // scrolls the page. The web sends that swipe as scroll signals,
          // which onSignal handles.
          child: GestureDetector(
            supportedDevices: const {.mouse, .trackpad},
            onPanStart: isEnabled ? dragStart : null,
            onPanUpdate: isEnabled ? dragUpdate : null,
            child: RawGestureDetector(
              gestures: touchGestures,
              child: CustomPaint(
                painter: () {
                  final arc = knobArc(value, min, max);

                  return _KnobPainter(from: arc.from, to: arc.to);
                }(),
              ),
            ),
          ),
        ),
      ),
    );

    // The readout row: the dial's width, the value centred in it.
    final readout = isEditing.value
        ? SizedBox(
            width: readoutWidth,
            child: Align(
              alignment: readoutAlignment,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): cancel,
                },
                child: SonicField(
                  controller: controller,
                  focusNode: editorFocus,
                  autofocus: true,
                  textAlign: isInline ? .start : .center,
                  style: valueStyle,
                  isRecessed: false,
                  padding: EdgeInsets.zero,
                  // Compact (phones): the number pad, signed where the range
                  // is, and no autocorrect or suggestion strip over a number.
                  // Regular keeps today's keyboard and entry options.
                  keyboardType: metrics.isCompact
                      ? numericKeyboardType(isSigned: min < 0)
                      : const TextInputType.numberWithOptions(decimal: true),
                  // The SDK default on the web and desktop, where the app
                  // runs: a re-tap after the field lost focus selects the
                  // value again.
                  selectAllOnFocus: true,
                  autocorrect: !metrics.isCompact,
                  enableSuggestions: !metrics.isCompact,
                  onSubmitted: (_) => commit(),
                  onTapOutside: (_) => commit(),
                ),
              ),
            ),
          )
        : GestureDetector(
            // Compact (touch): the whole row takes the double-tap, not just
            // the digits (~16x21 px on a phone). Regular keeps today's
            // digits-only target.
            behavior: metrics.isCompact ? .opaque : .deferToChild,
            onDoubleTap: isEnabled ? startEdit : null,
            child: SizedBox(
              width: readoutWidth,
              child: Align(
                alignment: readoutAlignment,
                child: Text(
                  valueText ?? '$value${unit ?? ''}',
                  style: valueStyle,
                ),
              ),
            ),
          );

    if (isInline) {
      return Row(
        mainAxisSize: .min,
        spacing: 12,
        children: [
          knob,
          Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppText.section.copyWith(color: Palette.muted),
              ),
              readout,
            ],
          ),
        ],
      );
    }

    // A vertical cell — value on top, knob, name below — so cells sit side by
    // side in a Wrap like the knobs on a hardware unit.
    return Padding(
      padding: EdgeInsets.all(isDense ? 4 : metrics.knobCellPadding),
      child: Column(
        mainAxisSize: .min,
        children: [
          readout,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: knob,
          ),
          if (label.isNotEmpty)
            Text(
              label.toUpperCase(),
              style: isDense
                  ? AppText.knobLabelCompact
                  : metrics.knobLabelStyle,
            ),
        ],
      ),
    );
  }
}

/// The active stretch of the knob's track, as fractions (0..1) of its 270°
/// sweep. It runs from the zero point to [value]: from the start for ranges
/// that begin at 0, from the middle for bipolar ones (EQ -50..50), from the
/// end for ranges that end at 0 (Low Pitch -24..0). Values outside the range
/// clamp to the track; a degenerate range draws nothing.
({double from, double to}) knobArc(num value, num min, num max) {
  if (max == min) return (from: 0.0, to: 0.0);

  double frac(num v) => ((v - min) / (max - min)).clamp(0.0, 1.0).toDouble();

  final anchor = frac(0);
  final f = frac(value);

  return (from: math.min(anchor, f), to: math.max(anchor, f));
}

/// Paints the flat Material dial: a 270° track and, over it, the active arc
/// between [from] and [to] (fractions of the track).
class _KnobPainter extends CustomPainter {
  _KnobPainter({required this.from, required this.to});

  final double from;
  final double to;

  static const _start = 3 * math.pi / 4; // 135°, bottom-left
  static const _sweep = 3 * math.pi / 2; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Rect.fromCircle(
      center: Offset(s / 2, s / 2),
      radius: 0.39 * s,
    );
    Paint stroke(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.11 * s
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      stroke(Palette.secondaryContainer),
    );

    if (to > from) {
      canvas.drawArc(
        rect,
        _start + from * _sweep,
        (to - from) * _sweep,
        false,
        stroke(Palette.primary),
      );
    }
  }

  @override
  bool shouldRepaint(_KnobPainter old) => old.from != from || old.to != to;
}
