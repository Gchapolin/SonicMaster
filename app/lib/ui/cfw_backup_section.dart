import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/backup_text.dart';
import '../l10n/common_text.dart';
import '../l10n/settings_text.dart';
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
      dialogTitle: BackupText.current.pickTitle,
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
    final t = BackupText.current;
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
        finish(t.readFailed(failure, e.message));
      } catch (e) {
        finish(t.readFailed(failure, '$e'));
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

      final b = await readPedal(t.backupFailed);

      if (b == null) return;

      try {
        final path = await save(
          cfwBackupFileName(b),
          utf8.encode(encodeCfwBackup(b)),
          t.saveTitle,
        );

        finish(path == null ? t.backupCancelled : t.backupSaved(path));
      } catch (e) {
        finish(t.backupNotSaved(e));
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
        finish(t.restoreRefused(errors.join('; ')));

        return;
      }

      isBusy.value = true;

      final current = await readPedal(t.restoreNotStarted);
      final cfw = ref.read(cfwInfoProvider);

      if (current == null || cfw == null || !context.mounted) return;

      final (plan, refusal) = planRestore(file, current, cfw);

      if (plan == null) {
        finish(t.restoreRefused(refusal!));

        return;
      }

      progress.value = null;

      final isConfirmed = await showSonicDialog<bool>(
        context: context,
        builder: (_) => _RestoreConfirm(file: file, plan: plan),
      );

      if (isConfirmed != true || plan.isEmpty) {
        finish(
          plan.isEmpty ? t.nothingDiffers : t.restoreCancelled,
          plan.notes,
        );

        return;
      }

      final before = await save(
        cfwBackupFileName(current, suffix: '-before-restore'),
        utf8.encode(encodeCfwBackup(current)),
        t.saveBeforeTitle,
      );

      if (before == null) {
        finish(t.beforeNotSaved);

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
            ? t.restoreDone(result.message, before)
            : t.restoreStopped(result.message, before),
        [...plan.notes, ...result.notes],
      );

      // The pedal changed under the app: read back what it shows.
      if (!context.mounted) return;

      await refreshNamesThenCfw(ref);
      if (context.mounted) await refreshGlobalSettings(ref);
    }

    final isEnabled = !isLoading && !isBusy.value;
    final muted = AppText.dialogBody.copyWith(color: Palette.onSurfaceVariant);

    final rowLabel = AppText.ui.copyWith(color: Palette.onSurfaceVariant);
    Widget row(String label, Widget button) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: .ellipsis,
              style: rowLabel,
            ),
          ),
          button,
        ],
      ),
    );

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 4,
      children: [
        Semantics(
          label: t.intro,
          child: row(
            SettingsText.current.backupRow,
            Row(
              mainAxisSize: .min,
              spacing: 8,
              children: [
                if (isBusy.value) const SonicSpinner(size: 20),
                SonicButton(
                  label: t.backUpNow,
                  height: 34,
                  minWidth: 0,
                  isAccent: true,
                  onPressed: isEnabled ? backUp : null,
                ),
              ],
            ),
          ),
        ),
        row(
          SettingsText.current.restoreRow,
          SonicButton(
            label: t.restoreEllipsis,
            height: 34,
            minWidth: 0,
            onPressed: isEnabled ? restore : null,
          ),
        ),
        Text(
          SettingsText.current.usbRecommended,
          style: AppText.ui.copyWith(color: Palette.outline, fontSize: 12),
        ),
        if (progress.value case final p?) Text(p, style: muted),
        if (isBusy.value) Text(t.dontTouch, style: AppText.dialogBody),
        if (status.value case final s?) Text(s, style: AppText.dialogBody),
        if (notes.value.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(t.notRestoredHeader, style: muted),
          for (final n in notes.value.take(30)) Text('• $n', style: muted),
          if (notes.value.length > 30)
            Text(t.more(notes.value.length - 30), style: muted),
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
    final t = BackupText.current;
    final muted = AppText.dialogBody.copyWith(color: Palette.onSurfaceVariant);
    final made = file.created.toLocal().toString().substring(0, 16);

    return SonicDialog(
      maxWidth: 440,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Text(
            plan.isEmpty ? t.nothingToRestore : t.confirmTitle,
            style: AppText.dialogTitle,
          ),
          const SizedBox(height: 8),
          Text(
            t.made(made, file.pedal.model, file.pedal.cfwTag ?? '', file.app),
            style: muted,
          ),
          const SizedBox(height: 10),
          if (!plan.isEmpty)
            Text(t.overwritesHeader, style: AppText.dialogBody),
          for (final line in plan.overwrites)
            Text('• $line', style: AppText.dialogBody),
          if (plan.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(t.notRestoredHeader, style: muted),
            for (final n in plan.notes.take(30)) Text('• $n', style: muted),
            if (plan.notes.length > 30)
              Text(t.more(plan.notes.length - 30), style: muted),
          ],
          if (!plan.isEmpty) ...[
            const SizedBox(height: 10),
            Text(t.confirmWarning, style: muted),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: .end,
            children: [
              SonicButton(
                label: plan.isEmpty
                    ? CommonText.current.close
                    : CommonText.current.cancel,
                onPressed: () => Navigator.pop(context, false),
              ),
              if (!plan.isEmpty) ...[
                const SizedBox(width: 10),
                SonicButton(
                  label: t.restore,
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
