# Visual minimalista (Material 3) para o SonicMaster

Data: 2026-11-24
Status: rascunho para aprovação

## Intenção

O app que o usuário usa com o pedal (Sonicake Pocket Master / Smart Box), principalmente no iPhone em paisagem, deve ganhar um visual minimalista no estilo do Google (Material 3), no lugar do visual atual de "pedal de plástico" (gradientes, sombras, texturas, LEDs).

O pedido inicial foi o Liquid Glass da Apple. Ele foi descartado porque o Flutter instalado (3.44.2) não tem nada de Liquid Glass. Uma busca no próprio SDK (`packages/flutter/lib`) não encontrou nenhuma referência. O usuário então escolheu o minimalismo do Google.

O usuário não disse o que incomoda no visual atual além do estilo. O objetivo, portanto, é estético: o app deve ficar com cara de app moderno do Google, mantendo tudo o que já funciona com o pedal.

## Decisões do usuário

- O alvo é o app em si (Flutter, `app/lib/ui`), não a página de telas.
- Os knobs viram **knobs planos**: um arco de 270 graus que se preenche conforme o valor, com o valor em cima e o rótulo embaixo. A alternativa com slider foi mostrada e rejeitada.
- O caminho escolhido é **redesenhar os controles próprios atuais**, mantendo tamanho e comportamento. A alternativa de trocar pelos componentes de verdade do Material 3 foi rejeitada.
- A fonte continua **Oswald**. A troca para Roboto Flex foi mostrada e adiada; pode virar um passo separado depois.
- Os cartões da cadeia **mantêm o ícone SVG colorido de cada módulo** (`moduleIconColor` em `chain_view.dart`, com as cores da tela do pedal). Assim nenhuma medida do cartão muda. O mockup mostrava cartões sem ícone; nisso o documento prevalece sobre o mockup.

Mockups de referência: `docs/superpowers/specs/mockups/controles.html` (knob x slider; o usuário escolheu a versão A) e `docs/superpowers/specs/mockups/fonte-v2.html` (Oswald x Roboto Flex; o usuário escolheu a versão A). Abrir no navegador; as cores, os raios e a espessura do arco dos mockups são a referência visual.

## Decisões minhas (o usuário pode corrigir)

- Só tema escuro, como hoje.
- As cores saem de um esquema Material 3 escuro gerado a partir do laranja atual (`Palette.accent`, `0xFFEF8A24`), com `ColorScheme.fromSeed` do próprio Flutter, na variante padrão (tonalSpot). Nenhum pacote novo. Com isso a cor principal fica um pêssego claro (`#FFB77C`), e não o laranja de hoje. É a mesma cor que os mockups usaram e que o usuário viu ao escolher.
- O vermelho de erro continua o de hoje (`0xFFFF5449`), e não o papel error do Material 3.
- Parâmetros com faixa negativa (por exemplo bandas do EQ de -50 a 50, Detune, Low Pitch) preenchem o arco a partir do zero até o valor. Os que começam em zero preenchem a partir do início do arco.
- O logotipo SONICMASTER da barra de cima continua.

## Objetivos

1. Todas as telas (computador/tablet, iPhone em modo compacto e todas as janelas) ficam planas: sem gradientes, sombras internas, texturas ou brilho de LED.
2. Cada controle próprio passa a ser desenhado no equivalente visual do Material 3 (tabela abaixo).
3. As cores do app vêm de papéis do Material 3 (surface, surfaceContainer, primary, secondaryContainer, outline etc.), definidos num lugar só. As cores escritas direto nos arquivos de tela deixam de existir, exceto onde a cor carrega informação própria (por exemplo o verde de conectado).

## Fora do escopo

- Mudar tamanhos, espaçamentos ou a disposição das telas.
- Mudar comportamento: toque, arraste do knob, reordenar a cadeia, sincronia com o pedal, atalhos de teclado.
- Tema claro.
- Trocar a fonte.
- Usar `MaterialApp` ou os widgets prontos do Material (Switch, SegmentedButton, DropdownMenu etc.). O app continua em `WidgetsApp`.
- Pacotes novos.

## O que seria um fracasso mesmo funcionando

- Alguma tela do iPhone (956x440 e os outros tamanhos que os testes cobrem) passar a cortar ou estourar.
- Qualquer mudança no que o app manda para o pedal ou no jeito de tocar nos controles.
- Valores dos knobs ou textos ficarem difíceis de ler no escuro. Regra: texto principal e valores com contraste de pelo menos 7:1 contra o fundo onde aparecem, e texto secundário com pelo menos 4.5:1. Os papéis do Material 3 gerados já atendem isso (onSurface sobre surface dá cerca de 14:1).

## Restrições

- **Tamanhos fixos.** 31 dos 48 arquivos em `app/test/ui` conferem tamanhos e posições, e o `SonicMetrics` (`app/lib/ui/sonic_metrics.dart`) define as medidas dos modos regular e compacto. Cada controle redesenhado ocupa exatamente o mesmo espaço e a mesma área de toque de hoje. Esses testes devem continuar passando sem alteração de medida.
- **Testes de imagem.** `app/test/ui/page_regular_golden_test.dart` (página regular conectada e desconectada) e `app/test/ui/sonic_toggle_golden_test.dart` existem para travar o visual. Hoje eles já falham neste Mac (há diferenças salvas em `app/test/ui/failures/` desde 20/11), porque foram gerados no Linux do CI do autor (ubuntu-latest) e a renderização de fonte muda entre sistemas. Este repositório é uma cópia local, sem CI próprio. Por isso, antes de mexer no visual, os goldens são regerados neste Mac com o visual atual e commitados como ponto de partida. Assim a diferença do redesenho fica separada da diferença de sistema. Depois, são regerados de propósito com o visual novo.
- **Projeto de outra pessoa.** O `origin` é o repositório do autor original (Skyggedans/SonicMaster). O redesenho afasta esta cópia do original. Não enviar nada para o `origin`.
- Testes que conferem cores específicas (se houver) mudam junto com a cor, sem mudar o que verificam.

## Caminhos considerados

1. **Redesenhar os controles próprios (escolhido).** Trocar só o desenho (painters e decorações) de cada controle e trocar a paleta por papéis do Material 3. A favor: um controle muda o app inteiro, sem tocar em lógica nem tamanhos, e quase todos os testes continuam valendo. Contra: o Material fica imitado, sem o efeito de onda ao tocar e sem as animações prontas, e o espaçamento continua o de hoje.
2. **Trocar pelos widgets reais do Material 3**, mantendo só o knob próprio. Rejeitado: os widgets prontos têm tamanhos próprios, o layout de todas as telas se desloca, a maioria dos testes de medida quebra, e o modo compacto do iPhone precisaria ser reencaixado.
3. **Só trocar a paleta.** Descartado: o visual de plástico está nos painters (gradientes, sombras e cores escritas direto nos arquivos), então trocar só as cores não chega no visual dos mockups.

## Como cada controle fica

Os controles estão em `app/lib/ui/sonic_controls.dart`, `knob_control.dart`, `led_button.dart` e `chain_view.dart`.

| Controle | Hoje | Depois (Material 3, escuro) |
|---|---|---|
| `KnobControl` | Botão de plástico com textura e sombra | Arco de 270 graus: trilho em secondaryContainer e parte ativa em primary, pontas arredondadas, sem ponteiro nem textura. Valor e rótulo nas posições de hoje. |
| `LedButton` (ligar/desligar módulo no cartão) | Barra de LED laranja com brilho | Ponto de estado: preenchido em primary quando ligado, só contorno em outline quando desligado. A área de toque continua a mesma. |
| `SonicToggle` | Chave de plástico | Switch do Material 3: trilho primary com bolinha onPrimary quando ligado; trilho surfaceContainerHighest com borda outline e bolinha menor quando desligado. |
| `SonicSegmented` | Segmentos em relevo | Botão segmentado com contorno outline; o segmento ativo fica em secondaryContainer. |
| `SonicDropdown` e o menu dele | Campo em relevo | Campo com contorno outline e ícone de seta; o menu é uma superfície surfaceContainer com cantos arredondados, e o item ativo fica em secondaryContainer. |
| `SonicButton` | Botão de plástico | Botão tonal (secondaryContainer) ou com contorno, conforme o papel atual de cada botão. |
| `SonicIconButton` | Ícone com relevo | Ícone em onSurfaceVariant, sem fundo; o estado ativo usa primary. |
| `SonicRecess` (campos afundados, como a busca) | Afundado com sombra interna | Superfície surfaceContainerHigh, plana, com cantos arredondados. |
| `SonicSurface` e `PanelCell` | Painéis com gradiente | surfaceContainer plano, cantos maiores, sem sombra. |
| `SonicDialog` | Placa com relevo | surfaceContainerHigh, cantos de 28, sem textura. A barreira escurece o fundo como hoje. |
| `SonicSpinner` | Spinner próprio | Arco de progresso circular em primary. |
| `ModuleCard` | Cartão de pedal com gradiente, ícone SVG e LED | Cartão surfaceContainerLow, plano, com o mesmo ícone colorido no mesmo lugar e tamanho. O selecionado fica em secondaryContainer, e o desligado com opacidade reduzida. A etiqueta FS1/FS2 é texto pequeno em primary. |
| `ChainConnector`, `AmpBlockBorder`, `DragGrip` | Setas, borda tracejada e pontos | Mesmo desenho, em outlineVariant e mais discreto. |
| Barra de cima, lista lateral de presets, gaveta do iPhone | Fundos com gradiente | surface plana; o preset atual em secondaryContainer; a etiqueta P01... em primary. |

## Cores

- `Palette` (`app/lib/theme/app_colors.dart`) passa a expor os papéis do Material 3 vindos de `ColorScheme.fromSeed(seedColor: 0xFFEF8A24, brightness: dark)`. Os nomes que já carregam significado (accent, error, textos) passam a apontar para os papéis equivalentes.
- As cores, gradientes e sombras escritos direto nos arquivos de tela somem e viram papéis da paleta. Hoje são cerca de 93 cores e 41 gradientes ou sombras: `sonic_controls.dart` (34 e 24), `chain_view.dart` (18 e 3), `led_button.dart` (11 e 4), `preset_rail.dart` (11 e 1), `knob_control.dart` (10 e 6), `top_bar.dart`, `preset_browser_page.dart`, `device_dialog.dart` e `main.dart`.
- O verde de "conectado" e o vermelho de erro continuam com cor própria.

## Como conferir

- `flutter test` passa por inteiro. Os goldens regerados de propósito devem ser olhados à mão antes de aceitar.
- A captura de telas (`app/tool_screens/capture_test.dart`, fora da suíte de testes) é rodada de novo e o resultado vira uma página nova, separada da página de hoje (https://claude.ai/artifact/PLneQQkwPwHJoQn8PuBkq2), para comparar antes e depois. Nada vai para o GitHub Pages do autor.
- O app é instalado no iPhone e conferido com o pedal conectado: ligar e desligar um módulo, girar um knob, trocar de preset, abrir as configurações.

## Fica para quem implementar

- Os valores exatos de raio, espessura do arco e opacidade, dentro do estilo dos mockups.
- A ordem de trabalho entre os controles.
