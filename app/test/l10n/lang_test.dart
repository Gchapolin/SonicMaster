import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/l10n/common_text.dart';
import 'package:sonicmaster/l10n/lang.dart';

void main() {
  tearDown(() => appLang = Lang.en);

  test('Portuguese for any pt locale, English otherwise', () {
    expect(langFor(const Locale('pt', 'BR')), Lang.pt);
    expect(langFor(const Locale('pt')), Lang.pt);
    expect(langFor(const Locale('en', 'US')), Lang.en);
    expect(langFor(const Locale('es')), Lang.en);
  });

  test('the texts follow the app language', () {
    expect(CommonText.current.cancel, 'Cancel');

    appLang = Lang.pt;

    expect(CommonText.current.cancel, 'Cancelar');
    expect(CommonText.current.close, 'Fechar');
  });
}
