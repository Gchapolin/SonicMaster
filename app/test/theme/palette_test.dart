import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/theme/app_colors.dart';

/// WCAG contrast ratio between two opaque colors.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;

  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('the Material 3 roles match ColorScheme.fromSeed (dark tonalSpot)', () {
    final s = ColorScheme.fromSeed(
      seedColor: const Color(0xFFEF8A24),
      brightness: Brightness.dark,
    );

    expect(Palette.primary, s.primary);
    expect(Palette.onPrimary, s.onPrimary);
    expect(Palette.primaryContainer, s.primaryContainer);
    expect(Palette.onPrimaryContainer, s.onPrimaryContainer);
    expect(Palette.secondaryContainer, s.secondaryContainer);
    expect(Palette.onSecondaryContainer, s.onSecondaryContainer);
    expect(Palette.surface, s.surface);
    expect(Palette.surfaceContainerLowest, s.surfaceContainerLowest);
    expect(Palette.surfaceContainerLow, s.surfaceContainerLow);
    expect(Palette.surfaceContainer, s.surfaceContainer);
    expect(Palette.surfaceContainerHigh, s.surfaceContainerHigh);
    expect(Palette.surfaceContainerHighest, s.surfaceContainerHighest);
    expect(Palette.onSurface, s.onSurface);
    expect(Palette.onSurfaceVariant, s.onSurfaceVariant);
    expect(Palette.outline, s.outline);
    expect(Palette.outlineVariant, s.outlineVariant);
  });

  test('the legacy names point at the roles', () {
    expect(Palette.background, Palette.surface);
    expect(Palette.accent, Palette.primary);
    expect(Palette.textPrimary, Palette.onSurface);
    expect(Palette.textMuted, Palette.onSurfaceVariant);
    expect(Palette.textDim, Palette.outline);
    expect(Palette.textDescription, Palette.onSurfaceVariant);
    expect(Palette.fieldText, Palette.onSurface);
    expect(Palette.railText, Palette.onSurface);
    expect(Palette.railMuted, Palette.onSurfaceVariant);
    expect(Palette.railBorder, Palette.outlineVariant);
    expect(Palette.chainIcon, Palette.onSurfaceVariant);
    expect(Palette.chainEffect, Palette.onSurfaceVariant);
  });

  test('the colors with a meaning of their own keep today\'s values', () {
    expect(Palette.error, const Color(0xFFFF5449));
    expect(Palette.ledConnected, const Color(0xFF44FF44));
    expect(Palette.ledDisconnected, const Color(0xFFFF4444));
    expect(Palette.scrim, const Color(0x99000000));
  });

  test('text stays readable: 7:1 for main text, 4.5:1 for secondary', () {
    expect(contrast(Palette.onSurface, Palette.surface), greaterThanOrEqualTo(7));
    expect(
      contrast(Palette.onSurface, Palette.surfaceContainer),
      greaterThanOrEqualTo(7),
    );
    expect(
      contrast(Palette.onSecondaryContainer, Palette.secondaryContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(Palette.onSurfaceVariant, Palette.surfaceContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(contrast(Palette.outline, Palette.surface), greaterThanOrEqualTo(4.5));
    expect(contrast(Palette.onPrimary, Palette.primary), greaterThanOrEqualTo(4.5));
  });
}
