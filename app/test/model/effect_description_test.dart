import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/lang.dart';
import 'package:sonicmaster/model/effect_definition.dart';

import '../support/test_assets.dart';

/// Effect descriptions in Brazilian Portuguese beside the English ones.
void main() {
  tearDown(() => appLang = Lang.en);

  test('every description has a Portuguese translation', () {
    Map<String, dynamic> read(String name) =>
        jsonDecode(File('assets/data/$name.json').readAsStringSync())
            as Map<String, dynamic>;

    final entries = <Map<String, dynamic>>[
      for (final v in read('effect_library').values) v as Map<String, dynamic>,
      for (final f in ['cfw_fx_models', 'cfw_eq_models'])
        ...(read(f)['models'] as List).cast<Map<String, dynamic>>(),
    ];
    final described = [
      for (final e in entries)
        if ((e['descriptionEn'] as String? ?? '').isNotEmpty) e,
    ];

    expect(described.length, 146 + 11 + 4);
    for (final e in described) {
      expect(
        (e['descriptionPt'] as String? ?? '').trim(),
        isNotEmpty,
        reason: e['name'] as String,
      );
    }
  });

  test('the description follows the app language', () {
    final analog = loadTestDataAssets().effects.byId(707)!;

    appLang = Lang.en;
    expect(analog.description, startsWith('Reproduces the sound'));

    appLang = Lang.pt;
    expect(analog.description, startsWith('Reproduz o som'));
    expect(analog.description, contains('Roland® SDE-3000*'));
  });

  test('Portuguese falls back to English when empty', () {
    const def = EffectDefinition(
      id: 1,
      name: 'X',
      descriptionEn: 'English',
      params: [],
    );

    appLang = Lang.pt;
    expect(def.description, 'English');
  });
}
