# Configurações do CFW no SonicMaster

Data: 2026-11-24 · Status: rascunho para aprovação
Base: captura no pedal do usuário (`docs/cfw-protocol/capture-notes.md`).

## Intenção
O usuário tem um Pocket Master com o firmware customizado (CFW 1.0.2) e quer controlar, pelo próprio app, as configurações que o CFW acrescenta. Com firmware de fábrica, nada muda.

## Escopo
- **Detectar o CFW e mostrar a versão.** A leitura `12 2A` responde com o texto "CFW1.0.2". Sem resposta, ou sem esse texto, o pedal está com firmware de fábrica.
- **Tema da tela:** Default, Amber CRT, Tube Amp, Synthwave, Stage Hi-Contrast e Game Boy.
- **Brilho (10 a 100%):** com CFW, substitui o Backlight de fábrica no diálogo.
- **Direct Monitor:** liga e desliga.
- **USB Rec:** WET, DRY DI e DI L + WET R. Com CFW, substitui o Mode Dry/Wet de fábrica.
- **Modo dos footswitches:** PRESET, STOMP e SCENE.
- **Carga do DSP:** um indicador na barra de cima, que muda de cor a partir de 85%.

## Fora do escopo
- O afinador, que fica para depois da captura das leituras com uma corda tocando.
- MIDI e cenas, que são os grupos seguintes. As chaves de MIDI e de cena do bloco são lidas, mas não aparecem na tela.

## Protocolo (capturado e verificado)
- **Leitura `12 2A`.** Resposta, depois de juntar os nibbles:
  - `12 2A 01`;
  - a versão em 16 bytes ASCII, completada com zeros;
  - 4 bytes de recursos e mais 1 byte;
  - a quantidade de pares;
  - os pares `chave, valor`.

  | Chave | Configuração |
  |---|---|
  | `01` | Tema (0 a 5) |
  | `02` | Brilho |
  | `03` | Direct Monitor |
  | `04` | USB Rec (0 WET, 1 DRY DI, 2 DI L + WET R) |
  | `06` | Modo (0 PRESET, 1 STOMP, 2 SCENE) |
  | `10` | Cena atual |
  | `11`, `12`, `15`, `16`, `17`, `27` | MIDI |
- **Escrita:** `11 2A <chave> <valor>`, montada pelo `buildSysexWriteFrame`. O brilho é a exceção: vai por `GlobalSettingWriter.dumpRecord(a0: 3, a1: 2, valor)`, como o app do CFW faz.
- **DSP:** a leitura `12 2B` responde com o percentual em 16 bits, little-endian, no 5º byte.
- Os testes comparam cada quadro gerado com o quadro capturado, byte a byte.

## Como fica na tela
- O diálogo de configurações ganha um selo "CFW 1.0.2" e três seções, que só aparecem quando o CFW é detectado:
  - **Display:** tema numa lista de escolha, brilho num knob e o ECO de hoje.
  - **I/O:** Direct Monitor num switch e USB Rec em botões segmentados. O Re-amp continua como hoje.
  - **Footswitches:** modo em botões segmentados.
- Cada controle é um dos componentes que já existem (`SonicDropdown`, `KnobControl`, `SonicToggle`, `SonicSegmented`). O valor muda na tela na hora e o comando é enviado esperando a confirmação do pedal, como as outras configurações.
- A barra de cima ganha um indicador "DSP 57%", só com CFW, atualizado no mesmo ciclo de 2 segundos que já existe (`deviceHeartbeat`).
- Com firmware de fábrica, a tela fica idêntica à de hoje.

## Restrições
- Nenhuma mudança no que o app faz com firmware de fábrica.
- Sem pacotes novos.
- Testes antes do código, e a suíte inteira passando.
- Nada é enviado para o `origin`.
