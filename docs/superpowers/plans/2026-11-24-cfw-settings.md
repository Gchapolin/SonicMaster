# Configurações do CFW Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** Detectar o CFW, ler e editar tema, brilho, Direct Monitor, USB Rec e modo dos footswitches, e mostrar a carga do DSP.
**Architecture:** um decodificador do bloco `12 2A` alimenta um `cfwInfoProvider` (null = firmware de fábrica). As escritas usam `buildSysexWriteFrame` / `GlobalSettingWriter`. O diálogo de configurações e a barra de cima leem o provider.
**Tech Stack:** Flutter 3.44.2, Riverpod, flutter_test.
**Spec:** `docs/superpowers/specs/2026-11-24-cfw-settings-design.md`

## Global Constraints
- Firmware de fábrica: comportamento e tela idênticos aos de hoje. Os testes existentes passam sem mudança.
- Sem pacotes novos, sem cores literais (`flat_style_test.dart`), tamanhos dos controles iguais aos de hoje.
- Quadros conferidos byte a byte contra os capturados (`docs/cfw-protocol/capture-notes.md`).

## Review Focus
- Pedal com firmware de fábrica: `12 2A` sem resposta. `cfwInfoProvider` precisa ficar null e nada do CFW pode aparecer. (Task 3)
- Bloco truncado ou com a quantidade de pares maior que os bytes disponíveis: o decodificador devolve null, sem exceção. (Task 1)
- Valor desconhecido (tema 9, USB Rec 5): a tela não quebra e mostra o valor cru ou o primeiro item. (Task 4)
- DSP acima de 100 ou leitura falhando: o indicador some ou fica limitado, sem travar o ciclo. (Task 5)
- Troca de pedal ou desconexão: as informações do CFW são limpas. (Task 3)

---

### Task 1: `CfwInfo` e decodificador do bloco `12 2A`
**Files:** Create `app/lib/model/cfw_info.dart`, `app/lib/protocol/cfw_settings_decoder.dart`, `app/test/protocol/cfw_settings_decoder_test.dart`, `app/test/fixtures/cfw_dumps.dart` (blocos reais: original, brilho 90, tema Default, cena SC1).
**Interfaces (produz):**
- `class CfwInfo { final String version; final int capabilities; final Map<int,int> settings; int get theme; int get brightness; bool get directMonitor; int get usbRec; int get pedalMode; CfwInfo copyWithSetting(int key, int value); }`
- `CfwInfo? decodeCfwSettings(List<int> bytes)`, onde `bytes` é o payload sem nibbles, começando em `12 2A`. Também `List<int>? collapseFrameHex(String frameHex)`, se o `HexCodec` existente não fizer isso.
- [ ] Testes que falham:
  - o bloco original dá `version == 'CFW1.0.2'`, theme 3, brightness 100, directMonitor true, usbRec 0, pedalMode 0, `settings[0x10] == 2`;
  - brilho 90 dá 90;
  - tema Default dá 0;
  - um bloco truncado e um bloco sem "CFW" dão null.
- [ ] Ver falhar, implementar, ver passar e fazer o commit `feat(cfw): decode the CFW settings block`.

### Task 2: Escritas do CFW
**Files:** Create `app/lib/protocol/cfw_setting_writer.dart`, `app/test/protocol/cfw_setting_writer_test.dart`.
**Interfaces:** `abstract final class CfwSettingWriter { static String setting(int key, int value); static String brightness(int percent); static const theme = 0x01, directMonitor = 0x03, usbRec = 0x04, pedalMode = 0x06; static String readSettings(); static String readDsp(); }`
- [ ] Testes que falham, comparando sem diferenciar maiúsculas de minúsculas:
  - `setting(theme, 0)` == `8080f00f000001000000040101020a00010000f7`
  - `setting(theme, 3)` == `8080f00f090001000000040101020a00010003f7`
  - `setting(directMonitor, 0)` == `8080f00d0a0001000000040101020a00030000f7`
  - `setting(usbRec, 1)` == `8080f00b060001000000040101020a00040001f7`
  - `setting(pedalMode, 1)` == `8080f0090c0001000000040101020a00060001f7`
  - `brightness(90)` == `8080f00b0800010000000a010101010003000200000000050a000000000000f7`
  - `readSettings()` == `8080f0010f0001000000020102020af7` (capturado)
  - `readDsp()` == `8080f0000d0001000000020102020bf7` (capturado)
- [ ] Ver falhar, implementar com `buildSysexWriteFrame` e `GlobalSettingWriter.dumpRecord`, ver passar e fazer o commit.

### Task 3: Leitura no `DeviceService` e `cfwInfoProvider`
**Files:** Modify `app/lib/device/device_service.dart` (`Future<String?> requestCfwSettings()`, `Future<String?> requestDspLoad()`, seguindo o padrão de `requestGlobalSettings`, casando a resposta pelo prefixo `12 2A` / `12 2B`), `app/lib/state/preset_providers.dart` (`final cfwInfoProvider = StateProvider<CfwInfo?>`, `final dspLoadProvider = StateProvider<int?>`, preenchidos em `refreshGlobalSettings` e limpos ao desconectar). Test: `app/test/state/cfw_providers_test.dart`, com uma transport falsa que responde ao `12 2A`.
- [ ] Testes que falham:
  - um pedal que responde ao `12 2A` preenche `cfwInfoProvider` com a versão;
  - um pedal mudo deixa o provider null depois do timeout;
  - desconectar limpa o provider.
- [ ] Implementar, ver passar e rodar `flutter test test/state` antes do commit.

### Task 4: Seções do CFW no diálogo de configurações
**Files:** Modify `app/lib/ui/global_settings_dialog.dart`. Test: `app/test/ui/global_settings_dialog_test.dart`.
- [ ] Testes que falham:
  - com `cfwInfoProvider` preenchido, aparecem o selo "CFW 1.0.2", "Theme", "Brightness", "Direct Monitor", "USB Rec" e "Pedal mode", e não aparecem "Backlight" nem o Mode Dry/Wet;
  - com null, a tela é igual à de hoje;
  - escolher "Game Boy" envia `setting(theme, 5)` e atualiza o provider;
  - tema desconhecido (9) não quebra.
- [ ] Implementar com os componentes existentes, rodar `dialog_phone_heights_test.dart` e `flat_style_test.dart` e fazer o commit.

### Task 5: Indicador de DSP
**Files:** Modify `app/lib/state/reconnect.dart` (`deviceHeartbeat`: com CFW, lê `requestDspLoad` e preenche `dspLoadProvider`) e `app/lib/ui/top_bar.dart` (chip "DSP n%", em `Palette.error` a partir de 85). Tests: `app/test/state/reconnect_test.dart` e `app/test/ui/top_bar_touch_test.dart` (ou um teste novo, `dsp_chip_test.dart`).
- [ ] Testes que falham:
  - com CFW e DSP 57, o chip mostra "57%";
  - com 90, o chip fica na cor de alerta;
  - sem CFW, não há chip;
  - DSP 250 aparece limitado a 100%.
- [ ] Implementar, ver passar, rodar a suíte inteira (só os goldens da página podem mudar se o chip aparecer, mas eles rodam sem CFW) e fazer o commit.

### Task 6: Conferência no aparelho
- [ ] `flutter build ios`, instalar no iPhone e no iPad, abrir as configurações com o pedal conectado por Bluetooth, trocar o tema e conferir que a tela do pedal muda. Depois voltar ao tema original.
