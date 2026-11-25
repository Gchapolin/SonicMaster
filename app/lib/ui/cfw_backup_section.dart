import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../protocol/cfw_backup.dart';
import '../state/cfw_backup_io.dart';
import '../state/cfw_providers.dart';
import '../state/data_providers.dart';
import '../state/device_providers.dart';
import '../state/file_download.dart';
import '../state/preset_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'sonic_controls.dart';

/// Saves a backup file: (file name, bytes, dialog title) -> where it went,
/// null when cancelled. Overridden in tests.
final backupFileSaverProvider =
    Provider<Future<String?> Function(String, List<int>, String)>(
      (_) =>
          (name, bytes, title) => saveBytesFile(
            fileName: name,
            bytes: bytes,
            dialogTitle: title,
            extensions: const ['json'],
          ),
    );

/// Picks a backup file and returns its text; null when cancelled.
/// Overridden in tests.
final backupFilePickerProvider = Provider<Future<String?> Function()>(
  (_) => () async {
    final res = await FilePicker.platform.pickFiles(
      dialogTitle: 'Restore the pedal',
      type: .custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final bytes = res?.files.single.bytes;

    return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
  },
);

/// The CFW's whole-pedal backup: one file with the 50 User presets as the
/// pedal stores them, their scenes and EXP A-D, the settings, the Global EQ
/// and the User IR / Clone data, in the CFW web app's format, and the restore
/// of such a file (made here or by the CFW app). Shown for CFW pedals only.
class CfwBackupSection extends HookConsumerWidget {
  const CfwBackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(presetLoadingProvider);
    final isBusy = useState(false);
    final progress = useState<String?>(null);
    final status = useState<String?>(null);
    final notes = useState<List<String>>(const []);

    void onProgress(String step, int done, int total) {
      if (context.mounted) progress.value = '$step ($done/$total)';
    }

    void finish(String message, [List<String> extra = const []]) {
      if (!context.mounted) return;

      isBusy.value = false;
      progress.value = null;
      status.value = message;
      notes.value = extra;
    }

    /// Reads the whole pedal with the heartbeat held off; null after a
    /// failed read (already reported).
    Future<CfwBackup?> readPedal(String failure) async {
      final cfw = ref.read(cfwInfoProvider);
      final service = ref.read(deviceServiceProvider);
      final loading = ref.read(presetLoadingProvider.notifier);

      if (cfw == null) return null;

      loading.state = true;
      try {
        return await readPedalBackup(
          service,
          cfw,
          app: 'SonicMaster',
          onProgress: onProgress,
        );
      } on CfwBackupException catch (e) {
        finish('$failure: ${e.message}. Nothing was saved.');
      } catch (e) {
        finish('$failure: $e. Nothing was saved.');
      } finally {
        if (loading.mounted) loading.state = false;
      }

      return null;
    }

    Future<void> backUp() async {
      final save = ref.read(backupFileSaverProvider);

      isBusy.value = true;
      status.value = null;
      notes.value = const [];

      final b = await readPedal('Backup failed');

      if (b == null) return;

      try {
        final path = await save(
          cfwBackupFileName(b),
          utf8.encode(encodeCfwBackup(b)),
          'Save the pedal backup',
        );

        finish(
          path == null
              ? 'Backup read, not saved (cancelled)'
              : 'Backup saved: $path',
        );
      } catch (e) {
        finish('Backup read, not saved: $e');
      }
    }

    Future<void> restore() async {
      final pick = ref.read(backupFilePickerProvider);
      final save = ref.read(backupFileSaverProvider);
      final service = ref.read(deviceServiceProvider);
      final loading = ref.read(presetLoadingProvider.notifier);
      final commands = ref.read(dataAssetsProvider).valueOrNull?.commands;

      status.value = null;
      notes.value = const [];

      final text = await pick();

      if (text == null || !context.mounted) return;

      final (file, errors) = parseCfwBackup(text);

      if (file == null) {
        finish('Restore refused: ${errors.join('; ')}');

        return;
      }

      isBusy.value = true;

      final current = await readPedal('Restore not started');
      final cfw = ref.read(cfwInfoProvider);

      if (current == null || cfw == null || !context.mounted) return;

      final (plan, refusal) = planRestore(file, current, cfw);

      if (plan == null) {
        finish('Restore refused: $refusal');

        return;
      }

      progress.value = null;

      final isConfirmed = await showSonicDialog<bool>(
        context: context,
        builder: (_) => _RestoreConfirm(file: file, plan: plan),
      );

      if (isConfirmed != true || plan.isEmpty) {
        finish(
          plan.isEmpty
              ? 'Nothing differs from the pedal: nothing to write'
              : 'Restore cancelled: nothing was written',
          plan.notes,
        );

        return;
      }

      final before = await save(
        cfwBackupFileName(current, suffix: '-before-restore'),
        utf8.encode(encodeCfwBackup(current)),
        'Save the pedal as it is now (before the restore)',
      );

      if (before == null) {
        finish(
          'Restore cancelled: the backup of the pedal as it is now was not '
          'saved; nothing was written',
        );

        return;
      }

      RestoreResult result;

      loading.state = true;
      try {
        result = await runRestore(
          service,
          plan,
          globalFrame: (name, value, type) => commands == null
              ? null
              : globalRestoreFrame(commands, name, value, type),
          onProgress: onProgress,
        );
      } catch (e) {
        result = RestoreResult(isOk: false, message: '$e', notes: const []);
      } finally {
        if (loading.mounted) loading.state = false;
      }

      finish(
        result.isOk
            ? '${result.message}. Before-restore backup: $before'
            : '${result.message}. Load the same file again to resume. '
                  'Before-restore backup: $before',
        [...plan.notes, ...result.notes],
      );

      // The pedal changed under the app: read back what it shows.
      if (!context.mounted) return;

      await refreshNamesThenCfw(ref);
      if (context.mounted) await refreshGlobalSettings(ref);
    }

    final isEnabled = !isLoading && !isBusy.value;
    final muted = AppText.dialogBody.copyWith(color: Palette.onSurfaceVariant);

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        Text(
          'One file with the 50 User presets exactly as the pedal stores '
          'them, their scenes and EXP A–D, the pedal and CFW settings, the '
          'Global EQ and the User IR / Clone data. Same format as the CFW web '
          'app: its backups restore here and the other way round. USB '
          'recommended (Bluetooth is slow).',
          style: muted,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SonicButton(
                label: 'Back up now',
                onPressed: isEnabled ? backUp : null,
              ),
              const SizedBox(width: 10),
              SonicButton(
                label: 'Restore…',
                onPressed: isEnabled ? restore : null,
              ),
              if (isBusy.value) ...[
                const SizedBox(width: 12),
                const SonicSpinner(size: 20),
              ],
            ],
          ),
        ),
        if (progress.value case final p?) Text(p, style: muted),
        if (isBusy.value)
          Text(
            "Don't touch the pedal until it ends.",
            style: AppText.dialogBody,
          ),
        if (status.value case final s?) Text(s, style: AppText.dialogBody),
        if (notes.value.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Not restored / plays differently here:', style: muted),
          for (final n in notes.value.take(30)) Text('• $n', style: muted),
          if (notes.value.length > 30)
            Text('… ${notes.value.length - 30} more', style: muted),
        ],
      ],
    );
  }
}

/// What a restore will overwrite, with an explicit Restore / Cancel.
class _RestoreConfirm extends StatelessWidget {
  const _RestoreConfirm({required this.file, required this.plan});

  final CfwBackup file;
  final RestorePlan plan;

  @override
  Widget build(BuildContext context) {
    final muted = AppText.dialogBody.copyWith(color: Palette.onSurfaceVariant);
    final made = file.created.toLocal().toString().substring(0, 16);

    return SonicDialog(
      maxWidth: 440,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Text(
            plan.isEmpty ? 'Nothing to restore' : 'Restore this backup?',
            style: AppText.dialogTitle,
          ),
          const SizedBox(height: 8),
          Text(
            'Made $made on the ${file.pedal.model} '
            '${file.pedal.cfwTag ?? ''} by ${file.app}.',
            style: muted,
          ),
          const SizedBox(height: 10),
          if (!plan.isEmpty)
            const Text('Overwrites on the pedal:', style: AppText.dialogBody),
          for (final line in plan.overwrites)
            Text('• $line', style: AppText.dialogBody),
          if (plan.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Not restored / plays differently here:', style: muted),
            for (final n in plan.notes.take(30)) Text('• $n', style: muted),
            if (plan.notes.length > 30)
              Text('… ${plan.notes.length - 30} more', style: muted),
          ],
          if (!plan.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'This rewrites the pedal’s memory. A backup of the pedal as it '
              'is now is saved first; each preset written is read back. If '
              'the restore stops, load the same file again to resume.',
              style: muted,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: .end,
            children: [
              SonicButton(
                label: plan.isEmpty ? 'Close' : 'Cancel',
                onPressed: () => Navigator.pop(context, false),
              ),
              if (!plan.isEmpty) ...[
                const SizedBox(width: 10),
                SonicButton(
                  label: 'Restore',
                  isAccent: true,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
