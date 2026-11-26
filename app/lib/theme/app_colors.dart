import 'package:flutter/painting.dart';

/// The app's single source of color: a Material 3 dark scheme.
///
/// The roles hold the Adobe Color palette "Vintage Neutral - Muted"
/// (6A736F A4A698 D9D0C7 D9AB9A D98977) as a dark UI, the same values as the
/// HTML prototype: warm terracotta surfaces, light warm text and the
/// terracotta accent. They are written as consts so `lib/` stays free of
/// `package:flutter/material.dart`; palette_test.dart pins them and their
/// contrast. The look is flat: no widget keeps gradients, shadows or inline
/// colors of its own (flat_style_test.dart).
///
/// The legacy names below map onto the roles, so call sites keep their
/// meaning. Colors that carry a meaning of their own (error, connection
/// status, scrim) keep their values.
abstract final class Palette {
  // Material 3 roles.
  static const Color primary = Color(0xFFDF9D8E);
  static const Color onPrimary = Color(0xFF312320);
  static const Color primaryContainer = Color(0xFF7A4A40);
  static const Color onPrimaryContainer = Color(0xFFFFDAD2);
  static const Color secondaryContainer = Color(0xFF835E56);
  static const Color onSecondaryContainer = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFF3E2C28);
  static const Color surfaceContainerLowest = Color(0xFF352521);
  static const Color surfaceContainerLow = Color(0xFF45322D);
  static const Color surfaceContainer = Color(0xFF4A3530);
  static const Color surfaceContainerHigh = Color(0xFF513A35);
  static const Color surfaceContainerHighest = Color(0xFF5E443E);
  static const Color onSurface = Color(0xFFF0ECE9);
  static const Color onSurfaceVariant = Color(0xFFE1D9D2);
  static const Color outline = Color(0xFFCDBEB8);
  static const Color outlineVariant = Color(0xFF694B45);

  /// The window background.
  static const Color background = surface;

  /// Primary interactive accent (buttons, cursors, scan spinner, active menu).
  static const Color accent = primary;

  /// Warning / out-of-range red.
  static const Color error = Color(0xFFFF5449);

  /// Primary text.
  static const Color textPrimary = onSurface;

  /// Secondary / body text.
  static const Color textMuted = onSurfaceVariant;

  /// Dimmed text — hints, counters, sub-labels.
  static const Color textDim = outline;

  /// Module help text.
  static const Color textDescription = onSurfaceVariant;

  /// Field text on inputs.
  static const Color fieldText = onSurface;

  /// Preset-rail text tones and border.
  static const Color railText = onSurface;
  static const Color railMuted = onSurfaceVariant;
  static const Color railBorder = outlineVariant;

  /// Chain-view icon and effect-label tones.
  static const Color chainIcon = onSurfaceVariant;
  static const Color chainEffect = onSurfaceVariant;

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
