# Cenas e EQ Global do CFW Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** EQ Global (4 modelos) no diálogo de configurações e cenas SC1/SC2 no editor de módulo, só em pedais com CFW.
**Architecture:** codecs puros (`cfw_geq_codec.dart`, `cfw_scene_codec.dart`) testados contra a captura; providers em `cfw_providers.dart`; UI lê os providers. Padrões de fila e proteção iguais aos de `pollCfwStatus`/`refreshNamesThenCfw`.
**Spec:** `docs/superpowers/specs/2026-11-25-cfw-scenes-geq-design.md`

## Global Constraints
- Firmware de fábrica: nenhum quadro novo enviado, nenhuma mudança de tela.
- Sem pacotes novos, sem cor literal, tamanhos atuais.
- Todo quadro esperado nos testes vem de `docs/cfw-protocol/capture-notes.md`.

## Review Focus
- Registro de cena com máscara apontando para parâmetro que o efeito atual não tem (efeito trocado depois): ignorar o valor, sem quebrar.
- `12 33` vazio (`53 43 01 00 08 00 ff ff`) ou truncado: lista vazia, sem exceção.
- Byte com sinal no EQ Global (-12 dB = -24 passos = 0xE8): ida e volta corretas.
- Trocar de preset com SC1 ativa: a cena e os registros do preset anterior não vazam para o novo.
- Modelo de EQ desconhecido lido do pedal (4, 5, 6): a seção mostra só o liga/desliga, sem knobs, e não regrava o bloco.

---

### Task 1: Codec do EQ Global
**Files:** `app/lib/model/cfw_global_eq.dart`, `app/lib/protocol/cfw_geq_codec.dart`, `app/test/protocol/cfw_geq_codec_test.dart`.
**Interfaces:** `class CfwGlobalEq { bool isOn; int model; List<int> slots /* 8, por algId, valor cru com sinal */; copyWith }`; `String buildGlobalEqFrame(CfwGlobalEq)`; `CfwGlobalEq? decodeGlobalEqFrame(String hex)`; `String readGlobalEqFrame()`.
- [ ] Testes (payload sem nibbles): Studio ligado com Bass +2 dB → `11 3a 01 00 04 00 00 00 00 32 00 64`; todos mexidos → `11 3a 01 00 04 07 03 07 03 32 07 5d`; Parametric 3 padrão → `11 3a 01 01 00 00 00 00 00 32 21 28`; desligado → `11 3a 00 00 00 00 00 00 00 32 00 64`; valor -24 vira `e8` e volta -24; decodificar resposta `12 3a …` curta → null.
- [ ] Falhar, implementar, passar, commit.

### Task 2: Modelos do EQ (dados)
**Files:** copiar `cfw_eq_models.json` para `app/assets/data/` (+ `pubspec.yaml` se os assets forem listados por arquivo, + linha de crédito em `THIRD_PARTY_NOTICES.md`), `app/lib/model/cfw_eq_models.dart`, teste.
**Interfaces:** `class CfwEqParam { name, algId, min, max, step, defaultValue, Map<num,String> texts; int toSlot(num v) /* dB: v/step; senão v */; num fromSlot(int) }`, `class CfwEqModel { int wireIndex; String name; List<CfwEqParam> params }`, `List<CfwEqModel> parseCfwEqModels(Map json)` com `wireIndex` = posição na ordem Studio 0, Parametric 3 1, Cut 24 2, Tilt 3.
- [ ] Testes: 4 modelos; Studio "Bass" `toSlot(2.0) == 4`; padrões do Parametric 3 geram os slots capturados `00 00 00 00 00 32 21 28`; texto do Low Cut 7 == "26Hz".
- [ ] Falhar, implementar, passar, commit.

### Task 3: Provider e seção "Global EQ" no diálogo
**Files:** `cfw_providers.dart` (`globalEqProvider`, `refreshGlobalEq`, `setGlobalEq`), `device_service.dart` (`requestGlobalEq`), `global_settings_dialog.dart`, testes de provider e de diálogo.
- [ ] Testes: com CFW, a seção aparece com switch, modelo e knobs do modelo; trocar o modelo envia o bloco com os padrões do modelo novo; girar um knob envia o bloco com o slot novo; sem CFW, nada aparece; modelo 5 lido → só o switch.
- [ ] Falhar, implementar (leitura ao abrir o diálogo, com as mesmas proteções de `pollCfwStatus`), passar, rodar `dialog_phone_heights_test`, commit.

### Task 4: Codec de cenas
**Files:** `app/lib/model/cfw_scenes.dart`, `app/lib/protocol/cfw_scene_codec.dart`, teste.
**Interfaces:** `class SceneRecord { int module; bool inScenes; bool? sc1On; bool? sc2On; Map<int,double> sc1; Map<int,double> sc2 /* algId → valor */ }`; `String buildSceneRecordFrame(SceneRecord)`; `String selectSceneFrame(int scene)`; `List<SceneRecord> decodeSceneRecords(List<int> bytes)`; `readSceneRecordsFrame()`, `readCurrentSceneFrame()`.
- [ ] Testes com os payloads capturados: `11 33 00 01 00 00`; `11 33 00 01 01 00 00 00 b8 41`; flags 03/07/09; `11 33 03 01 03 02` + 46.0, 96.0, 88.0; `11 32 01`; leitura vazia → `[]`; leitura com 2 registros (da captura) → NR {sc1: {0: 33}, sc2: {0: 44}, sc1On true} e AMP {sc1: {0: 33}}; truncada → `[]`.
- [ ] Falhar, implementar, passar, commit.

### Task 5: Estado das cenas
**Files:** `cfw_providers.dart` (`sceneRecordsProvider: Map<int, SceneRecord>`, `currentSceneProvider: int`, `refreshScenes`, `selectScene`, `setModuleInScenes`, `setSceneParam`, `setSceneModuleState`), `device_service.dart` (`requestSceneRecords`, `requestCurrentScene`), `preset_providers.dart` (`loadPreset`: com CFW, limpa e relê as cenas no fim), testes.
- [ ] Testes: carregar preset com CFW lê as cenas depois do dump de fábrica; sem CFW não envia nada; `setSceneParam` em SC1 envia o registro inteiro e atualiza o provider; trocar de preset limpa cena e registros; `setParameter` normal em SC1 num módulo fora das cenas continua indo pelo caminho de fábrica.
- [ ] Falhar, implementar, passar, commit.

### Task 6: Cenas no editor de módulo
**Files:** `module_editor.dart` (+ widget novo `scene_controls.dart`), testes de UI.
- [ ] Testes: sem CFW, o editor é idêntico ao de hoje; com CFW aparecem o switch Scenes e, com ele ligado, BASE/SC1/SC2; em SC1 o knob mostra o valor da cena e girar chama `setSceneParam` (não o quadro `0408`); BASE/ON/OFF envia flags 01/07/03; parâmetro na máscara que o efeito não tem é ignorado; nenhum estouro em 956x440.
- [ ] Falhar, implementar, passar, suíte inteira, commit.

### Task 7: Conferência ao vivo e revisão
- [ ] `integration_test/cfw_scenes_geq_live_test.dart`: EQ Global liga, Cut 24 e Tilt lidos de volta (confirma os índices 2 e 3), restaura; cena SC1 num módulo, lê `12 33`, restaura recarregando o preset sem salvar. Resultado gravado em arquivo no app e copiado com `devicectl`, sem depender do console.
- [ ] Revisão independente do ramo; corrigir Critical/Important com teste que falha antes.
