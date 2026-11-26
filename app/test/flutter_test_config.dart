import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Picked up by `flutter test` for every test file in this directory tree.
// Loads the bundled fonts once, so goldens and metrics use the real glyphs
// instead of the test font's solid blocks.
const _fonts = <String, List<String>>{
  'Oswald': ['assets/fonts/Oswald.ttf'],
  'Inter': ['assets/fonts/Inter.ttf'],
  'Space Grotesk': ['assets/fonts/SpaceGrotesk.ttf'],
  'JetBrains Mono': ['assets/fonts/JetBrainsMono.ttf'],
  'Share Tech Mono': ['assets/fonts/ShareTechMono.ttf'],
  'Barlow Condensed': [
    'assets/fonts/BarlowCondensed-Medium.ttf',
    'assets/fonts/BarlowCondensed-SemiBold.ttf',
    'assets/fonts/BarlowCondensed-Bold.ttf',
  ],
  'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
};

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final e in _fonts.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }
  await testMain();
}
