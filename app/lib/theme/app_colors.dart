import 'package:flutter/painting.dart';

import 'app_palettes.dart';

/// The app's single source of color: a Material 3 dark scheme.
///
/// The roles hold the Adobe Color palette "Vintage Neutral - Muted"
/// (6A736F A4A698 D9D0C7 D9AB9A D98977) as a dark UI, the same values as the
/// HTML prototype: warm terracotta surfaces, light warm text and the
/// terracotta accent. They are read from [Palette.current] (see app_palettes.dart);
/// palette_test.dart pins the default and its contrast. The look is flat: no widget keeps gradients, shadows or inline
/// colors of its own (flat_style_test.dart).
///
/// The legacy names below map onto the roles, so call sites keep their
/// meaning. Colors that carry a meaning of their own (error, connection
/// status, scrim) keep their values.
abstract final class Palette {
  /// The active palette; set it at startup or when the user picks one.
  static AppPalette current = appPalettes.first;

  static Color get field => current.field;
  static Color get line2 => current.line2;
  static Color get ok => current.ok;
  static Color get faint => current.faint;

  // Material 3 roles.
  static Color get primary => current.acc;
  static Color get onPrimary => current.onAcc;
  static Color get primaryContainer => current.accContainer;
  static Color get onPrimaryContainer => current.onAccContainer;
  static Color get secondaryContainer => current.sel;
  static Color get onSecondaryContainer => current.strong;
  static Color get surface => current.bg;
  static Color get surfaceContainerLowest => current.lowest;
  static Color get surfaceContainerLow => current.side;
  static Color get surfaceContainer => current.head;
  static Color get surfaceContainerHigh => current.card;
  static Color get surfaceContainerHighest => current.ctrl;
  static Color get onSurface => current.text;
  static Color get onSurfaceVariant => current.text2;
  static Color get outline => current.outline;
  static Color get outlineVariant => current.line;

  /// The window background.
  static Color get background => surface;

  /// Primary interactive accent (buttons, cursors, scan spinner, active menu).
  static Color get accent => primary;

  /// Warning / out-of-range red: a salmon red that keeps 4.5:1 on the card and
  /// head surfaces of all 18 palettes.
  static const Color error = Color(0xFFFF8F86);

  /// Primary text.
  static Color get textPrimary => onSurface;

  /// Secondary / body text.
  static Color get textMuted => onSurfaceVariant;

  /// Dimmed text — hints, counters, sub-labels.
  static Color get textDim => outline;

  /// Module help text.
  static Color get textDescription => onSurfaceVariant;

  /// Field text on inputs.
  static Color get fieldText => onSurface;

  /// Preset-rail text tones and border.
  static Color get railText => onSurface;
  static Color get railMuted => onSurfaceVariant;
  static Color get railBorder => outlineVariant;

  /// Chain-view icon and effect-label tones.
  static Color get chainIcon => onSurfaceVariant;
  static Color get chainEffect => onSurfaceVariant;

  /// Connection status LEDs.
  static const Color ledConnected = Color(0xFF44FF44);
  static const Color ledDisconnected = Color(0xFFFF4444);

  /// Modal dim: the barrier behind pop-ups (showSonicDialog) and behind the
  /// compact preset drawer.
  static const Color scrim = Color(0x99000000);

  /// Fully transparent (the native desktop window's background).
  static const Color transparent = Color(0x00000000);

  /// Per-module effect-icon tint, matching the pedal's own screen colours
  /// (kept a touch more saturated than phone photos of the display, which
  /// read lighter). Keyed by physical module id (0=NR … 8=RVB).
  static const Map<int, Color> moduleIcon = {
    0: Color(0xFFFFFFFF), // NR  — white
    1: Color(0xFF5B8DEF), // FX1 — light blue
    2: Color(0xFFFF4136), // DRV — red
    3: Color(0xFFFF851B), // AMP — orange
    4: Color(0xFFFFD400), // IR  — yellow
    5: Color(0xFFA6E22E), // EQ  — lime
    6: Color(0xFF3FD6EC), // FX2 — light cyan
    7: Color(0xFF1570A8), // DLY — dark cyan (distinct from FX2's bright cyan)
    8: Color(0xFFA45DE8), // RVB — violet
  };
}
