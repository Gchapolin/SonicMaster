import 'lang.dart';

/// Texts of saving, importing and exporting presets: the save and unsaved
/// changes dialogs, the community presets and the preset status messages.
abstract class PresetsText {
  const PresetsText();

  static PresetsText get current =>
      appLang == Lang.pt ? const _Pt() : const _En();

  // Save preset dialog.
  String get savePresetTitle;
  String get presetName;
  String get nameHint;

  // Unsaved changes dialog.
  String get discardTitle;
  String get discardBody;
  String get discard;

  // Community presets.
  String get communityTitle;
  String get communityIntro;
  String get connectToTry;
  String get catalogueUnreadable;
  String get tryLabel;
  String get saveTo;
  String get onThePedal;
  String get effectDataNotLoaded;
  String get downloadFailed;
  String usesCfwModel(String name);
  String get sendFailed;
  String get notACatalogue;

  // Preset file errors (reach the user through the community presets).
  String unsupportedPresetVersion(Object? version);
  String unknownEffect(String module, String effect);

  // Import / export status.
  String get exportDialogTitle;
  String exportedTo(String path);
  String exportFailed(Object e);
  String get importDialogTitle;
  String importFailed(Object e);
  String needsCfw(String name);
  String imported(int skipped, int warnings);
  String importPushFailed(Object e);

  // Preset load / edit / save status.
  String get dataLoadFailed;
  String get dataLoading;
  String noCommandFor(String label);
  String loaded(String label);
  String noAck(String label);
  String sendFailedFor(String label, Object e);
  String editFailed(Object e);
  String get reorderUnavailable;
  String get saveNoAck;
  String savedTo(String name, String slot);
  String saveFailed(Object e);
  String get factoryReset;
  String resetFailed(Object e);
}

class _En extends PresetsText {
  const _En();

  @override
  String get savePresetTitle => 'Save preset';
  @override
  String get presetName => 'Preset name';
  @override
  String get nameHint => 'Name';

  @override
  String get discardTitle => 'Discard unsaved changes?';
  @override
  String get discardBody =>
      'The current preset has edits that are not saved to a slot. '
      'Loading another preset will discard them.';
  @override
  String get discard => 'Discard';

  @override
  String get communityTitle => 'Community presets';
  @override
  String get communityIntro =>
      'Shared by players in the Sonicake CFW community '
      '(pocketmaster-cfw.guitar-training-generator.com).';
  @override
  String get connectToTry => 'Connect a pedal to try a preset.';
  @override
  String get catalogueUnreadable =>
      'The community catalogue could not be read. Check the '
      'connection and retry.';
  @override
  String get tryLabel => 'Try';
  @override
  String get saveTo => 'Save to…';
  @override
  String get onThePedal => 'On the pedal. Save to keep it.';
  @override
  String get effectDataNotLoaded => 'The effect data is not loaded yet';
  @override
  String get downloadFailed =>
      'Could not download the preset. Check the connection and retry.';
  @override
  String usesCfwModel(String name) =>
      'Uses $name, which needs the CFW firmware';
  @override
  String get sendFailed => 'The preset could not be sent to the pedal';
  @override
  String get notACatalogue => 'Not a community catalogue this app can read';

  @override
  String unsupportedPresetVersion(Object? version) =>
      'Unsupported preset version: $version';
  @override
  String unknownEffect(String module, String effect) =>
      'Module "$module" references unknown effect "$effect"';

  @override
  String get exportDialogTitle => 'Export preset';
  @override
  String exportedTo(String path) => 'exported to $path';
  @override
  String exportFailed(Object e) => 'export failed: $e';
  @override
  String get importDialogTitle => 'Import preset';
  @override
  String importFailed(Object e) => 'import failed: $e';
  @override
  String needsCfw(String name) => 'import failed: $name needs the CFW firmware';
  @override
  String imported(int skipped, int warnings) =>
      'imported${skipped > 0 ? ', $skipped skipped' : ''}'
      '${warnings > 0 ? ' ($warnings warning(s))' : ''}';
  @override
  String importPushFailed(Object e) => 'import push failed: $e';

  @override
  String get dataLoadFailed => 'data load failed';
  @override
  String get dataLoading => 'data still loading…';
  @override
  String noCommandFor(String label) => 'no command for $label';
  @override
  String loaded(String label) => 'loaded $label';
  @override
  String noAck(String label) => '$label: no ACK (timeout)';
  @override
  String sendFailedFor(String label, Object e) => '$label: send failed — $e';
  @override
  String editFailed(Object e) => 'edit failed: $e';
  @override
  String get reorderUnavailable => 'reorder unavailable';
  @override
  String get saveNoAck => 'save: no ACK (timeout)';
  @override
  String savedTo(String name, String slot) => 'saved "$name" to $slot';
  @override
  String saveFailed(Object e) => 'save failed: $e';
  @override
  String get factoryReset => 'factory reset — pedal rebooting';
  @override
  String resetFailed(Object e) => 'reset failed: $e';
}

class _Pt extends PresetsText {
  const _Pt();

  @override
  String get savePresetTitle => 'Salvar preset';
  @override
  String get presetName => 'Nome do preset';
  @override
  String get nameHint => 'Nome';

  @override
  String get discardTitle => 'Descartar alterações não salvas?';
  @override
  String get discardBody =>
      'O preset atual tem edições que não foram salvas em um slot. '
      'Carregar outro preset vai descartá-las.';
  @override
  String get discard => 'Descartar';

  @override
  String get communityTitle => 'Presets da comunidade';
  @override
  String get communityIntro =>
      'Compartilhados por músicos da comunidade Sonicake CFW '
      '(pocketmaster-cfw.guitar-training-generator.com).';
  @override
  String get connectToTry => 'Conecte uma pedaleira para testar um preset.';
  @override
  String get catalogueUnreadable =>
      'Não foi possível ler o catálogo da comunidade. Verifique a '
      'conexão e tente de novo.';
  @override
  String get tryLabel => 'Testar';
  @override
  String get saveTo => 'Salvar em…';
  @override
  String get onThePedal => 'Na pedaleira. Salve para manter.';
  @override
  String get effectDataNotLoaded =>
      'Os dados dos efeitos ainda não foram carregados';
  @override
  String get downloadFailed =>
      'Não foi possível baixar o preset. Verifique a conexão e tente de novo.';
  @override
  String usesCfwModel(String name) => 'Usa $name, que precisa do firmware CFW';
  @override
  String get sendFailed => 'Não foi possível enviar o preset para a pedaleira';
  @override
  String get notACatalogue =>
      'Não é um catálogo da comunidade que este app consiga ler';

  @override
  String unsupportedPresetVersion(Object? version) =>
      'Versão de preset não suportada: $version';
  @override
  String unknownEffect(String module, String effect) =>
      'O módulo "$module" usa um efeito desconhecido: "$effect"';

  @override
  String get exportDialogTitle => 'Exportar preset';
  @override
  String exportedTo(String path) => 'exportado para $path';
  @override
  String exportFailed(Object e) => 'falha ao exportar: $e';
  @override
  String get importDialogTitle => 'Importar preset';
  @override
  String importFailed(Object e) => 'falha ao importar: $e';
  @override
  String needsCfw(String name) =>
      'falha ao importar: $name precisa do firmware CFW';
  @override
  String imported(int skipped, int warnings) =>
      'importado${skipped > 0 ? ', $skipped ignorado(s)' : ''}'
      '${warnings > 0 ? ' ($warnings aviso(s))' : ''}';
  @override
  String importPushFailed(Object e) => 'falha ao enviar o preset importado: $e';

  @override
  String get dataLoadFailed => 'falha ao carregar os dados';
  @override
  String get dataLoading => 'dados ainda carregando…';
  @override
  String noCommandFor(String label) => 'sem comando para $label';
  @override
  String loaded(String label) => '$label carregado';
  @override
  String noAck(String label) => '$label: sem ACK (tempo esgotado)';
  @override
  String sendFailedFor(String label, Object e) => '$label: falha no envio — $e';
  @override
  String editFailed(Object e) => 'falha na edição: $e';
  @override
  String get reorderUnavailable => 'reordenação indisponível';
  @override
  String get saveNoAck => 'salvar: sem ACK (tempo esgotado)';
  @override
  String savedTo(String name, String slot) => '"$name" salvo em $slot';
  @override
  String saveFailed(Object e) => 'falha ao salvar: $e';
  @override
  String get factoryReset => 'restauração de fábrica — pedaleira reiniciando';
  @override
  String resetFailed(Object e) => 'falha na restauração: $e';
}
