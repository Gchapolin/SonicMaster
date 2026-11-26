import 'package:sonicmaster/protocol/cfw_backup.dart';
import 'package:sonicmaster/state/cfw_backup_io.dart';
import 'package:sonicmaster/state/cfw_providers.dart';

import 'backup_fixtures.dart';
import 'fake_cfw_pedal.dart';

/// A backup of [pedal] with preset P02 changed (and, with [withOrder], a
/// preset order, which the restore reports as a note).
Future<String> changedBackup(
  FakeCfwPedal pedal, {
  bool withOrder = false,
}) async {
  final b = await readPedalBackup(pedal, testCfwInfo(), app: 'test');

  pedal.reads.clear();

  return encodeCfwBackup(
    CfwBackup(
      created: b.created,
      app: b.app,
      pedal: b.pedal,
      sections: b.sections,
      presets: [
        for (final p in b.presets)
          p.index == 1
              ? BackupPreset(index: 1, record: testPresetRecord('New'))
              : p,
      ],
      cfwSettings: b.cfwSettings,
      order: withOrder ? List.generate(50, (i) => i) : null,
    ),
  );
}
