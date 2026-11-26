# Redesign do app a partir do protótipo HTML — design

Data: 2026-11-26. Projeto: `app/` (Flutter, iPad primeiro).

## Intenção

O protótipo HTML aprovado ao longo da sessão de 2026-11-25/26 vira o visual
do app no iPad. Interface mínima e plana em volta; amps, gabinetes e pedais
desenhados de forma realista, cada modelo parecido com o equipamento real em
que se inspira (sem marcas nem logos). A cor da interface vem de 18 paletas
do Adobe Color ("Neutral Vintage"), escolhidas em um diálogo "Aparência".

## Fonte de verdade

`docs/design/prototipo/` (cópia do artifact
https://claude.ai/artifact/Kh2fsakuPNEiLutLAWbLh2, página "Novo design"):

| Arquivo | O que define |
|---|---|
| `Peca.dc.html` | Desenho de cada peça: tabelas `P` (86 pedais: família, cor, cor do texto, estilo de knob), `KN` (nomes dos knobs por pedal), `A` (37 amps: combo/cabeçote, tolex, tela, painel, knob, friso), `AK` (knobs dos amps), `C` (18 gabinetes: falantes, polegadas, tolex, tela, slant, friso, cantoneiras), 14 famílias de pedal, 14 estilos de knob, desgaste (`wear`), `lit` |
| `N_Principal.dc.html` | Tela principal: barra de cima, lista de presets, pedaleira, editor com a peça grande, painel da direita, diálogo Aparência, descrições (`DESC`) |
| `N_Inicio`, `N_Conectar`, `N_Afinador`, `N_Salvar`, `N_Ajustes`, `N_Slots`, `N_Comunidade`, `N_MapaMidi`, `N_Restaurar` | Cada tela e diálogo, já sobre a tela principal escurecida |
| `N_Amps`, `N_Gabinetes`, `N_Pedais` | Catálogo visual de todas as peças (referência para os testes de imagem) |
| `paletas.json` | As 18 paletas: nome, 5 cores originais (`sw`) e os 17 papéis de cor (`c`) na ordem bg, side, head, card, field, ctrl, line, line2, sel, text, text2, muted, ok, acc, onacc, faint, strong |

## Objetivos

1. Todas as telas e diálogos do iPad em layout regular (paisagem) iguais ao protótipo.
2. Todas as peças: 86 pedais, 37 amps, 18 gabinetes + IR do usuário, interativas
   (knob arrasta, footswitch liga/desliga, LED acende).
3. Diálogo Aparência com as 18 paletas, troca ao vivo, salva no aparelho.
4. Nada que funciona hoje deixa de funcionar: reordenar a cadeia arrastando,
   footswitches, cenas, EXP, tap tempo, slots de IR/Clone, CFW, backup.

## Não objetivos

- Layout de celular (`N_Celular`): fora deste trabalho.
- Redesenhar o layout compacto (iPad em pé): ele ganha as peças e a paleta,
  mas mantém a estrutura atual.
- App web do CFW, protocolo, firmware: nada muda.

## Restrições

- `lib/` continua sem `package:flutter/material.dart` (`widgets_app_material_free_test`).
- Sem dependências novas no `pubspec.yaml` (shared_preferences e hooks_riverpod já existem).
- Fontes novas são arquivos de asset (licença OFL) e precisam de download: só com permissão do usuário.
- Textos em pt-BR e en pelos `*_text.dart` de `lib/l10n/`.
- Sem marcas, nomes comerciais ou logos nas peças.
- Todo código novo com teste; suíte completa verde antes de cada commit.

## Decisões (marcadas as que são minhas)

- **Cores em tempo de execução** (minha, afeta arquitetura): `Palette` deixa de ser
  um conjunto de `const` e passa a ler a paleta atual; quem usa `Palette.x`
  continua igual, mas os 7 usos em contexto `const` perdem o `const`.
- **Peças fora de `lib/ui/`** (minha): ficam em `lib/gear/`. A regra plana de
  `flat_style_test` (sem gradiente, sombra ou cor literal) continua valendo para
  `lib/ui/`; as peças precisam de gradientes e sombras para parecer reais.
- **Diálogos sem sombra** (minha): o protótipo tem sombra nos diálogos; o app
  mantém a regra plana em `lib/ui/` e usa só a borda.
- **Knobs na peça** (minha): parâmetros do tipo `knob` ficam na peça, na ordem do
  efeito. `toggle`, `select`, `eqBand` e o seletor de sincronia ficam no painel
  da direita. O EQ continua com a curva e os faders atuais abaixo da peça.
- **Desgaste** (minha): fixo em 60%, como no protótipo; sem controle na interface.

## Peças: como o app escolhe o desenho

Nome do modelo (o mesmo de `effect_library.json` e `cfw_models.dart`) → tabela
`P`, `A` ou `C`. Modelo sem entrada → peça genérica do tipo do módulo (pedal
cinza, amp cinza, gabinete cinza), nunca erro.
