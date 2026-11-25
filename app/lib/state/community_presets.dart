import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Downloads [preset] and pushes it to the pedal's live state, like Import
/// preset (Save keeps it). Returns null on success, else why it failed.
Future<String?> tryCommunityPreset(
  WidgetRef ref,
  CommunityPreset preset,
) async {
  final data = ref.read(dataAssetsProvider).valueOrNull;

  if (data == null) return 'The effect data is not loaded yet';

  final ImportedPreset imported;

  try {
    final text = await ref.read(communityFetchProvider)(
      Uri.parse(communityBaseUrl).resolve(preset.file),
    );

    imported = importedPresetFromJson(
      jsonDecode(text) as Map<String, dynamic>,
      data,
    );
  } on FormatException catch (e) {
    // Mostly an effect this app cannot select yet (a CFW-only model).
    return e.message;
  } catch (_) {
    return 'Could not download the preset. Check the connection and retry.';
  }

  return await pushImportedPreset(ref, imported)
      ? null
      : 'The preset could not be sent to the pedal';
}
