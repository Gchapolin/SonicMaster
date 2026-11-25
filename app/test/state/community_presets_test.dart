import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/device/device_service.dart';
import 'package:sonicmaster/model/community_catalog.dart';
import 'package:sonicmaster/state/community_presets.dart';
import 'package:sonicmaster/state/data_providers.dart';
import 'package:sonicmaster/state/device_providers.dart';

import '../support/silent_transport.dart';
import '../support/test_assets.dart';

class _Spy extends DeviceService {
  _Spy() : super(SilentTransport());

  final sent = <String>[];

  @override
  Future<void> sendFrame(String frameHex) async => sent.add(frameHex);

  @override
  Future<String?> requestStateDump({
    Duration timeout = const Duration(seconds: 1),
  }) async => null;
}

const _preset = CommunityPreset(id: 'a', name: 'Clean', file: 'presets/a.json');

String _presetJson(String effect) => jsonEncode({
  'version': '1.0',
  'ampMode': 'Normal',
  'modules': {
    'NR': {
      'enabled': true,
      'effect': effect,
      'parameters': {'THRE': 8},
    },
  },
  'signalChain': ['NR'],
});

void main() {
  late List<Uri> fetched;

  Future<(WidgetRef, ProviderContainer, _Spy)> pump(
    WidgetTester tester,
    Future<String> Function(Uri) fetch,
  ) async {
    fetched = [];

    final spy = _Spy();
    final c = ProviderContainer(
      overrides: [
        deviceServiceProvider.overrideWithValue(spy),
        dataAssetsProvider.overrideWith((_) => loadTestDataAssets()),
        communityFetchProvider.overrideWithValue((u) {
          fetched.add(u);

          return fetch(u);
        }),
      ],
    );

    addTearDown(c.dispose);

    late WidgetRef ref;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: Consumer(
          builder: (_, r, _) {
            ref = r;

            return const SizedBox();
          },
        ),
      ),
    );
    await c.read(dataAssetsProvider.future);

    return (ref, c, spy);
  }

  testWidgets('the catalogue comes from the CFW app\'s community folder', (
    tester,
  ) async {
    final (_, c, _) = await pump(
      tester,
      (_) async => jsonEncode({
        'type': 'sonicake-cfw-community-catalog',
        'schema': 1,
        'presets': [
          {'id': 'a', 'name': 'Clean', 'file': 'presets/a.json'},
        ],
      }),
    );

    final list = await c.read(communityCatalogProvider.future);

    expect(list.single.name, 'Clean');
    expect(fetched.single.toString(), '${communityBaseUrl}catalog.json');
  });

  testWidgets('Try downloads the preset file and sends it to the pedal', (
    tester,
  ) async {
    final (ref, _, spy) = await pump(tester, (_) async => _presetJson('Gate'));

    final error = await tester.runAsync(() => tryCommunityPreset(ref, _preset));

    expect(error, isNull);
    expect(fetched.single.toString(), '${communityBaseUrl}presets/a.json');
    expect(spy.sent, isNotEmpty);
  });

  testWidgets('an effect the app does not know: a message, nothing sent', (
    tester,
  ) async {
    final (ref, _, spy) = await pump(
      tester,
      (_) async => _presetJson('Some CFW Model'),
    );

    final error = await tester.runAsync(() => tryCommunityPreset(ref, _preset));

    expect(error, contains('Some CFW Model'));
    expect(spy.sent, isEmpty);
  });

  testWidgets('a failed download: a message, nothing sent', (tester) async {
    final (ref, _, spy) = await pump(
      tester,
      (_) async => throw Exception('offline'),
    );

    final error = await tester.runAsync(() => tryCommunityPreset(ref, _preset));

    expect(error, contains('Could not download'));
    expect(spy.sent, isEmpty);
  });
}
