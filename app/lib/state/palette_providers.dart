import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../theme/app_palettes.dart';

const paletteKey = 'app_palette';

/// The loaded [SharedPreferences], overridden in `main()`. Null (tests, no
/// persistence) keeps whatever [Palette.current] already is.
final paletteStoreProvider = Provider<SharedPreferences?>((_) => null);

/// Id of the active palette. Unknown or missing saved ids fall back to vintage.
class PaletteIdNotifier extends StateNotifier<String> {
  PaletteIdNotifier(this._prefs) : super(Palette.current.id) {
    final prefs = _prefs;

    if (prefs != null) {
      final p = paletteById(prefs.getString(paletteKey));
      Palette.current = p;
      state = p.id;
    }
  }

  final SharedPreferences? _prefs;

  Future<void> select(String id) async {
    final p = paletteById(id);
    Palette.current = p;
    state = p.id;
    await _prefs?.setString(paletteKey, p.id);
  }
}

final paletteIdProvider = StateNotifierProvider<PaletteIdNotifier, String>(
  (ref) => PaletteIdNotifier(ref.watch(paletteStoreProvider)),
);
