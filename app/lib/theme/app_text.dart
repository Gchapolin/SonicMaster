import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Named text-style tokens for the app.
///
/// Rule: never build a `TextStyle` from scratch — start from one of these tokens
/// and `.copyWith` only the deltas (a per-state color, a runtime-scaled size).
/// Tokens omit `color` where the call site sets it from state (active/disabled,
/// in-range/out-of-range); they bake a color only where the original style did.
///
/// The editor shell follows the prototype's faces (N_Principal.dc.html): Inter
/// for UI text ([ui], the root `WidgetsApp`'s app-wide `DefaultTextStyle`),
/// JetBrains Mono for numbers and codes, Space Grotesk for the logo and
/// titles, Barlow Condensed on gear pieces. Tokens carry `fontFamily`
/// explicitly where the default does not merge — a canvas / `TextPainter`, or
/// a raw `EditableText`, both of which paint the style verbatim.
///
/// The controls shared with the block editor (segments, dropdowns, buttons,
/// knobs, chain and module labels) still use the legacy condensed display
/// face, Oswald.
abstract final class AppText {
  static const String _display = 'Oswald';
  static const String _ui = 'Inter';
  static const String _mono = 'JetBrains Mono';
  static const String _title = 'Space Grotesk';

  /// Section header on the preset rail.
  static const TextStyle railHeader = TextStyle(
    fontFamily: _ui,
    fontWeight: FontWeight.w600,
    fontSize: 11,
    letterSpacing: 0.5,
  );

  /// LED / toggle button caption.
  static const TextStyle ledLabel = TextStyle(
    fontFamily: _display,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    letterSpacing: 1,
  );

  /// Segmented-control segment label.
  static const TextStyle segmentLabel = TextStyle(
    fontFamily: _display,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    letterSpacing: 1.4,
  );

  /// Dropdown trigger / select-parameter label (wide tracking).
  static const TextStyle controlLabel = TextStyle(
    fontFamily: _display,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    letterSpacing: 1.6,
  );

  /// Module / panel title.
  static const TextStyle moduleTitle = TextStyle(
    fontFamily: _display,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    letterSpacing: 0.8,
  );

  /// Selected preset name in the browser header.
  static const TextStyle presetTitle = TextStyle(
    fontFamily: _ui,
    fontWeight: FontWeight.w600,
    fontSize: 15,
  );

  /// Dropdown menu item.
  static const TextStyle menuItem = TextStyle(
    fontFamily: _display,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    letterSpacing: 1.3,
  );

  /// Push-button label. Size/tracking are scaled per instance:
  /// `AppText.button.copyWith(fontSize: 19 * s, letterSpacing: 19 * s * 0.12)`.
  static const TextStyle button = TextStyle(
    fontFamily: _display,
    fontWeight: FontWeight.w600,
    fontSize: 19,
    letterSpacing: 19 * 0.12,
  );

  /// Effect block label in the chain view (bold, tight).
  static const TextStyle chainLabel = TextStyle(
    fontFamily: _display,
    fontWeight: FontWeight.bold,
    fontSize: 12,
    letterSpacing: 0.5,
  );

  /// Small effect sub-label in the chain view.
  static TextStyle get chainSub =>
      TextStyle(fontFamily: _display, fontSize: 10, color: Palette.chainEffect);

  /// Connection well status label.
  static TextStyle get connectionLabel =>
      TextStyle(fontFamily: _ui, fontSize: 13, color: Palette.textMuted);

  /// Tap-tempo BPM readout.
  static TextStyle get bpm => TextStyle(
    fontFamily: _mono,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    color: Palette.textPrimary,
  );

  /// Large tap-tempo BPM display (color set per in/out-of-range state).
  static const TextStyle bpmDisplay = TextStyle(
    fontFamily: _mono,
    fontWeight: FontWeight.w500,
    fontSize: 20,
  );

  /// KnobControl / PanelCell value readout (12pt base × 1.5).
  static TextStyle get knobValue => TextStyle(
    fontFamily: _display,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    color: Palette.textPrimary,
  );

  /// KnobControl / PanelCell caption under the knob (11pt base × 1.5).
  static TextStyle get knobLabel => TextStyle(
    fontFamily: _display,
    fontWeight: FontWeight.w500,
    fontSize: 16.5,
    letterSpacing: 0.8,
    color: Palette.textMuted,
  );

  /// Compact [knobValue]: the readout over a 72-px panel knob. A full token,
  /// not a `copyWith`: SonicMetrics.compact is const.
  static TextStyle get knobValueCompact => TextStyle(
    fontFamily: _display,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: Palette.textPrimary,
  );

  /// Compact [knobLabel]: the caption under a 72-px panel knob, with tracking
  /// tightened to match the smaller size.
  static TextStyle get knobLabelCompact => TextStyle(
    fontFamily: _display,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    letterSpacing: 0.6,
    color: Palette.textMuted,
  );

  /// Module help / description text.
  static TextStyle get moduleDescription =>
      TextStyle(color: Palette.textDescription, fontSize: 13, height: 1.4);

  /// Device-list row title.
  static TextStyle get deviceRowTitle =>
      TextStyle(color: Palette.textPrimary, fontSize: 16);

  /// Device-list row subtitle.
  static TextStyle get deviceRowSub =>
      TextStyle(color: Palette.textDim, fontSize: 12);

  /// Dialog title.
  static TextStyle get dialogTitle => TextStyle(
    fontFamily: _title,
    color: Palette.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  /// Dialog body copy.
  static TextStyle get dialogBody => TextStyle(
    fontFamily: _ui,
    color: Palette.textMuted,
    fontSize: 14,
    height: 1.4,
  );

  /// Text-field input text. Carries the UI face explicitly: it is handed
  /// to a raw `EditableText`, which paints its style verbatim rather than
  /// merging the ambient `DefaultTextStyle` the way `Text` does.
  static TextStyle get input =>
      TextStyle(fontFamily: _ui, color: Palette.textPrimary);

  /// Text-field label.
  static TextStyle get inputLabel => TextStyle(color: Palette.textMuted);

  /// Text-field hint / counter / faint helper.
  static TextStyle get inputHint => TextStyle(color: Palette.textDim);

  /// Monospaced log line (dev console).
  static const TextStyle monoLog = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
  );

  /// Emphasised section label (dev console header).
  static const TextStyle boldLabel = TextStyle(
    fontFamily: _ui,
    fontWeight: FontWeight.bold,
  );

  // Prototype faces (redesign). Colors are set by the call site.

  /// Default UI text.
  static const TextStyle ui = TextStyle(
    fontFamily: _ui,
    fontWeight: FontWeight.w500,
    fontSize: 13,
  );

  /// Emphasised UI text.
  static const TextStyle uiStrong = TextStyle(
    fontFamily: _ui,
    fontWeight: FontWeight.w600,
    fontSize: 15,
  );

  /// Screen / panel title.
  static const TextStyle title = TextStyle(
    fontFamily: _title,
    fontWeight: FontWeight.w600,
    fontSize: 22,
  );

  /// Section header; upper-case the text at the call site.
  static const TextStyle section = TextStyle(
    fontFamily: _ui,
    fontWeight: FontWeight.w600,
    fontSize: 11,
    letterSpacing: 1,
  );

  /// Numeric / code readout.
  static const TextStyle mono = TextStyle(fontFamily: _mono, fontSize: 13);

  /// Label on a gear piece (size set by the call site).
  static const TextStyle gearLabel = TextStyle(
    fontFamily: 'Barlow Condensed',
    fontWeight: FontWeight.w600,
  );

  /// Tiny meter scale readout.
  static const TextStyle meter = TextStyle(
    fontFamily: 'Share Tech Mono',
    fontSize: 10,
  );
}
