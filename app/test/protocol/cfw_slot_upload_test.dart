import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/protocol/cfw_slot_names_codec.dart';
import 'package:sonicmaster/protocol/clo_upload_frame.dart';
import 'package:sonicmaster/protocol/ir_upload_frame.dart';

/// Frames captured from the CFW web app writing slot 6 of each kind
/// (docs/cfw-protocol/capture-notes.md, capture session 4): the stock
/// commands with slot index 5.
void main() {
  test('effect ids map to their slots, the factory cab 421 to none', () {
    expect([416, 420, 422, 426].map(userIrSlotOf), [0, 4, 5, 9]);
    expect(userIrSlotOf(421), isNull);
    expect(userIrSlotOf(415), isNull);
    expect(userIrSlotOf(427), isNull);
    expect([901, 905, 906, 910].map(userProfileSlotOf), [0, 4, 5, 9]);
    expect(userProfileSlotOf(900), isNull);
    expect(userProfileSlotOf(911), isNull);
  });

  test('an IR upload to slot 6 starts as captured', () {
    final blob = IrUploadFrame.buildBlob(
      slot: 5,
      name: 'test_ir',
      samples: List.filled(IrUploadFrame.deviceTaps, 0),
    );

    expect(blob.length, 2122);
    expect(blob.sublist(0, 17), [
      0x11, 0x21, 0, 0, 0, 0, 0x05, 0, 0x10, 0x0a, //
      ...'test_ir'.codeUnits,
    ]);
    expect(IrUploadFrame.buildChunks(blob), hasLength(112));
  });

  test('clearing slot 6 is the stock clear with slot 5', () {
    expect(IrUploadFrame.buildClearBlob(slot: 5), [
      0x11, 0x23, 0x05, 0x00, 0x10, 0x0a, //
    ]);
    expect(CloUploadFrame.buildClearBlob(slot: 5), [
      0x11, 0x27, 0x05, 0x00, 0x00, 0x0f, //
    ]);
  });
}
