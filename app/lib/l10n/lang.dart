/// The app's interface language: Brazilian Portuguese on a device set to any
/// Portuguese locale, English everywhere else. Effect, model and knob names
/// stay in English (they are the pedal's own names).
///
/// Each area of the app keeps its texts in its own `*_text.dart` here: an
/// abstract class with one getter per text, an English and a Portuguese
/// implementation (a missing translation does not compile), and `current`
/// picking one by [appLang].
library;

import 'dart:ui';

enum Lang { en, pt }

Lang langFor(Locale locale) => locale.languageCode == 'pt' ? Lang.pt : Lang.en;

/// The language in use, read from the device once at startup; tests set it.
// ponytail: not re-read if the device language changes while the app runs
// (iOS restarts the app on a language change); listen to
// PlatformDispatcher.onLocaleChanged if another platform needs it.
Lang appLang = langFor(PlatformDispatcher.instance.locale);
