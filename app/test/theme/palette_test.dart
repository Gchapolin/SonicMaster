import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/theme/app_colors.dart';
import 'package:sonicmaster/theme/app_palettes.dart';

/// WCAG contrast ratio between two opaque colors.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;

  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  tearDown(() => Palette.current = appPalettes.first);

  test('Palette follows Palette.current', () {
    Palette.current = paletteById('p13');
    expect(Palette.surface, paletteById('p13').bg);
  });

  test('the Material 3 roles are the Vintage Neutral - Muted palette', () {
    // Adobe Color "Vintage Neutral - Muted" (6A736F A4A698 D9D0C7 D9AB9A
    // D98977), turned into a dark UI the way the HTML prototype does it.
    expect(Palette.primary, const Color(0xFFDF9D8E));
    expect(Palette.onPrimary, const Color(0xFF312320));
    expect(Palette.primaryContainer, const Color(0xFF7A4A40));
    expect(Palette.onPrimaryContainer, const Color(0xFFFFDAD2));
    expect(Palette.secondaryContainer, const Color(0xFF835E56));
    expect(Palette.onSecondaryContainer, const Color(0xFFFFFFFF));
    expect(Palette.surface, const Color(0xFF3E2C28));
    expect(Palette.surfaceContainerLowest, const Color(0xFF352521));
    expect(Palette.surfaceContainerLow, const Color(0xFF45322D));
    expect(Palette.surfaceContainer, const Color(0xFF4A3530));
    expect(Palette.surfaceContainerHigh, const Color(0xFF513A35));
    expect(Palette.surfaceContainerHighest, const Color(0xFF5E443E));
    expect(Palette.onSurface, const Color(0xFFF0ECE9));
    expect(Palette.onSurfaceVariant, const Color(0xFFE1D9D2));
    expect(Palette.outline, const Color(0xFFCDBEB8));
    expect(Palette.outlineVariant, const Color(0xFF694B45));
  });

  test('the surfaces step up from the window background', () {
    final steps = [
      Palette.surfaceContainerLowest,
      Palette.surface,
      Palette.surfaceContainerLow,
      Palette.surfaceContainer,
      Palette.surfaceContainerHigh,
      Palette.surfaceContainerHighest,
    ].map((c) => c.computeLuminance()).toList();
    for (var i = 1; i < steps.length; i++) {
      expect(steps[i], greaterThan(steps[i - 1]));
    }
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
    expect(
      contrast(Palette.onSurface, Palette.surface),
      greaterThanOrEqualTo(7),
    );
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
    expect(
      contrast(Palette.outline, Palette.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(Palette.outline, Palette.surfaceContainerHighest),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(Palette.onPrimary, Palette.primary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(Palette.primary, Palette.surfaceContainerHigh),
      greaterThanOrEqualTo(4.5),
    );
  });
}
