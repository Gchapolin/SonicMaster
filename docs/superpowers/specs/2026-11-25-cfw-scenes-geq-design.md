# Cenas e EQ Global do CFW no SonicMaster

Data: 2026-11-25 · Status: rascunho para aprovação
Base: `docs/cfw-protocol/capture-notes.md` e `docs/cfw-protocol/cfw-app-data/cfw_eq_models.json` (MIT, com crédito).

## Intenção
Com o pedal em CFW, editar pelo app as duas cenas por preset (SC1, SC2) e o EQ Global. Com firmware de fábrica, nada muda.

## Parte A: EQ Global
- Nova seção "Global EQ" no diálogo de configurações, só com CFW: liga/desliga, modelo e os knobs do modelo.
- Modelos nesta entrega: Studio EQ, Parametric 3, Cut 24 e Tilt EQ. Os knobs, faixas, padrões e textos (por exemplo "26Hz", "Q 0.99") vêm de `cfw_eq_models.json`, copiado para `app/assets/data/`.
- Protocolo: leitura `12 3A`; escrita `11 3A <liga> <modelo> <8 bytes>`, um byte por `algId` de 0 a 7. Valores em dB vão em passos de 0,5 (byte com sinal); os demais vão como byte com sinal.
- Verificado na captura: Studio = modelo 0, Parametric 3 = modelo 1, e os padrões dos dois. **Suposição:** Cut 24 = 2 e Tilt EQ = 3 (ordem da lista do app do CFW). O teste ao vivo confirma lendo de volta; se não bater, o modelo sai da lista.
- Fora: os modelos GT EQ 1, GT EQ 2 e Bass EQ (mapeamento não capturado) e a curva desenhada (fica com o grupo "curva do EQ").

## Parte B: Cenas
- Depois de carregar um preset em pedal com CFW, o app lê os registros de cena (`12 33`) e a cena atual (`12 32`).
- No editor do módulo, só com CFW:
  - um switch **Scenes**, que inclui o módulo nas cenas;
  - um seletor **BASE / SC1 / SC2**, que troca a cena no pedal (`11 32 <cena>`);
  - com SC1 ou SC2 selecionada e o módulo nas cenas: girar um knob grava o valor só naquela cena, e um seletor **BASE / ON / OFF** define o liga/desliga do módulo na cena.
- O knob mostra o valor da cena quando ela sobrescreve o parâmetro; senão, o valor base.
- Protocolo: `11 33 <módulo> <flags> <máscaraSC1> <máscaraSC2> <float32...>`, o registro inteiro do módulo a cada mudança. Flags: bit0 módulo nas cenas, bit1/bit2 liga-desliga na SC1, bit3/bit4 na SC2. Leitura `12 33`: cabeçalho "SC", contagem, tamanho, CRC e os registros (com 4 bytes extras por registro, ignorados).
- Em BASE, tudo funciona como hoje.
- **Não verificado:** se as cenas são gravadas no preset pelo "Save" normal do pedal. O teste ao vivo confere isso num preset de teste escolhido pelo usuário; até lá, o design assume que sim.
- Fora: troca de cena por footswitch/MIDI (já é do pedal), copiar cena, e desligar um parâmetro da cena individualmente (v1 só acrescenta sobrescritas; desligar o switch Scenes limpa o módulo).

## Restrições
- Firmware de fábrica: tela e tráfego idênticos aos de hoje.
- Sem pacotes novos; visual plano (`flat_style_test.dart`); tamanhos atuais dos controles.
- Quadros conferidos byte a byte contra a captura. Testes antes do código; suíte inteira passando.
- As leituras novas entram depois das leituras de fábrica na fila e ficam quietas durante carregamentos e envios.
- Nada vai para o `origin`.
