import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/model/tuner_reading.dart';
import 'package:sonicmaster/protocol/cfw_tuner_codec.dart';
import 'package:sonicmaster/protocol/sysex_write_frame.dart';

List<int> _f32(double v) =>
    (ByteData(4)..setFloat32(0, v, Endian.little)).buffer.asUint8List();

/// A `12 3F` reply: version, flags, note, octave, cents, Hz, A4, seq, age.
String _reply({
  int version = 1,
  int flags = 0x03,
  int note = 0,
  int octave = 2,
  double cents = 0,
  double hz = 110,
  int a4 = 440,
}) => buildSysexWriteFrame([
  0x12, 0x3f, version, flags, note, octave & 0xff, //
  ..._f32(cents), ..._f32(hz), a4 & 0xff, a4 >> 8, 0xe5, 0x0e, 0, 0,
]);

void main() {
  test('the command frames match the capture', () {
    expect(tunerOpenFrame(isOpen: true), buildSysexWriteFrame([0x11, 0x3e, 1]));
    expect(
      tunerOpenFrame(isOpen: false),
      buildSysexWriteFrame([0x11, 0x3e, 0]),
    );
    expect(
      tunerA4Frame(441),
      buildSysexWriteFrame([0x11, 0x3e, 0x02, 0xb9, 0x01]),
    );
    expect(
      tunerOutputFrame(isMuted: true),
      buildSysexWriteFrame([0x11, 0x3e, 0x04, 0x00, 0x00]),
    );
    expect(
      tunerOutputFrame(isMuted: false),
      buildSysexWriteFrame([0x11, 0x3e, 0x04, 0x01, 0x00]),
    );
    expect(readTunerFrame(), buildSysexWriteFrame([0x12, 0x3f]));
  });

  test('the captured reading with no string playing has no note', () {
    final r = decodeTunerFrame(
      buildSysexWriteFrame([
        0x12, 0x3f, 0x01, 0x15, 0xff, 0x7f, 0x00, 0x00, 0x00, 0x00, //
        0xc3, 0x88, 0x02, 0x42, 0xb8, 0x01, 0xe5, 0x0e, 0x00, 0x00,
      ]),
    )!;

    expect(r.isOpen, isTrue);
    expect(r.hasNote, isFalse);
    expect(r.note, isNull);
    expect(r.octave, isNull);
    expect(r.a4, 440);
    expect(r.hz, closeTo(32.63, 0.01));
    expect(r.isMuted, isFalse);
  });

  test('a reading with a note carries note, octave, cents and Hz', () {
    final r = decodeTunerFrame(_reply(cents: -4.5, hz: 109.71))!;

    expect(r.hasNote, isTrue);
    expect(r.noteName, 'A');
    expect(r.octave, 2);
    expect(r.cents, closeTo(-4.5, 0.001));
    expect(r.hz, closeTo(109.71, 0.001));
  });

  test('the note index counts from A', () {
    expect(decodeTunerFrame(_reply(note: 7))!.noteName, 'E');
    expect(decodeTunerFrame(_reply(note: 11))!.noteName, 'G#');
  });

  test('flag 0x20 is the muted output, a closed tuner has no open flag', () {
    expect(decodeTunerFrame(_reply(flags: 0x23))!.isMuted, isTrue);
    expect(decodeTunerFrame(_reply(flags: 0x10))!.isOpen, isFalse);
  });

  test('a note flag without a usable note or octave has no note', () {
    expect(decodeTunerFrame(_reply(note: 0xff))!.hasNote, isFalse);
    expect(decodeTunerFrame(_reply(octave: 0x7f))!.hasNote, isFalse);
    expect(decodeTunerFrame(_reply(note: 12))!.hasNote, isFalse);
  });

  test('non-finite cents or Hz read as zero', () {
    final r = decodeTunerFrame(_reply(cents: double.nan, hz: double.infinity))!;

    expect(r.cents, 0);
    expect(r.hz, 0);
  });

  test('another version, register or a short frame decode to null', () {
    expect(decodeTunerFrame(_reply(version: 2)), isNull);
    expect(
      decodeTunerFrame(
        buildSysexWriteFrame([0x12, 0x3e, 1, 3, ...List.filled(16, 0)]),
      ),
      isNull,
    );
    expect(decodeTunerFrame(buildSysexWriteFrame([0x12, 0x3f, 1, 3])), isNull);
    expect(decodeTunerFrame('nope'), isNull);
  });
}
