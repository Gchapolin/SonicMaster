import 'lang.dart';

/// Texts of the User IR / User Profile (Clone) slots: the slots dialog, the
/// Load / Name / Clear actions, the upload status and the import dialogs.
abstract class SlotsText {
  const SlotsText();

  static SlotsText get current =>
      appLang == Lang.pt ? const _Pt() : const _En();

  // Slots dialog and slot actions.
  String get title;
  String get irSection;
  String get profileSection;
  String slotCount(int n);
  String get load;
  String get name;
  String get clear;
  String get rename;
  String get nameLabel;
  String get irFile;
  String get namProfile;

  // User IR.
  String get irLoadFailed;
  String get irImportFailed;
  String importingToIr(int n);
  String clearIrTitle(int n);
  String get clearIrBody;
  String renameIrTitle(int n);

  // User Profile (Clone).
  String get unsupportedFormatTitle;
  String unsupportedFormatBody(String architecture);
  String get namLoadFailed;
  String get importFailed;
  String importingToProfile(int n);
  String clearProfileTitle(int n);
  String get clearProfileBody;
  String renameProfileTitle(int n);

  // IR upload status.
  String pickIrTitle(int n);
  String irDecodeFailed(Object e);
  String cannotReadWav(Object e);
  String get uploadingIr;
  String irCommitted(String name, int n);
  String get irUploadNoAck;
  String get irNotCommitted;
  String get irUploadFailed;
  String renamedIr(int n);
  String clearedIr(int n);
  String get irCommandNoAck;
  String irCommandFailed(Object e);

  // Clone upload status.
  String pickNamTitle(int n);
  String get convertingNam;
  String get uploadingClone;
  String cloneCommitted(String name, int n);
  String get cloneUploadNoAck;
  String get cloneNotCommitted;
  String get cloneUploadFailed;
  String namConvertFailed(Object e);
  String conversionFailed(Object e);
  String renamedProfile(int n);
  String clearedProfile(int n);
  String get cloneCommandNoAck;
  String cloneCommandFailed(Object e);

  // Shared by both uploads.
  String get renaming;
  String get clearing;
  String get notCommitted;

  // Import dialogs.
  String get preparing;
  String get supportedFormats;
}

class _En extends SlotsText {
  const _En();

  @override
  String get title => 'User IR & Clone slots';
  @override
  String get irSection => 'User IR (cab)';
  @override
  String get profileSection => 'User Profile (Clone)';
  @override
  String slotCount(int n) => '$n slots';
  @override
  String get load => 'Load…';
  @override
  String get name => 'Name…';
  @override
  String get clear => 'Clear';
  @override
  String get rename => 'Rename';
  @override
  String get nameLabel => 'Name';
  @override
  String get irFile => 'IR File';
  @override
  String get namProfile => 'NAM Profile';

  @override
  String get irLoadFailed => 'IR load failed';
  @override
  String get irImportFailed => 'IR import failed';
  @override
  String importingToIr(int n) => 'Importing to User IR $n';
  @override
  String clearIrTitle(int n) => 'Clear User IR $n?';
  @override
  String get clearIrBody => 'This erases the loaded impulse response.';
  @override
  String renameIrTitle(int n) => 'Rename User IR $n';

  @override
  String get unsupportedFormatTitle => 'Unsupported model format';
  @override
  String unsupportedFormatBody(String architecture) =>
      'This .nam is a "$architecture" model, which the clone converter '
      "can't convert.";
  @override
  String get namLoadFailed => 'NAM load failed';
  @override
  String get importFailed => 'Import failed';
  @override
  String importingToProfile(int n) => 'Importing to User Profile $n';
  @override
  String clearProfileTitle(int n) => 'Clear User Profile $n?';
  @override
  String get clearProfileBody => 'This erases the loaded clone profile.';
  @override
  String renameProfileTitle(int n) => 'Rename User Profile $n';

  @override
  String pickIrTitle(int n) => 'Load IR into User IR $n';
  @override
  String irDecodeFailed(Object e) => 'IR decode failed: $e';
  @override
  String cannotReadWav(Object e) => 'Could not read this WAV file:\n$e';
  @override
  String get uploadingIr => 'Uploading IR…';
  @override
  String irCommitted(String name, int n) => 'IR "$name" → User IR $n';
  @override
  String get irUploadNoAck => 'IR upload failed (no ACK)';
  @override
  String get irNotCommitted =>
      'IR sent but not saved — power-cycle the pedal, then retry';
  @override
  String get irUploadFailed => 'IR upload failed';
  @override
  String renamedIr(int n) => 'renamed User IR $n';
  @override
  String clearedIr(int n) =>
      'cleared User IR $n — power-cycle before the next IR edit';
  @override
  String get irCommandNoAck => 'IR command failed (no ACK)';
  @override
  String irCommandFailed(Object e) => 'IR command failed: $e';

  @override
  String pickNamTitle(int n) => 'Load NAM profile into User Profile $n';
  @override
  String get convertingNam => 'Converting NAM…';
  @override
  String get uploadingClone => 'Uploading clone…';
  @override
  String cloneCommitted(String name, int n) =>
      'Clone "$name" → User Profile $n';
  @override
  String get cloneUploadNoAck => 'Clone upload failed (no ACK)';
  @override
  String get cloneNotCommitted =>
      'Clone sent but not saved — power-cycle the pedal, then retry';
  @override
  String get cloneUploadFailed => 'Clone upload failed';
  @override
  String namConvertFailed(Object e) => 'NAM convert failed: $e';
  @override
  String conversionFailed(Object e) => 'Conversion failed:\n$e';
  @override
  String renamedProfile(int n) => 'renamed User Profile $n';
  @override
  String clearedProfile(int n) =>
      'cleared User Profile $n — power-cycle before the next edit';
  @override
  String get cloneCommandNoAck => 'Clone command failed (no ACK)';
  @override
  String cloneCommandFailed(Object e) => 'Clone command failed: $e';

  @override
  String get renaming => 'renaming…';
  @override
  String get clearing => 'clearing…';
  @override
  String get notCommitted => 'not saved — power-cycle the pedal, then retry';

  @override
  String get preparing => 'Preparing…';
  @override
  String get supportedFormats => 'SUPPORTED FORMATS';
}

class _Pt extends SlotsText {
  const _Pt();

  @override
  String get title => 'Slots de IR do usuário e Clone';
  @override
  String get irSection => 'IR do usuário (cab)';
  @override
  String get profileSection => 'Perfil do usuário (Clone)';
  @override
  String slotCount(int n) => '$n slots';
  @override
  String get load => 'Carregar…';
  @override
  String get name => 'Nome…';
  @override
  String get clear => 'Limpar';
  @override
  String get rename => 'Renomear';
  @override
  String get nameLabel => 'Nome';
  @override
  String get irFile => 'Arquivo IR';
  @override
  String get namProfile => 'Perfil NAM';

  @override
  String get irLoadFailed => 'Falha ao carregar o IR';
  @override
  String get irImportFailed => 'Falha ao importar o IR';
  @override
  String importingToIr(int n) => 'Importando para IR do usuário $n';
  @override
  String clearIrTitle(int n) => 'Limpar IR do usuário $n?';
  @override
  String get clearIrBody => 'Isso apaga a resposta ao impulso carregada.';
  @override
  String renameIrTitle(int n) => 'Renomear IR do usuário $n';

  @override
  String get unsupportedFormatTitle => 'Formato de modelo não suportado';
  @override
  String unsupportedFormatBody(String architecture) =>
      'Este .nam é um modelo "$architecture", que o conversor de clone '
      'não consegue converter.';
  @override
  String get namLoadFailed => 'Falha ao carregar o NAM';
  @override
  String get importFailed => 'Falha ao importar';
  @override
  String importingToProfile(int n) => 'Importando para Perfil do usuário $n';
  @override
  String clearProfileTitle(int n) => 'Limpar Perfil do usuário $n?';
  @override
  String get clearProfileBody => 'Isso apaga o perfil de clone carregado.';
  @override
  String renameProfileTitle(int n) => 'Renomear Perfil do usuário $n';

  @override
  String pickIrTitle(int n) => 'Carregar IR no IR do usuário $n';
  @override
  String irDecodeFailed(Object e) => 'Falha ao decodificar o IR: $e';
  @override
  String cannotReadWav(Object e) =>
      'Não foi possível ler este arquivo WAV:\n$e';
  @override
  String get uploadingIr => 'Enviando IR…';
  @override
  String irCommitted(String name, int n) => 'IR "$name" → IR do usuário $n';
  @override
  String get irUploadNoAck => 'Falha ao enviar o IR (sem ACK)';
  @override
  String get irNotCommitted =>
      'IR enviado mas não salvo — desligue e ligue a pedaleira e tente de novo';
  @override
  String get irUploadFailed => 'Falha ao enviar o IR';
  @override
  String renamedIr(int n) => 'IR do usuário $n renomeado';
  @override
  String clearedIr(int n) =>
      'IR do usuário $n limpo — desligue e ligue antes da próxima edição de IR';
  @override
  String get irCommandNoAck => 'Falha no comando de IR (sem ACK)';
  @override
  String irCommandFailed(Object e) => 'Falha no comando de IR: $e';

  @override
  String pickNamTitle(int n) => 'Carregar perfil NAM no Perfil do usuário $n';
  @override
  String get convertingNam => 'Convertendo NAM…';
  @override
  String get uploadingClone => 'Enviando clone…';
  @override
  String cloneCommitted(String name, int n) =>
      'Clone "$name" → Perfil do usuário $n';
  @override
  String get cloneUploadNoAck => 'Falha ao enviar o clone (sem ACK)';
  @override
  String get cloneNotCommitted =>
      'Clone enviado mas não salvo — desligue e ligue a pedaleira e tente '
      'de novo';
  @override
  String get cloneUploadFailed => 'Falha ao enviar o clone';
  @override
  String namConvertFailed(Object e) => 'Falha ao converter o NAM: $e';
  @override
  String conversionFailed(Object e) => 'Falha na conversão:\n$e';
  @override
  String renamedProfile(int n) => 'Perfil do usuário $n renomeado';
  @override
  String clearedProfile(int n) =>
      'Perfil do usuário $n limpo — desligue e ligue antes da próxima edição';
  @override
  String get cloneCommandNoAck => 'Falha no comando de clone (sem ACK)';
  @override
  String cloneCommandFailed(Object e) => 'Falha no comando de clone: $e';

  @override
  String get renaming => 'renomeando…';
  @override
  String get clearing => 'limpando…';
  @override
  String get notCommitted =>
      'não salvo — desligue e ligue a pedaleira e tente de novo';

  @override
  String get preparing => 'Preparando…';
  @override
  String get supportedFormats => 'FORMATOS SUPORTADOS';
}
