// Live gate for the community presets on a real device — network only, no
// pedal: downloads the CFW community catalogue and every preset file, and
// converts each one, writing the outcome to <app tmp>/community_live.txt.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sonicmaster/model/community_catalog.dart';
import 'package:sonicmaster/model/data_assets.dart';
import 'package:sonicmaster/model/preset_json.dart';
import 'package:sonicmaster/state/http_get.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('community catalogue over the network', (tester) async {
    final out = File('${Directory.systemTemp.path}/community_live.txt');

    out.writeAsStringSync('START ${DateTime.now().toIso8601String()}\n');
    void log(String line) =>
        out.writeAsStringSync('$line\n', mode: FileMode.append);

    try {
      final data = await DataAssets.load();
      final list = decodeCommunityCatalog(
        await httpGetText(Uri.parse('${communityBaseUrl}catalog.json')),
      );

      log('CATALOG ${list.length}');

      for (final p in list) {
        try {
          final text = await httpGetText(
            Uri.parse(communityBaseUrl).resolve(p.file),
          );
          final imp = importedPresetFromJson(
            jsonDecode(text) as Map<String, dynamic>,
            data,
          );

          log(
            'OK ${p.name} fs=${imp.footswitch} '
            'scenes=${imp.scenes?.keys.toList()} warn=${imp.warnings.length}',
          );
        } catch (e) {
          log('NO ${p.name}: $e');
        }
      }

      log('DONE');
    } catch (e, st) {
      log('ERROR $e\n$st');
    }
  });
}
