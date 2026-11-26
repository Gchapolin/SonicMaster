# Redesign do protótipo no app (iPad) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Levar para o app Flutter todas as telas do iPad (layout regular) e todas as peças do protótipo HTML, com troca de paleta em tempo de execução.

**Architecture:** Cinco fases que entregam software funcionando cada uma: (A) paleta em tempo de execução e fontes; (B) peças realistas em `lib/gear/`, desenhadas com `CustomPainter` a partir de tabelas copiadas de `Peca.dc.html`; (C) tela principal regular refeita usando as peças; (D) diálogos refeitos; (E) layout compacto recebe peças e paleta. A lógica de estado (Riverpod, `preset_providers.dart`) não muda; só a camada de UI.

**Tech Stack:** Flutter (WidgetsApp, sem Material), hooks_riverpod, flutter_hooks, shared_preferences, `flutter test` com goldens.

**Spec:** `docs/superpowers/specs/2026-11-26-redesign-prototipo-design.md` (fonte visual: `docs/design/prototipo/`).

## Global Constraints

- `lib/` sem `package:flutter/material.dart` (`test/ui/widgets_app_material_free_test.dart`).
- `lib/ui/*.dart` e `lib/main.dart` sem `Gradient(`, `BoxShadow(`, `MaskFilter`, `Color(0x`, `Color.fromARGB/RGBO(` (`test/ui/flat_style_test.dart`). `lib/gear/` é a única exceção.
- Sem dependências novas no `pubspec.yaml`.
- Fontes novas (Inter, Space Grotesk, JetBrains Mono, Barlow Condensed, Share Tech Mono, todas OFL) só depois de o usuário autorizar o download.
- Textos novos em `lib/l10n/*_text.dart`, com `_Pt` e `_En`.
- Nenhuma marca, nome comercial ou logo desenhado nas peças.
- Cada task termina com `cd app && flutter test --timeout 60s` verde e um commit terminado em `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Nunca push para `origin`.
- Goldens novos em `app/test/gear/goldens/` e `app/test/ui/goldens/`; regerar só com `--update-goldens` e olhar a imagem antes de commitar.

## Review Focus

1. Modelo sem entrada nas tabelas (CFW novo, nome digitado diferente): deve virar peça genérica do tipo do módulo, nunca exceção — teste em Task 5.
2. Efeito com muitos knobs (EQ com 7, delays com 6, Studio Delay com 8): a peça grande e a mini não podem estourar nem cortar rótulos — teste em Task 7.
3. Valor de parâmetro fora de `min..max` ou com `step` fracionário vindo da pedaleira: o knob mostra o valor limitado e manda o valor arredondado ao `step` — teste em Task 12.
4. Sem preset carregado / desconectado (`fxId == null`, `def == null`): pedaleira e editor mostram o estado vazio, sem peça quebrada — teste em Task 11.
5. Paleta salva que não existe mais (id antigo em shared_preferences): volta para `vintage` — teste em Task 2.

---

## Fase A — Base

### Task 1: Paleta em tempo de execução

**Files:**
- Create: `app/lib/theme/app_palettes.dart`
- Modify: `app/lib/theme/app_colors.dart` (de `static const` para `static Color get`)
- Modify: os 7 usos de `Palette` em contexto `const` (`grep -rn "const .*Palette\." app/lib`)
- Test: `app/test/theme/app_palettes_test.dart`, `app/test/theme/palette_test.dart`

**Interfaces:**
- Produces: `class AppPalette { final String id; final String name; final List<Color> swatches; final Color bg, side, head, card, field, ctrl, line, line2, sel, text, text2, muted, ok, acc, onAcc, faint, strong, lowest, outline, accContainer, onAccContainer; }`. Os 17 primeiros vêm de `paletas.json`; os 4 últimos: para `vintage` são os valores de hoje em `app_colors.dart` (`lowest 0xFF352521`, `outline 0xFFCDBEB8`, `accContainer 0xFF7A4A40`, `onAccContainer 0xFFFFDAD2`); para as outras, `lowest` = bg com 10% de preto, `outline` = muted, `accContainer` = acc com 45% de preto, `onAccContainer` = acc com 75% de branco.
- Produces: `const List<AppPalette> appPalettes` (18 itens, valores de `docs/design/prototipo/paletas.json`, ids `vintage`, `p1`…`p17`, mesma ordem)
- Produces: `AppPalette paletteById(String? id)` (desconhecido ou null → `appPalettes.first`)
- Produces: `Palette.current` (setter/getter, padrão `appPalettes.first`); papéis M3 lidos dela: `surface=bg`, `surfaceContainerLowest=lowest`, `surfaceContainerLow=side`, `surfaceContainer=head`, `surfaceContainerHigh=card`, `surfaceContainerHighest=ctrl`, `onSurface=text`, `onSurfaceVariant=text2`, `outline=outline`, `outlineVariant=line`, `primary=acc`, `onPrimary=onAcc`, `secondaryContainer=sel`, `onSecondaryContainer=strong`, `primaryContainer=accContainer`, `onPrimaryContainer=onAccContainer`. Novos: `Palette.field`, `Palette.line2`, `Palette.ok`.

- [ ] **Step 1: Testes que falham** em `app_palettes_test.dart`:
  - `appPalettes has the 18 Adobe palettes in order`: `length == 18`, `first.id == 'vintage'`, `first.bg == Color(0xFF3E2C28)`, `first.acc == Color(0xFFDF9D8E)`, `last.name == 'Mayflower'`.
  - `every palette keeps text readable`: para cada paleta, contraste `text/sel >= 4.5`, `muted/ctrl >= 4.5`, `acc/card >= 4.5`, `onAcc/acc >= 4.5`, `text/bg >= 7`.
  - `paletteById falls back to vintage`: `paletteById('nope').id == 'vintage'`, `paletteById(null).id == 'vintage'`.
  - Em `palette_test.dart`: `Palette follows Palette.current`: após `Palette.current = paletteById('p13')`, `Palette.surface == paletteById('p13').bg`; `tearDown` volta para `appPalettes.first`.
- [ ] **Step 2:** `cd app && flutter test test/theme` → FAIL (`app_palettes.dart` não existe).
- [ ] **Step 3:** Criar `app_palettes.dart` com os 18 valores copiados de `paletas.json`; trocar `static const Color x = ...` por `static Color get x => current.<papel>` em `app_colors.dart`, mantendo `error`, `ledConnected`, `ledDisconnected`, `scrim`, `transparent`, `moduleIcon` como `const`. Tirar `const` dos 7 usos.
- [ ] **Step 4:** `flutter test test/theme` → PASS; `flutter test --timeout 60s` → PASS. Os goldens e `palette_test` não mudam: com `vintage` os papéis devolvem exatamente os valores de hoje.
- [ ] **Step 5:** Commit `feat(theme): palettes chosen at runtime`.

### Task 2: Escolha da paleta salva e aplicada

**Files:**
- Create: `app/lib/state/palette_providers.dart`
- Modify: `app/lib/main.dart` (`_AppFrame` reconstrói ao trocar)
- Test: `app/test/state/palette_providers_test.dart`

**Interfaces:**
- Consumes: `paletteById`, `Palette.current` (Task 1).
- Produces: `final paletteIdProvider = StateNotifierProvider<PaletteIdNotifier, String>`; `PaletteIdNotifier.select(String id)` grava em shared_preferences na chave `app_palette` e atualiza `Palette.current`.

- [ ] **Step 1: Testes que falham:**
  - `starts from the saved palette`: `SharedPreferences.setMockInitialValues({'app_palette': 'p13'})` → valor inicial `'p13'` e `Palette.current.id == 'p13'`.
  - `an unknown saved id falls back to vintage` (Review Focus 5): valor salvo `'roxo'` → `'vintage'`.
  - `select saves and applies`: `select('p4')` → prefs `app_palette == 'p4'`, `Palette.current.id == 'p4'`.
  - Widget test: `switching keeps open dialogs`: com um `showSonicDialog` aberto, `select('p13')` → o diálogo continua aberto e um `Text` com `TextStyle(color: Palette.onSurface)` passa a ter a cor de `p13`.
- [ ] **Step 2:** rodar → FAIL. **Step 3:** implementar; `_AppFrame` escuta `paletteIdProvider` e, ao mudar, marca toda a árvore para reconstruir (`void _rebuildAll(Element e) { e.markNeedsBuild(); e.visitChildren(_rebuildAll); }` a partir de `context as Element`), sem trocar chaves: diálogos abertos e o estado ficam como estão. **Step 4:** PASS + suíte. **Step 5:** Commit `feat(theme): remember the chosen palette`.

### Task 3: Fontes do protótipo

> Antes de começar: pedir ao usuário autorização para baixar as 5 famílias do Google Fonts (OFL), informando nomes e tamanho.

**Files:**
- Create: `app/assets/fonts/{Inter,SpaceGrotesk,JetBrainsMono,BarlowCondensed,ShareTechMono}*.ttf` + licenças OFL
- Modify: `app/pubspec.yaml` (seção `fonts:`), `app/lib/theme/app_text.dart`
- Test: `app/test/theme/app_text_test.dart`

**Interfaces:**
- Produces: em `AppText`: `ui` (Inter 13/500), `uiStrong` (Inter 15/600), `title` (Space Grotesk 22/600), `section` (Inter 11/600, letterSpacing 1, caixa alta pelo texto), `mono` (JetBrains Mono 13), `gearLabel` (Barlow Condensed 600), `meter` (Share Tech Mono 10). Os estilos atuais continuam existindo até a Fase D terminar.

- [ ] **Step 1:** Teste que falha: `the prototype fonts are declared` lê `pubspec.yaml` e espera as 5 famílias; `AppText.title.fontFamily == 'Space Grotesk'`, `AppText.mono.fontFamily == 'JetBrains Mono'`.
- [ ] **Step 2:** FAIL. **Step 3:** baixar (com permissão), declarar, criar estilos. **Step 4:** PASS + suíte. **Step 5:** Commit `feat(theme): the prototype's fonts`.

## Fase B — Peças (`lib/gear/`)

### Task 4: Tabelas das peças

**Files:**
- Create: `app/lib/gear/gear_specs.dart`
- Test: `app/test/gear/gear_specs_test.dart`

**Interfaces:**
- Produces: `enum PedalFamily { std, compact, ts, mxr, wide, round, wedge, rat, graphic, studio, rack, tape, wah, modern }`
- Produces: `enum KnobStyle { boss, black, mxr, chickenBlack, chickenCream, chickenBrown, skirt, goldcap, chrome, blackFlat, silvercap, cream, alu, white }`
- Produces: `sealed class GearSpec`; `PedalSpec(family, body, label, knob, knobNames)`, `AmpSpec(isHead, tolex, grille, panel, knob, piping, knobNames)`, `CabSpec(speakers, inch, tolex, grille, slant, piping, corners)`; `GenericSpec(kind)`.
- Produces: `const Map<String, PedalSpec> pedalSpecs` (86), `const Map<String, AmpSpec> ampSpecs` (37), `const Map<String, CabSpec> cabSpecs` (18 + `User IR 1`).
- Valores: copiados das tabelas `P`, `KN`, `A`, `AK`, `C`, `TOLEX`, `GRILLE`, `PANEL` de `docs/design/prototipo/Peca.dc.html` (cores como `Color(0xFF......)`).

- [ ] **Step 1:** Testes que falham: contagens `86/37/19`; `pedalSpecs['Scream']!.family == PedalFamily.ts`; `ampSpecs['Brit 800']!.isHead == true`; `cabSpecs['BritGN 4x12']!.slant == true` e `speakers == 4`; cada `PedalSpec.knobNames` não vazio.
- [ ] **Step 2–5:** FAIL → copiar tabelas → PASS + suíte → Commit `feat(gear): the pieces' specs from the prototype`.

### Task 5: Qual peça para cada modelo

**Files:**
- Create: `app/lib/gear/gear_lookup.dart`
- Test: `app/test/gear/gear_lookup_test.dart`

**Interfaces:**
- Consumes: Task 4.
- Produces: `enum GearKind { pedal, amp, cab }`; `GearSpec gearFor(String model, GearKind kind)` (sem entrada → `GenericSpec(kind)`); `GearKind gearKindForModule(int physId)` (3 → amp, 4 → cab, resto → pedal).

- [ ] **Step 1:** Testes que falham:
  - `every effect in the app has its own piece`: carrega `DataAssets` como em `test/data_completeness_test.dart`; para cada efeito de `effect_library.json` e cada modelo de `cfw_models.dart`, `gearFor(name, kind)` não é `GenericSpec`.
  - `an unknown model gets a generic piece` (Review Focus 1): `gearFor('Nova Coisa', GearKind.pedal) is GenericSpec`.
- [ ] **Step 2–5:** FAIL → implementar (se o teste de cobertura achar nomes faltando, acrescentar a `gear_specs.dart` com a família mais próxima e listar no commit) → PASS → Commit `feat(gear): pick the piece for each model`.

### Task 6: Primitivas de desenho

**Files:**
- Create: `app/lib/gear/paint/knob_painter.dart`, `paint/hardware.dart` (jack, porca, parafuso, LED, joia), `paint/surfaces.dart` (pintura com brilho, tolex, tela, desgaste)
- Test: `app/test/gear/paint_test.dart`, golden `knob_styles.png`

**Interfaces:**
- Produces: `class GearKnobPainter extends CustomPainter { GearKnobPainter({required KnobStyle style, required double value /*0..100*/}) }`; `void paintLed(Canvas, Offset, double size, bool on)`; `void paintJack(Canvas, Offset, double size)`; `void paintWear(Canvas, Rect, double amount /*0..1*/)`; `void paintTolex(Canvas, Rect, Color)`; `void paintGrille(Canvas, Rect, Color, {bool lightGrille})`.

- [ ] **Step 1:** Golden que falha `knob_styles` (14 knobs em grade, valores 0, 50, 100) + teste `value is clamped to 0..100`.
- [ ] **Step 2–5:** FAIL → implementar copiando gradientes de `knobLook` e helpers de `Peca.dc.html` → gerar golden, comparar visualmente com `N_Pedais` → Commit `feat(gear): knob and hardware painters`.

### Task 7: Pedais (14 famílias)

**Files:**
- Create: `app/lib/gear/pedal_piece.dart`
- Test: `app/test/gear/pedal_piece_test.dart`, golden `pedal_families.png`

**Interfaces:**
- Consumes: Tasks 4–6.
- Produces: `class PedalPiece extends StatelessWidget { PedalPiece({required PedalSpec spec, required String model, List<double?>? values, ValueChanged<(int, double)>? onKnob, VoidCallback? onSwitch, bool lit = true, double wear = 0.6}) }`; tamanho natural por família igual ao protótipo.

- [ ] **Step 1:** Testes que falham:
  - golden `pedal_families` (um pedal de cada família, `lit` true e false);
  - `dragging a knob reports its index and new value`: arrastar o 2º knob para cima → `onKnob` com índice 1 e valor maior;
  - `tapping the footswitch calls onSwitch`;
  - `eight knobs fit without overflow` (Review Focus 2): `Studio Delay` com 8 valores, sem `FlutterError` de overflow, rótulos visíveis (`find.text` para os 8 nomes).
- [ ] **Step 2–5:** FAIL → implementar → PASS → Commit `feat(gear): the 14 pedal families`.

### Task 8: Amps (combo e cabeçote)

**Files:** Create `app/lib/gear/amp_piece.dart`; Test `app/test/gear/amp_piece_test.dart`, golden `amps.png`.

**Interfaces:** Produces `class AmpPiece extends StatelessWidget { AmpPiece({required AmpSpec spec, required String model, List<double?>? values, ValueChanged<(int, double)>? onKnob, VoidCallback? onSwitch, bool lit = true, double wear = 0.6}) }`.

- [ ] **Step 1:** golden com os 37 amps (ordem de `amp_gain.dart`: clean → baixo); `the jewel light follows lit`; `knob drag on a head reports the index`; `the badge stays readable on a light grille` (cor do texto do selo escura quando `grille` é clara).
- [ ] **Step 2–5:** FAIL → implementar (tolex, tela, painel, puxador, joia facetada, jacks, toggles do cabeçote) → PASS → Commit `feat(gear): amps, combos and heads`.

### Task 9: Gabinetes e IR do usuário

**Files:** Create `app/lib/gear/cab_piece.dart`; Test `app/test/gear/cab_piece_test.dart`, golden `cabs.png`.

**Interfaces:** Produces `class CabPiece extends StatelessWidget { CabPiece({required CabSpec spec, required String model, double wear = 0.6}) }`.

- [ ] **Step 1:** golden com os 19; `a slant cab keeps its corners and piping` (sem recorte: o retângulo inteiro pintado, costura diagonal); `speaker count follows the spec` (1, 2, 4).
- [ ] **Step 2–5:** FAIL → implementar → PASS → Commit `feat(gear): cabinets and the user IR cab`.

### Task 10: Peça pronta para encaixar

**Files:** Create `app/lib/gear/gear_piece.dart`; Test `app/test/gear/gear_piece_test.dart`.

**Interfaces:**
- Consumes: Tasks 5, 7–9.
- Produces: `class GearPiece extends StatelessWidget { GearPiece({required String model, required GearKind kind, required Size fit, List<double?>? values, ValueChanged<(int, double)>? onKnob, VoidCallback? onSwitch, bool lit = true}) }` — escolhe a peça e escala com `FittedBox(fit: BoxFit.contain)` dentro de `fit`. Tamanhos do protótipo: mini pedal `Size(66,114)`, mini amp `Size(118,76)`, mini gabinete `Size(88,92)`, editor `Size(660,440)`.
- Produces: `GenericPiece` para `GenericSpec`.

- [ ] **Step 1:** `the piece never leaves its box` (para 1 modelo de cada tipo e os 3 tamanhos, `tester.getSize` ≤ `fit`); `GenericSpec draws the generic piece`.
- [ ] **Step 2–5:** FAIL → implementar → PASS → Commit `feat(gear): fitted pieces`.

## Fase C — Tela principal (layout regular)

### Task 11: Pedaleira com as peças

**Files:**
- Modify: `app/lib/ui/chain_view.dart` (`ModuleCard` em layout regular passa a mostrar `GearPiece` mini + rótulo do módulo; seleção = fundo `Palette.card` com borda `Palette.primary`; ligado/desligado → `lit`)
- Test: `app/test/ui/chain_pieces_test.dart` (já existe: estender), `chain_view_test.dart`, `chain_card_gesture_test.dart`

**Interfaces:** Consumes `GearPiece`, `gearKindForModule`; mantém `ModuleCard` com os mesmos parâmetros + `model`.

- [ ] **Step 1:** Testes: `each module shows its model's piece` (9 `GearPiece` com o modelo de `currentSelectedEffectsProvider`); `an off module draws its piece unlit`; `dragging still reorders` (o teste de gesto atual continua passando); `no preset shows empty slots` (Review Focus 4: `fxId == null` → caixa tracejada com o rótulo NR…RVB, sem `GearPiece`).
- [ ] **Step 2–5:** FAIL → implementar → PASS (atualizar `page_regular_*` goldens) → Commit `feat(ui): the pedalboard shows the pieces`.

### Task 12: Editor com a peça grande

**Files:**
- Modify: `app/lib/ui/module_editor.dart` (layout regular: linha do seletor de modelo com anterior/próximo, chip da faixa do amp, peça grande no centro)
- Create: `app/lib/ui/knob_mapping.dart`
- Test: `app/test/ui/knob_mapping_test.dart`, `module_editor_test` existentes

**Interfaces:**
- Produces: `List<EffectParameter> pieceKnobs(EffectDefinition def)` (params `WidgetType.knob`, na ordem do efeito); `double toPieceValue(EffectParameter p, num v)` (0..100, limitado); `num fromPieceValue(EffectParameter p, double v)` (arredonda ao `step`, limita a `min..max`).
- Consumes: `setParameter(ref, moduleId, algId, value)`, `toggleModule(ref, physId, isOn)`, `setEffectType(ref, moduleId, id)`.

- [ ] **Step 1:** Testes:
  - `knob values map both ways` (Review Focus 3): param `min 0 max 10 step 0.5`: `toPieceValue(p, 15) == 100`, `fromPieceValue(p, 33) == 3.5`.
  - `dragging a knob on the piece sends setParameter` (provider fake grava `algId` e valor).
  - `the footswitch on the piece toggles the module`.
  - `prev/next walk the model list` e `the amp list keeps the bands` (reusa `SonicDropdown` com `sections`).
- [ ] **Step 2–5:** FAIL → implementar → PASS → Commit `feat(ui): edit on the piece itself`.

### Task 13: Painel da direita

**Files:** Modify `app/lib/ui/module_editor.dart` (extrair `app/lib/ui/block_panel.dart`); Test `app/test/ui/block_panel_test.dart`.

**Interfaces:** Produces `class BlockPanel extends ConsumerWidget { BlockPanel(this.moduleId) }` com: Bloco ligado (`SonicToggle`), Modo Clone (só AMP, `setAmpMode`), Slots do usuário (só IR, abre `UserSlotsDialog`), Footswitch (`SonicSegmented` Nenhum/FS1/FS2, `setModuleFootswitch`), Cenas (`SceneControls`), EXP (`ExpControls`), os params `toggle`/`select`/sync, descrição do efeito. Largura 236.

- [ ] **Step 1:** Testes: `clone switch only on the amp`; `user slots button only on the cab`; `the panel lists the non-knob params` (um efeito com `select` mostra o dropdown); `the description is the effect's`.
- [ ] **Step 2–5:** FAIL → implementar → PASS → Commit `feat(ui): the block panel`.

### Task 14: Barra de cima e lista de presets

**Files:** Modify `app/lib/ui/top_bar.dart`, `dsp_chip.dart`, `preset_rail.dart`; Test: testes existentes + `top_bar_test` novo.

**Interfaces:** Barra: logo "sonic**master**" (accent no "master"), preset com anterior/próximo, VOL/BPM, TAP, medidor DSP (barra 86×6 `Palette.ok`→`Palette.primary`), bateria, ícones afinador/comunidade/aparência/ajustes, botão Salvar (`Palette.primary`), status da conexão. Lista: segmentado Fábrica/Usuário, busca, itens com id em `AppText.mono` na cor de destaque, volume geral embaixo.

- [ ] **Step 1:** Testes: `the appearance button opens the appearance dialog` (encontra o `Semantics(label: 'Aparência')`); `the DSP meter shows the load`; `the rail marks the current preset`. Atualizar goldens `page_regular_*`.
- [ ] **Step 2–5:** FAIL → implementar → PASS → Commit `feat(ui): top bar and preset list in the new style`.

### Task 15: Sem pedaleira

**Files:** Modify o estado desconectado em `app/lib/ui/preset_browser_page.dart`; Test `app/test/ui/page_shell_test.dart`.

- [ ] **Step 1:** Teste `disconnected shows the empty board and Testar demo` (9 vagas tracejadas, "Nenhuma pedaleira conectada", botão "Testar demo"); golden `page_regular_disconnected` regerado.
- [ ] **Step 2–5:** FAIL → implementar → PASS → Commit `feat(ui): the no-pedal screen`.

## Fase D — Diálogos

Cada task desta fase: **Files** = o arquivo do diálogo + seu teste; **Step 1** = os testes listados + golden do diálogo sobre a tela principal; **Steps 2–5** = FAIL → implementar como o `N_*.dc.html` indicado → PASS + suíte → commit `feat(ui): <diálogo> in the new style`.

### Task 16: Moldura dos diálogos

`app/lib/ui/sonic_controls.dart` (`SonicDialog`, `showSonicDialog`): fundo `Palette.surfaceContainerHigh`, borda 1 `Palette.line2`, raio 20, padding 24, título em `AppText.title`, sem sombra. Testes: `the dialog uses the card colour and radius 20`; `the scrim still closes it`. Os diálogos que não têm tela própria no protótipo (`unsaved_changes_dialog.dart`, `import_dialogs.dart`, `_PresetFieldsDialog`) ficam no estilo novo só por esta moldura; conferir os goldens/testes deles.

### Task 17: Conectar — `device_dialog.dart` (`N_Conectar`)
Testes: `Bluetooth/USB switch`, `the found device is selectable`, `USB with nothing found shows the empty message`.

### Task 18: Afinador — `tuner_dialog.dart` (`N_Afinador`)
Testes: `the needle follows the cents` (−50…+50 → ângulo), `in tune within 5 cents turns the note green` (`Palette.ok`), `mute switch`.

### Task 19: Salvar — `save_preset_dialog.dart` (`N_Salvar`)
Testes: `the slot menu lists all user slots in two columns without scrolling`, `picking a slot fills the name`, `name limited to 10 chars`.

### Task 20: Ajustes — `global_settings_dialog.dart` (`N_Ajustes`)
Testes: `all nine sections fit in three columns at 1180x820 without scrolling` (nenhum `Scrollable` com extensão rolável > 0), `selects open their options`, `Fazer backup agora is the primary button`.

### Task 21: Slots de IR e Clone — `user_slots_dialog.dart` (`N_Slots`)
Testes: `two columns of ten`, `each header shows its piece` (`GearPiece` `User IR 1` e `Brit 800`), `Limpar clears that slot only`.

### Task 22: Comunidade — `community_presets_dialog.dart` (`N_Comunidade`)
Testes: `each card shows its amp piece`, `Testar moves the on-pedal status to that preset`.

### Task 23: Mapa MIDI — `midi_map_dialog.dart` (`N_MapaMidi`)
Testes: `rows list with remove`, `add row form`, `status shows count of 64 and unsaved`.

### Task 24: Restaurar — `cfw_backup_section.dart` (`_RestoreConfirm`, `N_Restaurar`)
Testes: `lists what will be overwritten and what is not restored`, `warning text`, `Restaurar is the primary action`.

### Task 25: Aparência

**Files:** Create `app/lib/ui/appearance_dialog.dart`, `app/lib/l10n/appearance_text.dart`; Test `app/test/ui/appearance_dialog_test.dart`.

**Interfaces:** Consumes `appPalettes`, `paletteIdProvider.notifier.select`. Produces `Future<void> showAppearanceDialog(BuildContext)`.

Testes: `shows the 18 palettes with their five swatches in three columns`; `picking a palette recolours the app at once and saves it`; `the footer names the chosen palette`; textos pt `Aparência`, `Cor do app`, `Fechar`.

## Fase E — Fechamento

### Task 26: Layout compacto com peças e paleta

**Files:** Modify `app/lib/ui/chain_view.dart` (ramo compacto), `module_editor.dart` (ramo compacto); Test `chain_view_compact_test.dart`, `module_editor_compact_test.dart`.

- [ ] Testes: `compact chain shows mini pieces`, `compact editor shows the piece fitted to the width`, overflow tests existentes continuam passando. Commit `feat(ui): pieces in the compact layout`.

### Task 27: Verificação no iPad

- [ ] `cd app && flutter test --timeout 60s` → tudo verde.
- [ ] Build e instalação: `flutter build ios --release`, `xcrun devicectl device install app --device 00008120-00016DDE0A42201E build/ios/iphoneos/Runner.app`; abrir em modo demo, percorrer tela principal, cada diálogo e 3 paletas (vintage, p13, p16), comparando com `docs/design/prototipo/`.
- [ ] Anotar diferenças visuais encontradas como tasks novas; nada de push.
