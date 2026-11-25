import 'lang.dart';

/// The CFW whole-pedal backup: the Settings section, the file check, the
/// restore plan and the restore's messages. Only what the user reads: the
/// file's own keys and values never go through here.
abstract class BackupText {
  const BackupText();

  static BackupText get current =>
      appLang == Lang.pt ? const _Pt() : const _En();

  // --- Section and confirm dialog -------------------------------------------

  String get intro;
  String get backUpNow;
  String get restoreEllipsis;
  String get restore;
  String get dontTouch;
  String get notRestoredHeader;
  String more(int count);
  String get pickTitle;
  String get saveTitle;
  String get saveBeforeTitle;
  String get backupFailed;
  String get restoreNotStarted;
  String readFailed(String failure, String why);
  String get backupCancelled;
  String backupSaved(String path);
  String backupNotSaved(Object e);
  String restoreRefused(String why);
  String get nothingDiffers;
  String get restoreCancelled;
  String get beforeNotSaved;
  String restoreDone(String message, String before);
  String restoreStopped(String message, String before);
  String get nothingToRestore;
  String get confirmTitle;
  String made(String when, String model, String tag, String app);
  String get overwritesHeader;
  String get confirmWarning;

  // --- Labels ---------------------------------------------------------------

  String get midiMap;
  String get cfwSettings;
  String get globalEq;
  String get globalSettings;
  String get userIr;
  String get userProfile;
  String get namModels;
  String scenesOf(String label);
  String cfwSetting(Object key);
  String globalSetting(Object key);

  /// "no answer" or "status N".
  String status(int? code);

  // --- File check -----------------------------------------------------------

  String get notJson;
  String get notBackup;
  String newerFormat(Object? format);
  String get documentChecksum;
  String get missingData;
  String get checksumMismatch;
  String get notBase64;
  String get badEntry;
  String badIndex(Object? index);
  String badSlot(Object? slot);
  String bytesExpected(int got, int expected);
  String badOptions(Object? options);
  String get notObject;
  String get notFiftyIndices;
  String get badPayload;
  String get badValues;
  String edition(Object? edition);

  /// "preset record: [why]".
  String presetRecord(String why);
  String recordBytes(int got);
  String get badLayout;
  String get notPreset;
  String get unknownLayout;
  String get noStompGroups;
  String get noEffectIds;
  String get noChainOrder;
  String get noParameters;
  String get notANumber;
  String get enableMask;

  // --- Reading the pedal ----------------------------------------------------

  String noSceneReadBack(String label);
  String noExpReadBack(String label);
  String noAnswerFromPedal(String label, String code);
  String get globalEqNoAnswer;
  String noReadBack(String label, int chunk);
  String readBackStatus(String label, int status);
  String bytesReadBack(String label, int got);
  String get namBackupUnsupported;
  String readingPreset(String label);
  String readingScenes(String label);
  String readingExp(String label);
  String get readingMidiMap;
  String get readingCfwSettings;
  String get readingGlobalEq;
  String get readingOrder;
  String readingSlotData(String kind);
  String get readingGlobals;

  // --- Restore plan ---------------------------------------------------------

  String entriesWritten(int count);
  String toChange(int count);
  String get changes;
  String presetsWritten(int count, String labels);
  String scenesRestoredOn(String labels);
  String expRestoredOn(String labels);
  String andMore(String shown, int count);
  String wrongModel(String model);
  String get namRestoreUnsupported;
  String namNotRestored(bool hasModels, bool hasPresets);
  String editionMessage({required bool isFileNam});
  String get needsCfw1;
  String get needCfw1;
  String get themeNamNote;
  String get notOnFirmware;
  String slotsOnPedal(int count);
  String get noUploadYet;
  String get expNoRoom;
  String get stompNotKept;
  String get orderKept;
  String get globalCannotCheck;

  // --- Restore --------------------------------------------------------------

  String summary({
    required int presets,
    required bool midiMap,
    required int cfwSettings,
    required bool globalEq,
    required int globals,
  });
  String midiMapNotRestored({required bool isAcked});
  String refused(int? code);
  String reportsExpected(Object? got, int expected);
  String get refused1134;
  String get noRoomForExp;
  String notWritten(String register, int? code);
  String get differentPreset;
  String get knobsChanged;
  String get readBackDifferentScenes;
  String get readBackDifferent;
  String needsSelectAndSave({required bool scenes, required bool exp});
  String writing(String label, String name);
  String get noWrite;
  String get notConfirmed;
}

class _En extends BackupText {
  const _En();

  @override
  String get intro =>
      'One file with the 50 User presets exactly as the pedal stores '
      'them, their scenes and EXP A–D, the pedal and CFW settings, the '
      'Global EQ and the User IR / Clone data. Same format as the CFW web '
      'app: its backups restore here and the other way round. USB '
      'recommended (Bluetooth is slow).';
  @override
  String get backUpNow => 'Back up now';
  @override
  String get restoreEllipsis => 'Restore…';
  @override
  String get restore => 'Restore';
  @override
  String get dontTouch => "Don't touch the pedal until it ends.";
  @override
  String get notRestoredHeader => 'Not restored / plays differently here:';
  @override
  String more(int count) => '… $count more';
  @override
  String get pickTitle => 'Restore the pedal';
  @override
  String get saveTitle => 'Save the pedal backup';
  @override
  String get saveBeforeTitle =>
      'Save the pedal as it is now (before the restore)';
  @override
  String get backupFailed => 'Backup failed';
  @override
  String get restoreNotStarted => 'Restore not started';
  @override
  String readFailed(String failure, String why) =>
      '$failure: $why. Nothing was saved.';
  @override
  String get backupCancelled => 'Backup read, not saved (cancelled)';
  @override
  String backupSaved(String path) => 'Backup saved: $path';
  @override
  String backupNotSaved(Object e) => 'Backup read, not saved: $e';
  @override
  String restoreRefused(String why) => 'Restore refused: $why';
  @override
  String get nothingDiffers =>
      'Nothing differs from the pedal: nothing to write';
  @override
  String get restoreCancelled => 'Restore cancelled: nothing was written';
  @override
  String get beforeNotSaved =>
      'Restore cancelled: the backup of the pedal as it is now was not '
      'saved; nothing was written';
  @override
  String restoreDone(String message, String before) =>
      '$message. Before-restore backup: $before';
  @override
  String restoreStopped(String message, String before) =>
      '$message. Load the same file again to resume. '
      'Before-restore backup: $before';
  @override
  String get nothingToRestore => 'Nothing to restore';
  @override
  String get confirmTitle => 'Restore this backup?';
  @override
  String made(String when, String model, String tag, String app) =>
      'Made $when on the $model $tag by $app.';
  @override
  String get overwritesHeader => 'Overwrites on the pedal:';
  @override
  String get confirmWarning =>
      'This rewrites the pedal’s memory. A backup of the pedal as it '
      'is now is saved first; each preset written is read back. If '
      'the restore stops, load the same file again to resume.';

  @override
  String get midiMap => 'Custom MIDI map';
  @override
  String get cfwSettings => 'CFW settings';
  @override
  String get globalEq => 'Global EQ';
  @override
  String get globalSettings => 'Global settings';
  @override
  String get userIr => 'User IR';
  @override
  String get userProfile => 'User Profile';
  @override
  String get namModels => 'NAM models';
  @override
  String scenesOf(String label) => '$label scenes';
  @override
  String cfwSetting(Object key) => 'CFW setting $key';
  @override
  String globalSetting(Object key) => 'Global setting $key';
  @override
  String status(int? code) => code == null ? 'no answer' : 'status $code';

  @override
  String get notJson => 'not a JSON file';
  @override
  String get notBackup => 'not a Sonicake CFW backup file';
  @override
  String newerFormat(Object? format) =>
      'backup format $format: made by a newer app version, update the app';
  @override
  String get documentChecksum =>
      'the file was changed or damaged (document checksum)';
  @override
  String get missingData => 'missing data';
  @override
  String get checksumMismatch => 'checksum mismatch';
  @override
  String get notBase64 => 'not base64';
  @override
  String get badEntry => 'bad entry';
  @override
  String badIndex(Object? index) => 'bad index $index';
  @override
  String badSlot(Object? slot) => 'bad slot $slot';
  @override
  String bytesExpected(int got, int expected) =>
      '$got bytes (expected $expected)';
  @override
  String badOptions(Object? options) => 'bad options $options';
  @override
  String get notObject => 'not an object';
  @override
  String get notFiftyIndices => 'not 50 indices';
  @override
  String get badPayload => 'bad payload';
  @override
  String get badValues => 'bad values';
  @override
  String edition(Object? edition) => 'edition $edition';
  @override
  String presetRecord(String why) => 'preset record: $why';
  @override
  String recordBytes(int got) => '$got bytes (expected 494, Smart Box 506)';
  @override
  String get badLayout => 'bad layout';
  @override
  String get notPreset => 'not a preset';
  @override
  String get unknownLayout => 'unknown layout';
  @override
  String get noStompGroups => 'no STOMP groups';
  @override
  String get noEffectIds => 'no effect ids';
  @override
  String get noChainOrder => 'no chain order';
  @override
  String get noParameters => 'no parameters';
  @override
  String get notANumber => 'a parameter is not a number';
  @override
  String get enableMask => 'enable mask';

  @override
  String noSceneReadBack(String label) => '$label: no scene read-back (12 34)';
  @override
  String noExpReadBack(String label) => '$label: no EXP A–D read-back (12 3D)';
  @override
  String noAnswerFromPedal(String label, String code) =>
      '$label: no answer from the pedal ($code)';
  @override
  String get globalEqNoAnswer => 'Global EQ: no answer (12 3A)';
  @override
  String noReadBack(String label, int chunk) =>
      '$label: no read-back (12 38 chunk $chunk)';
  @override
  String readBackStatus(String label, int status) =>
      '$label: read-back status $status';
  @override
  String bytesReadBack(String label, int got) => '$label: $got bytes read back';
  @override
  String get namBackupUnsupported =>
      'backups of the NAM CFW are not supported by SonicMaster yet';
  @override
  String readingPreset(String label) => 'Reading preset $label';
  @override
  String readingScenes(String label) => 'Reading the scenes of $label';
  @override
  String readingExp(String label) => 'Reading EXP A–D of $label';
  @override
  String get readingMidiMap => 'Reading the Custom MIDI map';
  @override
  String get readingCfwSettings => 'Reading the CFW settings';
  @override
  String get readingGlobalEq => 'Reading the Global EQ';
  @override
  String get readingOrder => 'Reading the preset order';
  @override
  String readingSlotData(String kind) => 'Reading $kind data';
  @override
  String get readingGlobals => 'Reading the global settings';

  @override
  String entriesWritten(int count) => '$count entries written';
  @override
  String toChange(int count) => '$count to change';
  @override
  String get changes => 'changes';
  @override
  String presetsWritten(int count, String labels) =>
      'Presets: $count written ($labels)';
  @override
  String scenesRestoredOn(String labels) => 'Scenes: restored on $labels';
  @override
  String expRestoredOn(String labels) => 'EXP A–D: restored on $labels';
  @override
  String andMore(String shown, int count) => '$shown, + $count more';
  @override
  String wrongModel(String model) {
    final article = 'AEIOU'.contains(model.isEmpty ? 'x' : model[0])
        ? 'an'
        : 'a';

    return 'This backup comes from $article $model: restore it on that '
        'pedal.';
  }

  @override
  String get namRestoreUnsupported =>
      'restoring on the NAM CFW is not supported by SonicMaster';
  @override
  String namNotRestored(bool hasModels, bool hasPresets) =>
      '${[if (hasModels) 'NAM models (slots 02–20)', if (hasPresets) 'User presets (P01–P50)'].join(', ')}: '
      'not restored. ${editionMessage(isFileNam: true)}';
  @override
  String editionMessage({required bool isFileNam}) {
    const settingsOnly =
        'Here only the pedal settings (global settings, CFW settings, Custom '
        'MIDI map) move, no presets. ';
    const switching =
        'Switching CFW: back up BEFORE flashing (on the CFW you are leaving), '
        'then restore the backup you made earlier on the other CFW.';

    return isFileNam
        ? 'This backup was made on the NAM CFW: restore it after installing '
              'the NAM CFW. $settingsOnly$switching'
        : 'This backup was made on the normal CFW: restore it after installing '
              'the normal CFW (its presets would play almost nothing on the NAM '
              'CFW). $settingsOnly$switching No NAM backup yet? Clear the User '
              'presets.';
  }

  @override
  String get needsCfw1 => 'needs CFW 1.0';
  @override
  String get needCfw1 => 'need CFW 1.0';
  @override
  String get themeNamNote =>
      'CFW setting Theme (NAM CFW): means another thing on the normal CFW, '
      'kept as it is';
  @override
  String get notOnFirmware => 'not on this firmware';
  @override
  String slotsOnPedal(int count) => 'this pedal has $count slots';
  @override
  String get noUploadYet =>
      'not restored (SonicMaster does not upload backup data yet)';
  @override
  String get expNoRoom => 'not restored (no room: its scenes use the space)';
  @override
  String get stompNotKept => 'STOMP groups not kept (needs CFW 1.0)';
  @override
  String get orderKept =>
      'Preset order: kept as it is (the presets are written in the order of '
      'the backup)';
  @override
  String get globalCannotCheck =>
      'not restored (SonicMaster cannot check it on this pedal)';

  @override
  String summary({
    required int presets,
    required bool midiMap,
    required int cfwSettings,
    required bool globalEq,
    required int globals,
  }) => [
    'Restored $presets preset(s)',
    if (midiMap) 'the Custom MIDI map',
    if (cfwSettings > 0) '$cfwSettings CFW setting(s)',
    if (globalEq) 'the Global EQ',
    if (globals > 0) '$globals global setting(s)',
  ].join(', ');
  @override
  String midiMapNotRestored({required bool isAcked}) =>
      'not restored (${isAcked ? 'read back differently' : 'no ack'})';
  @override
  String refused(int? code) => 'refused (${status(code)})';
  @override
  String reportsExpected(Object? got, int expected) =>
      'pedal reports $got, expected $expected';
  @override
  String get refused1134 => 'the pedal refused 11 34, written with 11 4F';
  @override
  String get noRoomForExp =>
      'not written (its scenes leave no room for EXP A–D)';
  @override
  String notWritten(String register, int? code) =>
      'not written ($register ${status(code)})';
  @override
  String get differentPreset =>
      'the pedal reads back a different preset; the restore stopped here';
  @override
  String get knobsChanged => 'the pedal changed some knob values on the write';
  @override
  String get readBackDifferentScenes => 'read back differently';
  @override
  String get readBackDifferent => 'read back differently';
  @override
  String needsSelectAndSave({required bool scenes, required bool exp}) =>
      '${[if (scenes) 'scenes', if (exp) 'EXP A–D'].join(' + ')}: '
      'not restored (this firmware needs the preset selected and saved; '
      'SonicMaster does not do that yet)';
  @override
  String writing(String label, String name) => 'Writing $label $name';
  @override
  String get noWrite => 'not restored (no write for it)';
  @override
  String get notConfirmed => 'sent, the pedal did not confirm it';
}

class _Pt extends BackupText {
  const _Pt();

  @override
  String get intro =>
      'Um arquivo com os 50 presets User exatamente como a pedaleira os '
      'guarda, suas cenas e EXP A–D, os ajustes da pedaleira e do CFW, o EQ '
      'global e os dados de IR do usuário / Clone. Mesmo formato do app web '
      'do CFW: os backups dele restauram aqui e vice-versa. USB recomendado '
      '(o Bluetooth é lento).';
  @override
  String get backUpNow => 'Fazer backup agora';
  @override
  String get restoreEllipsis => 'Restaurar…';
  @override
  String get restore => 'Restaurar';
  @override
  String get dontTouch => 'Não mexa na pedaleira até terminar.';
  @override
  String get notRestoredHeader => 'Não restaurado / toca diferente aqui:';
  @override
  String more(int count) => '… mais $count';
  @override
  String get pickTitle => 'Restaurar a pedaleira';
  @override
  String get saveTitle => 'Salvar o backup da pedaleira';
  @override
  String get saveBeforeTitle =>
      'Salvar a pedaleira como está agora (antes da restauração)';
  @override
  String get backupFailed => 'O backup falhou';
  @override
  String get restoreNotStarted => 'Restauração não iniciada';
  @override
  String readFailed(String failure, String why) =>
      '$failure: $why. Nada foi salvo.';
  @override
  String get backupCancelled => 'Backup lido, não salvo (cancelado)';
  @override
  String backupSaved(String path) => 'Backup salvo: $path';
  @override
  String backupNotSaved(Object e) => 'Backup lido, não salvo: $e';
  @override
  String restoreRefused(String why) => 'Restauração recusada: $why';
  @override
  String get nothingDiffers => 'Nada difere da pedaleira: nada a gravar';
  @override
  String get restoreCancelled => 'Restauração cancelada: nada foi gravado';
  @override
  String get beforeNotSaved =>
      'Restauração cancelada: o backup da pedaleira como está agora não foi '
      'salvo; nada foi gravado';
  @override
  String restoreDone(String message, String before) =>
      '$message. Backup de antes da restauração: $before';
  @override
  String restoreStopped(String message, String before) =>
      '$message. Carregue o mesmo arquivo de novo para continuar. '
      'Backup de antes da restauração: $before';
  @override
  String get nothingToRestore => 'Nada a restaurar';
  @override
  String get confirmTitle => 'Restaurar este backup?';
  @override
  String made(String when, String model, String tag, String app) =>
      'Feito em $when na $model $tag pelo $app.';
  @override
  String get overwritesHeader => 'Vai sobrescrever na pedaleira:';
  @override
  String get confirmWarning =>
      'Isso regrava a memória da pedaleira. Antes, é salvo um backup da '
      'pedaleira como está agora; cada preset gravado é lido de volta. Se a '
      'restauração parar, carregue o mesmo arquivo de novo para continuar.';

  @override
  String get midiMap => 'Mapa MIDI personalizado';
  @override
  String get cfwSettings => 'Ajustes do CFW';
  @override
  String get globalEq => 'EQ global';
  @override
  String get globalSettings => 'Ajustes globais';
  @override
  String get userIr => 'IR do usuário';
  @override
  String get userProfile => 'Perfil do usuário';
  @override
  String get namModels => 'Modelos NAM';
  @override
  String scenesOf(String label) => '$label (cenas)';
  @override
  String cfwSetting(Object key) => 'Ajuste do CFW $key';
  @override
  String globalSetting(Object key) => 'Ajuste global $key';
  @override
  String status(int? code) => code == null ? 'sem resposta' : 'status $code';

  @override
  String get notJson => 'não é um arquivo JSON';
  @override
  String get notBackup => 'não é um arquivo de backup do Sonicake CFW';
  @override
  String newerFormat(Object? format) =>
      'formato de backup $format: feito por uma versão mais nova do app, '
      'atualize o app';
  @override
  String get documentChecksum =>
      'o arquivo foi alterado ou danificado (checksum do documento)';
  @override
  String get missingData => 'faltam dados';
  @override
  String get checksumMismatch => 'checksum não confere';
  @override
  String get notBase64 => 'não é base64';
  @override
  String get badEntry => 'entrada inválida';
  @override
  String badIndex(Object? index) => 'índice inválido $index';
  @override
  String badSlot(Object? slot) => 'slot inválido $slot';
  @override
  String bytesExpected(int got, int expected) =>
      '$got bytes (esperado $expected)';
  @override
  String badOptions(Object? options) => 'opções inválidas $options';
  @override
  String get notObject => 'não é um objeto';
  @override
  String get notFiftyIndices => 'não tem 50 índices';
  @override
  String get badPayload => 'dados inválidos';
  @override
  String get badValues => 'valores inválidos';
  @override
  String edition(Object? edition) => 'edição $edition';
  @override
  String presetRecord(String why) => 'registro do preset: $why';
  @override
  String recordBytes(int got) => '$got bytes (esperado 494, Smart Box 506)';
  @override
  String get badLayout => 'layout inválido';
  @override
  String get notPreset => 'não é um preset';
  @override
  String get unknownLayout => 'layout desconhecido';
  @override
  String get noStompGroups => 'sem grupos STOMP';
  @override
  String get noEffectIds => 'sem ids de efeito';
  @override
  String get noChainOrder => 'sem ordem da cadeia';
  @override
  String get noParameters => 'sem parâmetros';
  @override
  String get notANumber => 'um parâmetro não é um número';
  @override
  String get enableMask => 'máscara de ativação';

  @override
  String noSceneReadBack(String label) =>
      '$label: cenas não lidas de volta (12 34)';
  @override
  String noExpReadBack(String label) =>
      '$label: EXP A–D não lido de volta (12 3D)';
  @override
  String noAnswerFromPedal(String label, String code) =>
      '$label: sem resposta da pedaleira ($code)';
  @override
  String get globalEqNoAnswer => 'EQ global: sem resposta (12 3A)';
  @override
  String noReadBack(String label, int chunk) =>
      '$label: nada lido de volta (12 38 bloco $chunk)';
  @override
  String readBackStatus(String label, int status) =>
      '$label: status $status na leitura';
  @override
  String bytesReadBack(String label, int got) =>
      '$label: $got bytes lidos de volta';
  @override
  String get namBackupUnsupported =>
      'o SonicMaster ainda não faz backup do CFW NAM';
  @override
  String readingPreset(String label) => 'Lendo o preset $label';
  @override
  String readingScenes(String label) => 'Lendo as cenas de $label';
  @override
  String readingExp(String label) => 'Lendo EXP A–D de $label';
  @override
  String get readingMidiMap => 'Lendo o mapa MIDI personalizado';
  @override
  String get readingCfwSettings => 'Lendo os ajustes do CFW';
  @override
  String get readingGlobalEq => 'Lendo o EQ global';
  @override
  String get readingOrder => 'Lendo a ordem dos presets';
  @override
  String readingSlotData(String kind) => 'Lendo os dados de $kind';
  @override
  String get readingGlobals => 'Lendo os ajustes globais';

  @override
  String entriesWritten(int count) => '$count entradas gravadas';
  @override
  String toChange(int count) => '$count a mudar';
  @override
  String get changes => 'muda';
  @override
  String presetsWritten(int count, String labels) =>
      'Presets: $count gravados ($labels)';
  @override
  String scenesRestoredOn(String labels) => 'Cenas: restauradas em $labels';
  @override
  String expRestoredOn(String labels) => 'EXP A–D: restaurado em $labels';
  @override
  String andMore(String shown, int count) => '$shown e mais $count';
  @override
  String wrongModel(String model) =>
      'Este backup vem de uma $model: restaure-o nessa pedaleira.';
  @override
  String get namRestoreUnsupported => 'o SonicMaster não restaura no CFW NAM';
  @override
  String namNotRestored(bool hasModels, bool hasPresets) =>
      '${[if (hasModels) 'Modelos NAM (slots 02–20)', if (hasPresets) 'Presets User (P01–P50)'].join(', ')}: '
      'não restaurado. ${editionMessage(isFileNam: true)}';
  @override
  String editionMessage({required bool isFileNam}) {
    const settingsOnly =
        'Aqui só passam os ajustes da pedaleira (ajustes globais, ajustes do '
        'CFW, mapa MIDI personalizado), nenhum preset. ';
    const switching =
        'Para trocar de CFW: faça backup ANTES de gravar o firmware (no CFW '
        'que você está deixando), depois restaure no outro CFW o backup que '
        'você fez antes.';

    return isFileNam
        ? 'Este backup foi feito no CFW NAM: restaure-o depois de instalar o '
              'CFW NAM. $settingsOnly$switching'
        : 'Este backup foi feito no CFW normal: restaure-o depois de instalar '
              'o CFW normal (os presets dele tocariam quase nada no CFW NAM). '
              '$settingsOnly$switching Ainda sem backup NAM? Limpe os presets '
              'User.';
  }

  @override
  String get needsCfw1 => 'precisa do CFW 1.0';
  @override
  String get needCfw1 => 'precisam do CFW 1.0';
  @override
  String get themeNamNote =>
      'Ajuste do CFW Tema (CFW NAM): significa outra coisa no CFW normal, '
      'mantido como está';
  @override
  String get notOnFirmware => 'não existe neste firmware';
  @override
  String slotsOnPedal(int count) => 'esta pedaleira tem $count slots';
  @override
  String get noUploadYet =>
      'não restaurado (o SonicMaster ainda não envia dados de backup)';
  @override
  String get expNoRoom =>
      'não restaurado (sem espaço: as cenas dele usam o espaço)';
  @override
  String get stompNotKept => 'grupos STOMP não mantidos (precisa do CFW 1.0)';
  @override
  String get orderKept =>
      'Ordem dos presets: mantida como está (os presets são gravados na '
      'ordem do backup)';
  @override
  String get globalCannotCheck =>
      'não restaurado (o SonicMaster não consegue conferi-lo nesta pedaleira)';

  @override
  String summary({
    required int presets,
    required bool midiMap,
    required int cfwSettings,
    required bool globalEq,
    required int globals,
  }) => [
    'Restaurado(s): $presets preset(s)',
    if (midiMap) 'o mapa MIDI personalizado',
    if (cfwSettings > 0) '$cfwSettings ajuste(s) do CFW',
    if (globalEq) 'o EQ global',
    if (globals > 0) '$globals ajuste(s) global(is)',
  ].join(', ');
  @override
  String midiMapNotRestored({required bool isAcked}) =>
      'não restaurado (${isAcked ? 'lido de volta diferente' : 'sem confirmação'})';
  @override
  String refused(int? code) => 'recusado (${status(code)})';
  @override
  String reportsExpected(Object? got, int expected) =>
      'a pedaleira informa $got, esperado $expected';
  @override
  String get refused1134 => 'a pedaleira recusou 11 34, gravado com 11 4F';
  @override
  String get noRoomForExp =>
      'não gravado (as cenas dele não deixam espaço para EXP A–D)';
  @override
  String notWritten(String register, int? code) =>
      'não gravado ($register ${status(code)})';
  @override
  String get differentPreset =>
      'a pedaleira lê de volta um preset diferente; a restauração parou aqui';
  @override
  String get knobsChanged =>
      'a pedaleira mudou alguns valores de knob na gravação';
  @override
  String get readBackDifferentScenes => 'lidas de volta diferente';
  @override
  String get readBackDifferent => 'lido de volta diferente';
  @override
  String needsSelectAndSave({required bool scenes, required bool exp}) =>
      '${[if (scenes) 'cenas', if (exp) 'EXP A–D'].join(' + ')}: '
      'não restaurado (este firmware precisa do preset selecionado e salvo; '
      'o SonicMaster ainda não faz isso)';
  @override
  String writing(String label, String name) => 'Gravando $label $name';
  @override
  String get noWrite => 'não restaurado (nada para gravá-lo)';
  @override
  String get notConfirmed => 'enviado, a pedaleira não confirmou';
}
