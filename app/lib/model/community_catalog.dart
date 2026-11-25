import 'dart:convert';

import '../l10n/presets_text.dart';

/// Where the Sonicake CFW web app publishes its community presets: the
/// catalogue is `catalog.json`, each preset file is relative to it.
const communityBaseUrl =
    'https://pocketmaster-cfw.guitar-training-generator.com/app/community/';

/// One entry of the community catalogue; the preset itself is the JSON at
/// [file] (the app's own preset export format, plus the CFW extras).
class CommunityPreset {
  const CommunityPreset({
    required this.id,
    required this.name,
    required this.file,
    this.author,
    this.genres = const [],
    this.description,
    this.guitar,
    this.tuning,
    this.controls,
  });

  final String id;
  final String name;
  final String file;
  final String? author;
  final List<String> genres;
  final String? description;
  final String? guitar;
  final String? tuning;
  final String? controls;
}

/// Parses the catalogue (`type` sonicake-cfw-community-catalog, schema 1).
/// Throws [FormatException] when it is not one; skips malformed entries.
List<CommunityPreset> decodeCommunityCatalog(String text) {
  final json = jsonDecode(text);

  if (json is! Map ||
      json['type'] != 'sonicake-cfw-community-catalog' ||
      json['schema'] is! int ||
      (json['schema'] as int) > 1) {
    throw FormatException(PresetsText.current.notACatalogue);
  }

  String? str(Map e, String key) => e[key] is String ? e[key] as String : null;

  return [
    for (final e in (json['presets'] as List?) ?? const [])
      if (e is Map && str(e, 'name') != null && str(e, 'file') != null)
        CommunityPreset(
          id: str(e, 'id') ?? str(e, 'file')!,
          name: str(e, 'name')!,
          file: str(e, 'file')!,
          author: str(e, 'author'),
          genres: [...((e['genres'] as List?) ?? const []).whereType<String>()],
          description: str(e, 'description'),
          guitar: str(e, 'guitar'),
          tuning: str(e, 'tuning'),
          controls: str(e, 'controls'),
        ),
  ];
}
