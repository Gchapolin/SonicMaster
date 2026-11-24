# Visual minimalista (Material 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesenhar os controles próprios do SonicMaster no estilo plano do Material 3 escuro, sem mudar tamanho, posição nem comportamento de nada.

**Architecture:** As cores do Material 3 entram como constantes na `Palette` (`app/lib/theme/app_colors.dart`), verificadas contra `ColorScheme.fromSeed` num teste. Cada controle troca só o desenho (painters, decorações) para usar esses papéis. Um teste de guarda (`flat_style_test.dart`) varre o código-fonte de cada classe já redesenhada e falha se ela ainda tiver gradiente, sombra, blur ou cor escrita direto. Esse teste é o "teste que falha primeiro" de cada tarefa visual.

**Tech Stack:** Flutter 3.44.2, Dart, `flutter_test` (inclui o matcher `paints`), Riverpod. App em `WidgetsApp`, sem Material.

**Spec:** `docs/superpowers/specs/2026-11-24-visual-minimalista-material-design.md`

## Global Constraints

- Nenhum controle muda de tamanho, posição ou área de toque. Os testes de medida em `app/test/ui` continuam passando sem alterar números.
- Comportamento intacto: toque, arraste do knob, reordenar a cadeia, sincronia com o pedal, atalhos.
- Só tema escuro. Fonte Oswald. Sem pacotes novos. Sem `MaterialApp` nem widgets do Material.
- `lib/` não importa `package:flutter/material.dart` por causa deste trabalho. `ColorScheme.fromSeed` só aparece em teste.
- Esquema: `ColorScheme.fromSeed(seedColor: Color(0xFFEF8A24), brightness: Brightness.dark)`, variante padrão (tonalSpot).
- Vermelho de erro continua `0xFFFF5449`. Verde de conectado (`ledConnected`, `0xFF44FF44`) e vermelho de desconectado (`ledDisconnected`, `0xFFFF4444`) continuam. As cores por módulo (`moduleIconColor` em `chain_view.dart`) e os ícones SVG dos cartões continuam.
- Contraste: texto principal e valores com pelo menos 7:1 contra o fundo; texto secundário com pelo menos 4.5:1.
- Referência visual: `docs/superpowers/specs/mockups/controles.html` (versão A) e `fonte-v2.html` (versão A).
- Nada é enviado para o `origin` (repositório do autor original).
- Da Tarefa 2 até a Tarefa 10, os dois goldens da página (`page_regular_*.png`) falham de propósito, porque o visual está mudando. Eles são regerados uma única vez, na Tarefa 10. Nas tarefas do meio, rodar os testes listados em cada uma, não a suíte inteira.
- Cor nova em código de tela só via `Palette` (inclusive `Palette.x.withValues(alpha: ...)`), nunca `Color(0x...)`.

## Review Focus

- Valor do knob fora de `min..max` (o pedal pode mandar algo inesperado) ou `min == max`: o arco deve ficar limitado ao trilho, sem NaN e sem quebrar o desenho. Teste na Tarefa 3.
- Parâmetro com faixa negativa que termina em zero (Low Pitch, -24 a 0): o arco deve encher do valor até o fim do trilho, não do começo. Teste na Tarefa 3.
- Módulo desligado (FX2 no preset "Rust Lemon"): precisa continuar visivelmente diferente de um ligado e de um selecionado. Teste na Tarefa 8.
- Texto sobre as superfícies novas (preset atual, etiqueta P01, valores): contraste dentro da regra. Teste na Tarefa 2.
- Tela do iPhone nos tamanhos que os testes cobrem (956x440 e os de `dialog_phone_heights_test.dart`): nada corta nem estoura depois do redesenho. Coberto pelos testes de medida existentes, rodados em todas as tarefas e de novo na Tarefa 10.

---

### Task 1: Ponto de partida dos goldens neste Mac

Os três goldens já falham neste Mac porque foram gerados no Linux. Esta tarefa regera com o visual **atual**, para a diferença do redesenho ficar separada da diferença de sistema.

**Files:**
- Modify: `app/test/ui/goldens/page_regular_1280x800.png`, `page_regular_disconnected_1280x800.png`, `sonic_toggle.png`
- Add: `docs/superpowers/specs/2026-11-24-visual-minimalista-material-design.md`, `docs/superpowers/specs/mockups/*.html`, este plano

- [ ] **Step 1: Confirmar a falha atual**

Run: `cd app && flutter test test/ui/page_regular_golden_test.dart test/ui/sonic_toggle_golden_test.dart`
Expected: FAIL nos três goldens (diferença de pixels).

- [ ] **Step 2: Regerar com o visual atual**

Run: `cd app && flutter test test/ui/page_regular_golden_test.dart test/ui/sonic_toggle_golden_test.dart --update-goldens`
Depois abrir as três PNGs e conferir que mostram o visual de hoje (plástico, laranja), sem nada quebrado.

- [ ] **Step 3: Rodar a suíte inteira**

Run: `cd app && flutter test`
Expected: tudo passa.

- [ ] **Step 4: Commit**

```bash
git add app/test/ui/goldens docs/superpowers
git commit -m "test: regenerate goldens on macOS as baseline; add redesign spec and plan"
```

---

### Task 2: Papéis do Material 3 na `Palette`

**Files:**
- Modify: `app/lib/theme/app_colors.dart`
- Create: `app/test/theme/palette_test.dart`

**Interfaces:**
- Produces (todas `static const Color` em `Palette`):
  `primary 0xFFFFB77C`, `onPrimary 0xFF4D2600`, `primaryContainer 0xFF6C3A06`, `onPrimaryContainer 0xFFFFDCC3`, `secondaryContainer 0xFF5A422E`, `onSecondaryContainer 0xFFFFDCC3`, `surface 0xFF19120C`, `surfaceContainerLowest 0xFF140D08`, `surfaceContainerLow 0xFF221A14`, `surfaceContainer 0xFF261E18`, `surfaceContainerHigh 0xFF312822`, `surfaceContainerHighest 0xFF3C332C`, `onSurface 0xFFEFE0D6`, `onSurfaceVariant 0xFFD6C3B6`, `outline 0xFF9E8E82`, `outlineVariant 0xFF51443B`.
- Os nomes antigos continuam existindo, apontando para os papéis: `background = surface`, `accent = primary`, `textPrimary = onSurface`, `textMuted = onSurfaceVariant`, `textDim = outline`, `textDescription = onSurfaceVariant`, `fieldText = onSurface`, `railText = onSurface`, `railMuted = onSurfaceVariant`, `railBorder = outlineVariant`, `chainIcon = onSurfaceVariant`, `chainEffect = onSurfaceVariant`. `error`, `ledConnected`, `ledDisconnected` e `scrim` ficam com os valores de hoje.

- [ ] **Step 1: Escrever os testes que falham** (em `palette_test.dart`; o teste pode importar `material.dart`)

```dart
test('papéis batem com ColorScheme.fromSeed tonalSpot escuro', () {
  final s = ColorScheme.fromSeed(seedColor: const Color(0xFFEF8A24), brightness: Brightness.dark);
  expect(Palette.primary, s.primary);
  expect(Palette.secondaryContainer, s.secondaryContainer);
  expect(Palette.surface, s.surface);
  expect(Palette.surfaceContainerLow, s.surfaceContainerLow);
  expect(Palette.surfaceContainer, s.surfaceContainer);
  expect(Palette.surfaceContainerHigh, s.surfaceContainerHigh);
  expect(Palette.onSurface, s.onSurface);
  expect(Palette.onSurfaceVariant, s.onSurfaceVariant);
  expect(Palette.outline, s.outline);
  expect(Palette.outlineVariant, s.outlineVariant);
  // ... um expect por papel da lista de Interfaces
});

test('nomes antigos apontam para os papéis', () {
  expect(Palette.accent, Palette.primary);
  expect(Palette.background, Palette.surface);
  expect(Palette.textPrimary, Palette.onSurface);
  expect(Palette.error, const Color(0xFFFF5449));
});

test('contraste dentro da regra', () {
  // contrast(a, b) = (L1 + 0.05) / (L2 + 0.05), com Color.computeLuminance()
  expect(contrast(Palette.onSurface, Palette.surface), greaterThanOrEqualTo(7));
  expect(contrast(Palette.onSurface, Palette.surfaceContainer), greaterThanOrEqualTo(7));
  expect(contrast(Palette.onSecondaryContainer, Palette.secondaryContainer), greaterThanOrEqualTo(4.5));
  expect(contrast(Palette.onSurfaceVariant, Palette.surfaceContainer), greaterThanOrEqualTo(4.5));
  expect(contrast(Palette.outline, Palette.surface), greaterThanOrEqualTo(4.5));
  expect(contrast(Palette.onPrimary, Palette.primary), greaterThanOrEqualTo(4.5));
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd app && flutter test test/theme/palette_test.dart`
Expected: FAIL (`Palette.primary` não existe).

- [ ] **Step 3: Adicionar os papéis e remapear os nomes antigos em `app_colors.dart`**

Manter `abstract final class Palette` e `static const`. Atualizar o comentário da classe: a paleta agora é o esquema Material 3 escuro, e gradientes e sombras locais não existem mais.

- [ ] **Step 4: Rodar o teste novo e a suíte**

Run: `cd app && flutter test test/theme/palette_test.dart`, depois `cd app && flutter test`
Expected: `palette_test` passa. Na suíte, só os três goldens podem falhar (as cores mudaram). Qualquer outra falha é investigada antes de seguir.

- [ ] **Step 5: Commit**

```bash
git add app/lib/theme/app_colors.dart app/test/theme/palette_test.dart
git commit -m "feat(theme): Material 3 dark roles from the app's orange seed"
```

---

### Task 3: Knob plano e teste de guarda

**Files:**
- Modify: `app/lib/ui/knob_control.dart` (`_KnobPainter` e onde ele é criado)
- Create: `app/test/ui/flat_style_test.dart`
- Test: `app/test/ui/knob_control_test.dart` (adicionar casos)

**Interfaces:**
- Produces: `({double from, double to}) knobArc(num value, num min, num max)` em `knob_control.dart` (top-level, público para teste). Frações do trilho de 0 a 1. A âncora é a posição do zero, `((0 - min) / (max - min)).clamp(0, 1)`. Depois `from = min(âncora, f)` e `to = max(âncora, f)`, com `f` sendo o valor normalizado e limitado a 0..1. Se `max == min`, retorna `(from: 0, to: 0)`.
- Produces: `flat_style_test.dart` com `const flatClasses = <String, List<String>>{...}` (arquivo → classes), um helper `String classSource(String path, String className)` (do `class Name` até o próximo `\nclass ` ou o fim do arquivo) e um teste por entrada que falha se o trecho tiver `Gradient(`, `BoxShadow(`, `MaskFilter` ou `Color(0x`. As tarefas seguintes só acrescentam entradas a `flatClasses`.

- [ ] **Step 1: Escrever os testes que falham**

Em `knob_control_test.dart`:
```dart
test('knobArc unipolar', () => expect(knobArc(50, 0, 100), (from: 0.0, to: 0.5)));
test('knobArc bipolar no zero', () => expect(knobArc(0, -50, 50), (from: 0.5, to: 0.5)));
test('knobArc bipolar positivo', () => expect(knobArc(25, -50, 50), (from: 0.5, to: 0.75)));
test('knobArc bipolar no mínimo', () => expect(knobArc(-50, -50, 50), (from: 0.0, to: 0.5)));
test('knobArc faixa que termina em zero', () => expect(knobArc(-12, -24, 0), (from: 0.5, to: 1.0)));
test('knobArc fora da faixa é limitado', () => expect(knobArc(150, 0, 100), (from: 0.0, to: 1.0)));
test('knobArc com min == max', () => expect(knobArc(5, 5, 5), (from: 0.0, to: 0.0)));
testWidgets('knob desenha trilho e arco ativo, sem sombra', (tester) async {
  // KnobControl(value: 70, min: 0, max: 100, ...) num WidgetsApp
  expect(find.descendant(of: find.byType(KnobControl), matching: find.byType(CustomPaint)).first,
      paints..arc(color: Palette.secondaryContainer)..arc(color: Palette.primary));
});
```
Em `flat_style_test.dart`, a primeira entrada: `'lib/ui/knob_control.dart': ['KnobControl', '_KnobPainter']`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd app && flutter test test/ui/knob_control_test.dart test/ui/flat_style_test.dart`
Expected: FAIL (`knobArc` não existe; `_KnobPainter` tem `BoxShadow(` e `MaskFilter`).

- [ ] **Step 3: Implementar `knobArc` e trocar `_KnobPainter`**

O painter recebe `from`, `to` e o `size` de hoje. Ele desenha só dois arcos, com centro `s/2`, raio `0.39 * s`, traço `0.11 * s` e `StrokeCap.round`. O trilho começa em 135 graus e varre 270 graus, na cor `Palette.secondaryContainer`. O arco ativo, de `from` a `to`, sai na cor `Palette.primary` e é omitido quando `from == to`. Não há sombra, textura, gota nem ponteiro. Valor, rótulo, gestos e `size` não mudam.

- [ ] **Step 4: Rodar e ver passar, junto com os testes de knob**

Run: `cd app && flutter test test/ui/knob_control_test.dart test/ui/knob_touch_test.dart test/ui/flat_style_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/ui/knob_control.dart app/test/ui/knob_control_test.dart app/test/ui/flat_style_test.dart
git commit -m "feat(ui): flat Material arc knob; add flat-style guard test"
```

---

### Task 4: LED do cartão vira ponto de estado

**Files:**
- Modify: `app/lib/ui/led_button.dart`
- Test: `app/test/ui/led_button_test.dart`, `app/test/ui/flat_style_test.dart`

**Interfaces:**
- Consumes: `Palette.primary`, `Palette.outline` (Tarefa 2).
- `LedButton({required bool isOn, required String label, VoidCallback? onTap, double height = 26})` não muda, nem o tamanho que ocupa.

- [ ] **Step 1: Escrever os testes que falham**

Em `led_button_test.dart`: `isOn: true` resulta em `paints..circle(color: Palette.primary, style: PaintingStyle.fill)`, e `isOn: false` em `paints..circle(color: Palette.outline, style: PaintingStyle.stroke)`. Em `flat_style_test.dart`, adicionar `'lib/ui/led_button.dart': ['LedButton']`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd app && flutter test test/ui/led_button_test.dart test/ui/flat_style_test.dart`
Expected: FAIL.

- [ ] **Step 3: Desenhar o ponto**

Desenhar com um `CustomPaint` no mesmo espaço de hoje: um círculo de diâmetro `height * 0.4`, centrado. Quando ligado, preenchido em `primary`. Quando desligado, um anel de 1.5 px em `outline`. A área de toque e o `onTap` ficam iguais.

- [ ] **Step 4: Rodar e ver passar**

Run: `cd app && flutter test test/ui/led_button_test.dart test/ui/module_card_test.dart test/ui/chain_card_gesture_test.dart test/ui/flat_style_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/ui/led_button.dart app/test/ui/led_button_test.dart app/test/ui/flat_style_test.dart
git commit -m "feat(ui): module LED becomes a flat status dot"
```

---

### Task 5: Switch (`SonicToggle`)

**Files:**
- Modify: `app/lib/ui/sonic_controls.dart` (`SonicToggle`, `_ToggleKnobPainter`)
- Modify: `app/test/ui/goldens/sonic_toggle.png`
- Test: `app/test/ui/flat_style_test.dart`

- [ ] **Step 1: Adicionar a guarda que falha**

Adicionar `'lib/ui/sonic_controls.dart': ['SonicToggle', '_ToggleKnobPainter']` a `flatClasses`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd app && flutter test test/ui/flat_style_test.dart`
Expected: FAIL.

- [ ] **Step 3: Redesenhar no mesmo tamanho**

Quando ligado: trilho em pílula `primary` e bolinha `onPrimary` com diâmetro de 75% da altura, encostada à direita. Quando desligado: trilho `surfaceContainerHighest` com borda de 2 px em `outline` e bolinha `outline` com diâmetro de 50% da altura, à esquerda. A animação de hoje continua, só que entre esses estados.

- [ ] **Step 4: Regerar o golden do toggle e conferir à mão**

Run: `cd app && flutter test test/ui/sonic_toggle_golden_test.dart --update-goldens && flutter test test/ui/flat_style_test.dart test/ui/global_settings_dialog_test.dart`
Expected: PASS. Abrir `goldens/sonic_toggle.png` e comparar com o switch de `mockups/controles.html`.

- [ ] **Step 5: Commit**

```bash
git add app/lib/ui/sonic_controls.dart app/test/ui/goldens/sonic_toggle.png app/test/ui/flat_style_test.dart
git commit -m "feat(ui): Material 3 style switch"
```

---

### Task 6: Botões, segmentados e lista de escolha

**Files:**
- Modify: `app/lib/ui/sonic_controls.dart` (`SonicButton`, `_SonicButtonPainter`, `SonicSegmented`, `_Segment`, `SonicDropdown`, `_DropdownTrigger`, `_DropdownMenu`, `_SonicMenuItem`, `SonicIconButton`)
- Test: `app/test/ui/flat_style_test.dart`

- [ ] **Step 1: Adicionar a guarda que falha** com essas nove classes na entrada de `sonic_controls.dart`.
- [ ] **Step 2: Rodar e ver falhar.** Run: `cd app && flutter test test/ui/flat_style_test.dart`. Expected: FAIL.
- [ ] **Step 3: Redesenhar.** As regras:
  - **Segmentado:** borda de 1 px em `outline`, raio igual a metade da altura e divisórias em `outline`. O segmento ativo fica em `secondaryContainer` com texto `onSecondaryContainer`, e os outros com texto `onSurface`.
  - **Lista de escolha:**
    - O gatilho tem borda de 1 px em `outline`, raio 8, texto `onSurface` e seta `onSurfaceVariant`.
    - O menu é uma superfície `surfaceContainer` com raio 12, sem sombra. O item ativo fica em `secondaryContainer`.
  - **Botão (`SonicButton`):** com `isAccent: true`, fica em `primary` com texto `onPrimary`. Senão, `secondaryContainer` com texto `onSecondaryContainer`. Raio igual a metade da altura. Desabilitado (`onPressed == null`): fundo e texto em `Palette.onSurface.withValues(alpha: 0.12)` e `alpha: 0.38`, respectivamente. O estado pressionado (`isDown`) escurece o fundo em 8% (`Color.alphaBlend` com `onSurface` a 8%).
  - **Botão de ícone (`SonicIconButton`):** sem fundo. Sem `color` passado, o ícone fica em `onSurfaceVariant`. Com `color` passado, usa a cor de quem chamou.
- [ ] **Step 4: Rodar e ver passar.** Run: `cd app && flutter test test/ui/flat_style_test.dart test/ui/sonic_dropdown_test.dart test/ui/module_editor_dropdown_test.dart test/ui/top_bar_touch_test.dart test/ui/save_preset_dialog_test.dart test/ui/unsaved_changes_dialog_test.dart test/ui/widgets_app_material_free_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit**: `git commit -am "feat(ui): flat buttons, segmented control and dropdown"`

---

### Task 7: Superfícies, janelas e spinner

**Files:**
- Modify: `app/lib/ui/sonic_controls.dart` (`SonicRecess`, `_RecessPainter`, `SonicSurface`, `PanelCell`, `SonicDialog`, `SonicSpinner`, `_SpinnerPainter`, `DragGrip`)
- Test: `app/test/ui/flat_style_test.dart`

- [ ] **Step 1: Adicionar a guarda que falha** com essas oito classes.
- [ ] **Step 2: Rodar e ver falhar.** Expected: FAIL.
- [ ] **Step 3: Redesenhar.** As regras:
  - **`SonicRecess`:** `surfaceContainerHigh`, raio 12, sem sombra interna.
  - **`SonicSurface`:** `surfaceContainer`, raio 24.
  - **`PanelCell`:** `surfaceContainer`, raio 16.
  - **`SonicDialog`:** `surfaceContainerHigh`, raio 28. A barreira continua `Palette.scrim`.
  - **`SonicSpinner`:** arco de progresso em `primary`, com a mesma espessura de hoje e sem trilho.
  - **`DragGrip`:** pontos em `outlineVariant`.
- [ ] **Step 4: Rodar e ver passar.** Run: `cd app && flutter test test/ui/flat_style_test.dart test/ui/sonic_dialog_test.dart test/ui/dialog_phone_heights_test.dart test/ui/panel_cell_metrics_test.dart test/ui/sonic_field_test.dart test/ui/device_dialog_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit**: `git commit -am "feat(ui): flat surfaces, dialogs and spinner"`

---

### Task 8: Cadeia de efeitos

**Files:**
- Modify: `app/lib/ui/chain_view.dart` (`ModuleCard`, `_FsBadge`, `ChainConnector`, `AmpBlockBorder`, `_DashPainter`). `moduleIconColor` fica como está.
- Test: `app/test/ui/module_card_test.dart`, `app/test/ui/flat_style_test.dart`

- [ ] **Step 1: Escrever os testes que falham**

Adicionar as cinco classes à guarda. Em `module_card_test.dart`, cobrir três estados:
- Cartão selecionado: o `DecoratedBox` do cartão tem `color: Palette.secondaryContainer`.
- Cartão não selecionado e ligado: `color: Palette.surfaceContainerLow`.
- Cartão desligado: o conteúdo (rótulo e ícone) fica sob um `Opacity(opacity: 0.5)`.

O ícone SVG continua presente, com a mesma cor de `moduleIconColor`.

- [ ] **Step 2: Rodar e ver falhar.** Expected: FAIL.
- [ ] **Step 3: Redesenhar.** As regras:
  - **Cartão:** plano, raio 12, sem borda laranja de seleção. O ícone, o rótulo e o nome do efeito ficam no lugar e no tamanho de hoje.
  - **`_FsBadge`:** só texto em `primary`, sem fundo, na posição de hoje.
  - **`ChainConnector`:** em `outlineVariant`.
  - **`AmpBlockBorder`:** tracejado de 1 px em `outlineVariant`.
- [ ] **Step 4: Rodar e ver passar.** Run: `cd app && flutter test test/ui/module_card_test.dart test/ui/chain_view_test.dart test/ui/chain_view_compact_test.dart test/ui/chain_pieces_test.dart test/ui/chain_card_gesture_test.dart test/ui/flat_style_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit**: `git commit -am "feat(ui): flat chain cards keeping module icons"`

---

### Task 9: Barra de cima, lista de presets e moldura

**Files:**
- Modify: `app/lib/ui/top_bar.dart` (`TopBar`, `_LogoZone`, `_PresetWell`), `app/lib/ui/preset_rail.dart` (todas as classes), `app/lib/ui/preset_browser_page.dart` (`PresetBrowserPage`, `_ConsoleResizeHandle`), `app/lib/ui/device_dialog.dart` (`_DeviceRow`), `app/lib/main.dart` (`_AppFrame`)
- Test: `app/test/ui/flat_style_test.dart`

- [ ] **Step 1: Adicionar a guarda que falha** com essas classes. `main.dart` entra como `'lib/main.dart': ['_AppFrame']`.
- [ ] **Step 2: Rodar e ver falhar.** Expected: FAIL.
- [ ] **Step 3: Redesenhar.** As regras:
  - **Fundos:** a barra, a lista lateral, a gaveta e a página usam `surface`, com divisórias de 1 px em `outlineVariant`.
  - **`_PresetWell`:** `surfaceContainerLow`, raio 12.
  - **Lista de presets:**
    - O `PresetChip` fica em `surfaceContainerLow`. O preset atual fica em `secondaryContainer` com texto `onSecondaryContainer`, sem borda laranja.
    - A etiqueta P01 fica em `primary` com texto `onPrimary`.
    - O `RailTab` (FACTORY/USER) segue a regra do segmentado da Tarefa 6.
  - **`_DeviceRow`:** `surfaceContainerLow`; a linha selecionada fica em `secondaryContainer`.
  - **`_AppFrame`:** fundo `Palette.surface`.
  - **Logotipo:** o SVG do SONICMASTER continua.
- [ ] **Step 4: Rodar e ver passar.** Run: `cd app && flutter test test/ui/flat_style_test.dart test/ui/preset_rail_test.dart test/ui/rail_widgets_test.dart test/ui/preset_drawer_test.dart test/ui/top_bar_touch_test.dart test/ui/app_frame_test.dart test/ui/device_dialog_test.dart test/ui/page_shell_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit**: `git commit -am "feat(ui): flat top bar, preset rail and app frame"`

---

### Task 10: Fechamento e conferência

**Files:**
- Modify: `app/test/ui/flat_style_test.dart`, `app/test/ui/goldens/page_regular_*.png`

- [ ] **Step 1: Trocar a guarda por uma varredura completa.** Em vez da lista `flatClasses`, o teste encontra todas as classes de `lib/ui/*.dart` e de `lib/main.dart` e aplica a mesma regra. Só `moduleIconColor` fica de fora, porque é top-level e não é classe. Run: `cd app && flutter test test/ui/flat_style_test.dart`. Expected: PASS. Se falhar, a classe apontada ainda tem estilo antigo: corrigir seguindo as regras da tarefa equivalente.
- [ ] **Step 2: Regerar os goldens da página e olhar à mão.** Run: `cd app && flutter test test/ui/page_regular_golden_test.dart --update-goldens`. Abrir as duas PNGs e comparar com `mockups/controles.html`.
- [ ] **Step 3: Suíte inteira.** Run: `cd app && flutter test`. Expected: tudo passa.
- [ ] **Step 4: Commit**: `git commit -am "test: full flat-style guard; regenerate page goldens with new look"`
- [ ] **Step 5: Página de antes e depois.** Rodar `app/tool_screens/capture_test.dart` (comando no topo do arquivo) num diretório novo e publicar as 21 telas como uma página nova, sem substituir https://claude.ai/artifact/PLneQQkwPwHJoQn8PuBkq2.
- [ ] **Step 6: Instalar no iPhone** (`flutter build ios --release`, depois `xcrun devicectl device install app`) e pedir ao usuário para conferir com o pedal: ligar e desligar um módulo, girar um knob, trocar de preset e abrir as configurações.
