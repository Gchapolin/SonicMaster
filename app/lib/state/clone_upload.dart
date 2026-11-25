import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device/device_service.dart';
import '../l10n/slots_text.dart';
import '../protocol/clo_generator.dart';
import '../protocol/clo_upload_frame.dart';
import '../protocol/nam_format.dart';
import 'device_providers.dart';
import 'import_exception.dart';
import 'preset_providers.dart';

/// Prompts for a `.nam` to load into User-Profile [slot] (0-based), reads its
/// bytes (works on web, where there is no file path), and returns the JSON text
/// + display name, or null if the user cancels.
Future<({String namJson, String name})?> pickNamForClone(int slot) async {
  final res = await FilePicker.platform.pickFiles(
    dialogTitle: SlotsText.current.pickNamTitle(slot + 1),
    type: .custom,
    allowedExtensions: const ['nam'],
    withData: true,
  );

  final picked = res?.files.single;
  final bytes = picked?.bytes;

  if (picked == null || bytes == null) return null;

  return (namJson: utf8.decode(bytes), name: picked.name);
}

/// Checks [namJson] is a supported model format, returning it unchanged. Throws
/// [UnsupportedNamFormat] when the converter can't clone the architecture.
String validateNam(String namJson) {
  assertNamSupported(namJson);

  return namJson;
}

/// Converts [namJson] natively to a clone `.clo` ([CloGenerator]) and uploads it
/// into User-Profile [slot], driving the shared status text and the clone-import
/// progress fraction (for the progress modal). Throws [ImportException] on
/// failure — the caller shows the error dialog.
Future<void> convertAndUploadClone(
  WidgetRef ref, {
  required int slot,
  required String namJson,
  required String fileName,
}) async {
  final status = ref.read(presetLoadStatusProvider.notifier);

  ref.read(presetLoadingProvider.notifier).state = true;
  ref.read(importProgressProvider.notifier).state = null;

  final name = _slotName(fileName);

  try {
    status.state = SlotsText.current.convertingNam;
    final profile = await const CloGenerator().fromNam(namJson);

    final chunks = CloUploadFrame.buildChunks(
      CloUploadFrame.buildBlob(slot: slot, name: name, profile: profile),
    );

    final result = await _writeCloneSlot(
      ref,
      chunks,
      onProgress: (sent, total) {
        ref.read(importProgressProvider.notifier).state = total == 0
            ? null
            : sent / total;
        status.state = '${SlotsText.current.uploadingClone} $sent/$total';
      },
    );

    status.state = switch (result) {
      .committed => SlotsText.current.cloneCommitted(name, slot + 1),
      .noAck => SlotsText.current.cloneUploadNoAck,
      .notCommitted => SlotsText.current.cloneNotCommitted,
    };

    if (result != .committed) {
      throw ImportException(
        status.state ?? SlotsText.current.cloneUploadFailed,
      );
    }
  } on ImportException {
    rethrow;
  } catch (e) {
    status.state = SlotsText.current.namConvertFailed(e);

    throw ImportException(
      SlotsText.current.conversionFailed(e),
      isFormatError: looksLikeNamFormatError(e),
    );
  } finally {
    ref.read(presetLoadingProvider.notifier).state = false;
    ref.read(importProgressProvider.notifier).state = null;
  }
}

/// Renames User-Profile [slot] (0-based) to [name] on the pedal (a short
/// clone-rename command; the profile audio is untouched), then refreshes names.
Future<void> renameCloneSlot(WidgetRef ref, int slot, String name) =>
    _runCloneCommand(
      ref,
      CloUploadFrame.buildChunks(
        CloUploadFrame.buildRenameBlob(slot: slot, name: name),
      ),
      busy: SlotsText.current.renaming,
      done: SlotsText.current.renamedProfile(slot + 1),
    );

/// Clears User-Profile [slot] (0-based) on the pedal, then refreshes the names.
Future<void> clearCloneSlot(WidgetRef ref, int slot) => _runCloneCommand(
  ref,
  CloUploadFrame.buildChunks(CloUploadFrame.buildClearBlob(slot: slot)),
  busy: SlotsText.current.clearing,
  done: SlotsText.current.clearedProfile(slot + 1),
);

/// Sends a small chunked clone command (rename/clear) with the same commit flow
/// as an upload. No-op if a load is in flight.
Future<void> _runCloneCommand(
  WidgetRef ref,
  List<String> chunks, {
  required String busy,
  required String done,
}) async {
  if (ref.read(presetLoadingProvider)) return;

  final status = ref.read(presetLoadStatusProvider.notifier);

  ref.read(presetLoadingProvider.notifier).state = true;

  try {
    status.state = busy;
    final result = await _writeCloneSlot(ref, chunks);

    status.state = switch (result) {
      .committed => done,
      .noAck => SlotsText.current.cloneCommandNoAck,
      .notCommitted => SlotsText.current.notCommitted,
    };
  } catch (e) {
    status.state = SlotsText.current.cloneCommandFailed(e);
  } finally {
    ref.read(presetLoadingProvider.notifier).state = false;
  }
}

/// Writes clone [chunks] to a User-Profile slot, mirroring the tool's sequence:
/// read profile names to enter the clone context (`020204`), send the chunks,
/// await the flash commit, then re-read the names. The commit is device state,
/// not the wire — after some ops the pedal latches non-committing until a
/// power-cycle, surfaced as [IrWriteResult.notCommitted].
Future<IrWriteResult> _writeCloneSlot(
  WidgetRef ref,
  List<String> chunks, {
  void Function(int sent, int total)? onProgress,
}) async {
  await refreshCloneNames(ref); // 020204 — enter clone context

  final service = ref.read(deviceServiceProvider);

  final result = await service.uploadClone(chunks, onProgress: onProgress);

  await refreshCloneNames(ref);

  return result;
}

/// The pedal stores a 15-char profile name; derive it from the file name
/// (extension dropped). [CloUploadFrame] truncates to the limit.
String _slotName(String fileName) {
  final dot = fileName.lastIndexOf('.');

  return dot > 0 ? fileName.substring(0, dot) : fileName;
}
