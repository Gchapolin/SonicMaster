import 'package:flutter/painting.dart';

/// The app's single source of color: a Material 3 dark scheme.
///
/// The roles are the values `ColorScheme.fromSeed(seedColor: 0xFFEF8A24,
/// brightness: dark)` produces (default tonalSpot variant), written as consts
/// so `lib/` stays free of `package:flutter/material.dart`; palette_test.dart
/// checks them against fromSeed. The look is flat: no widget keeps gradients,
/// shadows or inline colors of its own (flat_style_test.dart).
///
/// The legacy names below map onto the roles, so call sites keep their
/// meaning. Colors that carry a meaning of their own (error, connection
/// status, scrim) keep their values.
abstract final class Palette {
  // Material 3 roles.
  static const Color primary = Color(0xFFFFB77C);
  static const Color onPrimary = Color(0xFF4D2600);
  static const Color primaryContainer = Color(0xFF6C3A06);
  static const Color onPrimaryContainer = Color(0xFFFFDCC3);
  static const Color secondaryContainer = Color(0xFF5A422E);
  static const Color onSecondaryContainer = Color(0xFFFFDCC3);
  static const Color surface = Color(0xFF19120C);
  static const Color surfaceContainerLowest = Color(0xFF140D08);
  static const Color surfaceContainerLow = Color(0xFF221A14);
  static const Color surfaceContainer = Color(0xFF261E18);
  static const Color surfaceContainerHigh = Color(0xFF312822);
  static const Color surfaceContainerHighest = Color(0xFF3C332C);
  static const Color onSurface = Color(0xFFEFE0D6);
  static const Color onSurfaceVariant = Color(0xFFD6C3B6);
  static const Color outline = Color(0xFF9E8E82);
  static const Color outlineVariant = Color(0xFF51443B);

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
