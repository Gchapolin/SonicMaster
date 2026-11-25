import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/cfw_scenes.dart';
import 'package:sonicmaster/protocol/cfw_scene_codec.dart';
import 'package:sonicmaster/protocol/cfw_settings_decoder.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';

/// Payloads captured from the CFW web app (docs/cfw-protocol/capture-notes.md).
List<int> payload(String frame) => collapseFrame(frame)!.sublist(4);

const f23 = [0x00, 0x00, 0xb8, 0x41];
const f33 = [0x00, 0x00, 0x04, 0x42];
const f44 = [0x00, 0x00, 0x30, 0x42];
const f46 = [0x00, 0x00, 0x38, 0x42];
const f88 = [0x00, 0x00, 0xb0, 0x42];
const f96 = [0x00, 0x00, 0xc0, 0x42];

void main() {
  test('a module that only takes part in scenes', () {
    expect(payload(buildSceneRecordFrame(const SceneRecord(module: 0))), [
      0x11,
      0x33,
      0x00,
      0x01,
      0x00,
      0x00,
    ]);
  });

  test('one SC1 value', () {
    expect(
      payload(
        buildSceneRecordFrame(const SceneRecord(module: 0, sc1: {0: 23})),
      ),
      [0x11, 0x33, 0x00, 0x01, 0x01, 0x00, ...f23],
    );
  });

  test('module on/off overrides set the flag bits', () {
    List<int> flags(SceneRecord r) =>
        payload(buildSceneRecordFrame(r)).sublist(2, 4);

    expect(flags(const SceneRecord(module: 0, sc1On: false)), [0x00, 0x03]);
    expect(flags(const SceneRecord(module: 0, sc1On: true)), [0x00, 0x07]);
    expect(flags(const SceneRecord(module: 3, sc2On: false)), [0x03, 0x09]);
    expect(flags(const SceneRecord(module: 3, sc2On: true)), [0x03, 0x19]);
  });

  test('SC1 values in algId order, then SC2 values', () {
    expect(
      payload(
        buildSceneRecordFrame(
          const SceneRecord(
            module: 3,
            sc2On: false,
            sc1: {1: 96, 0: 46},
            sc2: {1: 88},
          ),
        ),
      ),
      [0x11, 0x33, 0x03, 0x09, 0x03, 0x02, ...f46, ...f96, ...f88],
    );
  });

  test('scene select and the read frames', () {
    expect(payload(selectSceneFrame(1)), [0x11, 0x32, 0x01]);
    expect(payload(readSceneRecordsFrame()), [0x12, 0x33]);
    expect(payload(readCurrentSceneFrame()), [0x12, 0x32]);
  });

  test('an empty read has no records', () {
    final reply = buildSysexWriteFrame([
      0x12,
      0x33,
      0x53,
      0x43,
      0x01,
      0x00,
      0x08,
      0x00,
      0xff,
      0xff,
    ]);

    expect(decodeSceneRecordsFrame(reply), isEmpty);
  });

  test('a read with two records (captured)', () {
    final reply = buildSysexWriteFrame([
      0x12, 0x33, 0x53, 0x43, 0x02, 0x02, 0x24, 0x00, 0x8a, 0xd7, //
      0x00, 0x07, 0x01, 0x01, 0x1b, 0x00, 0x00, 0x00, ...f33, ...f44, //
      0x03, 0x01, 0x01, 0x00, 0x01, 0x00, 0x00, 0x07, ...f33, //
    ]);
    final records = decodeSceneRecordsFrame(reply);

    expect(records, hasLength(2));
    expect(records[0].module, 0);
    expect(records[0].sc1On, isTrue);
    expect(records[0].sc2On, isNull);
    expect(records[0].sc1, {0: 33.0});
    expect(records[0].sc2, {0: 44.0});
    expect(records[1].module, 3);
    expect(records[1].sc1, {0: 33.0});
    expect(records[1].sc2, isEmpty);
  });

  test('truncated or foreign replies decode to nothing', () {
    final cut = buildSysexWriteFrame([
      0x12, 0x33, 0x53, 0x43, 0x01, 0x01, 0x14, 0x00, 0xc3, 0xc2, //
      0x03, 0x01, 0x01, 0x00, 0x01, 0x00,
    ]);

    expect(decodeSceneRecordsFrame(cut), isEmpty);
    expect(
      decodeSceneRecordsFrame(buildSysexWriteFrame([0x12, 0x2a, 0x53, 0x43])),
      isEmpty,
    );
    expect(decodeSceneRecordsFrame('junk'), isEmpty);
  });

  test('the current scene reply', () {
    final reply = buildSysexWriteFrame([
      0x12,
      0x32,
      0x01,
      0x02,
      0,
      0,
      0,
      0,
      0x52,
      0x53,
      0xb9,
      0x03,
    ]);

    expect(decodeCurrentSceneFrame(reply), 2);
    expect(decodeCurrentSceneFrame('junk'), isNull);
  });
}
