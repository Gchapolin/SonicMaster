import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/community_catalog.dart';

String _catalog({
  String type = 'sonicake-cfw-community-catalog',
  int schema = 1,
  List<Object?> presets = const [],
}) => jsonEncode({
  'type': type,
  'schema': schema,
  'updated': '2026-11-16',
  'presets': presets,
});

const _entry = {
  'id': '2026-11-13_a_clean',
  'name': 'Clean',
  'pedal': 'PM',
  'fw': 'CFW1.0',
  'author': 'Someone',
  'authorLink': 'https://example.com',
  'authorLinkLabel': 'Example',
  'genres': ['Ambient', 'Rock'],
  'description': 'A clean sound.',
  'guitar': 'Humbucker',
  'tuning': 'Standard',
  'voicedFor': 'headphones,frfr',
  'controls': 'no STOMP',
  'file': 'presets/2026-11-13_a_clean.json',
  'sha256': 'ab',
  'audio': null,
  'audioSeconds': null,
  'added': '2026-11-13',
};

void main() {
  test('reads each preset entry', () {
    final list = decodeCommunityCatalog(_catalog(presets: [_entry]));

    expect(list, hasLength(1));

    final p = list.single;

    expect(p.id, '2026-11-13_a_clean');
    expect(p.name, 'Clean');
    expect(p.author, 'Someone');
    expect(p.genres, ['Ambient', 'Rock']);
    expect(p.description, 'A clean sound.');
    expect(p.guitar, 'Humbucker');
    expect(p.tuning, 'Standard');
    expect(p.controls, 'no STOMP');
    expect(p.file, 'presets/2026-11-13_a_clean.json');
  });

  test('missing optional text stays null', () {
    final list = decodeCommunityCatalog(
      _catalog(
        presets: [
          {'id': 'x', 'name': 'X', 'file': 'presets/x.json'},
        ],
      ),
    );

    expect(list.single.author, isNull);
    expect(list.single.genres, isEmpty);
  });

  test('entries without a name or file are skipped', () {
    final list = decodeCommunityCatalog(
      _catalog(
        presets: [
          {'id': 'x', 'name': 'X'},
          'junk',
          _entry,
        ],
      ),
    );

    expect(list.map((p) => p.name), ['Clean']);
  });

  test('not a catalog, or a newer schema: FormatException', () {
    expect(
      () => decodeCommunityCatalog(_catalog(type: 'other')),
      throwsFormatException,
    );
    expect(
      () => decodeCommunityCatalog(_catalog(schema: 2)),
      throwsFormatException,
    );
    expect(() => decodeCommunityCatalog('<html>'), throwsFormatException);
  });
}
