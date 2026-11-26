import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/presets_text.dart';
import '../model/community_catalog.dart';
import '../model/preset_json.dart';
import 'data_providers.dart';
import 'http_get.dart';
import 'preset_io.dart';

/// How the app fetches community files (overridden in tests).
final communityFetchProvider = Provider<Future<String> Function(Uri)>(
  (_) => httpGetText,
);

/// The community catalogue, fetched once per session; invalidate to retry.
final communityCatalogProvider = FutureProvider<List<CommunityPreset>>((
  ref,
) async {
  final fetch = ref.watch(communityFetchProvider);

  return decodeCommunityCatalog(
    await fetch(Uri.parse('${communityBaseUrl}catalog.json')),
  );
});

/// At most this many preset files download at once (a catalogue has dozens).
const _maxParallelFiles = 3;

/// Waiting slots for [communityFileProvider] downloads.
class _FileGate {
  var _running = 0;
  final _waiting = <Completer<void>>[];

  Future<T> run<T>(Future<T> Function() job) async {
    if (_running >= _maxParallelFiles) {
      final c = Completer<void>();
      _waiting.add(c);
      await c.future;
    } else {
      _running++;
    }

    try {
      return await job();
    } finally {
      if (_waiting.isEmpty) {
        _running--;
      } else {
        _waiting.removeAt(0).complete();
      }
    }
  }
}

final _fileGate = Provider<_FileGate>((_) => _FileGate());

/// The text of one community file by absolute URL, downloaded once per
/// session (the card thumbnail and Try share it). A failure is not kept: the
/// provider disposes when nobody watches it, and [tryCommunityPreset]
/// invalidates an errored one before reading.
final communityFileProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, url) async {
    final fetch = ref.watch(communityFetchProvider);
    final text = await ref.read(_fileGate).run(() => fetch(Uri.parse(url)));

    ref.keepAlive();

    return text;
  },
);

/// The absolute URL of [preset]'s file.
String communityFileUrl(CommunityPreset preset) =>
    Uri.parse(communityBaseUrl).resolve(preset.file).toString();

/// Downloads [preset] and pushes it to the pedal's live state, like Import
/// preset (Save keeps it). Returns null on success, else why it failed.
Future<String?> tryCommunityPreset(
  WidgetRef ref,
  CommunityPreset preset,
) async {
  final data = ref.read(dataAssetsProvider).valueOrNull;

  if (data == null) return PresetsText.current.effectDataNotLoaded;

  final ImportedPreset imported;

  try {
    final file = communityFileProvider(communityFileUrl(preset));

    // A failed download stays in the provider while a card watches it.
    if (ref.read(file).hasError) ref.invalidate(file);

    final text = await ref.read(file.future);

    imported = importedPresetFromJson(
      jsonDecode(text) as Map<String, dynamic>,
      data,
    );
  } on FormatException catch (e) {
    // Mostly an effect this app cannot select yet (a CFW-only model).
    return e.message;
  } catch (_) {
    return PresetsText.current.downloadFailed;
  }

  if (cfwOnlyEffectName(ref, imported) case final name?) {
    return PresetsText.current.usesCfwModel(name);
  }

  return await pushImportedPreset(ref, imported)
      ? null
      : PresetsText.current.sendFailed;
}
