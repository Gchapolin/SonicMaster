# CFW protocol capture notes

Captured 2026-11-24 from the user's own Pocket Master (CFW 1.0.2, base V1.3.3) over Bluetooth,
by logging the GATT writes/notifications of the CFW web app (pocketmaster-cfw.guitar-training-generator.com/app/)
in Chrome. Only the bytes on the wire are recorded here; no code from the CFW app is copied.

Frame (hex, after the `8080` BLE header and `F0`, before `F7`): `c1 c2 | 00 01 00 00 00 | len | ...payload nibbles...`
- `c1 c2`: checksum nibbles (same scheme as stock commands in command_library.json).
- BLE characteristic: 7772e5db-3868-4112-a1a9-f2669d106bf3 (writes and notifications).
- Notation below: `>` app -> pedal, `<` pedal -> app; checksum bytes kept as captured.

## Periodic traffic (ignore when diffing)
- `> ..0201020100` every ~2 s (status poll), answered by `< ..0501010201..` (170 bytes).
- `< ..0105..`, `< ..010a01..` frequent status pushes (likely DSP meter / live state; to decode).

## A1. Scenes ON (preset P01)
> 0909 000100000006 0101 0303 0000 0001 0000 0000
< 0b02 000100000003 0104 0008 0000            (ack)

Stock commands in command_library.json use `01 01 04 xx` (param set `0408`, module on/off `0409`, effect type `0407`,
chain order `0404`, preset select `0403`). The CFW scene commands below use `01 01 03 xx`: a new family.

Values are float32, sent as 8 nibbles; nibble pairs form bytes, bytes are little-endian:
`00 00 00 00 0b 08 04 01` -> bytes 00 00 B8 41 -> 0x41B80000 = 23.0.

## A2-A5. Scene select (len 03)
> 000e 000100000003 0101 0302 0001   SC1
> 0007 000100000003 0101 0302 0002   SC2
> 0009 000100000003 0101 0302 0000   BASE
< 0b02 000100000003 0104 0008 0000   (ack, every write)
< ..0c 0102 0302 0001 00vv ...       (scene state push; vv = current scene)

## A6. Knob value inside a scene (SC1, NR THRE 10 -> 23), len 0a, sent while dragging
> 0901 00010000000a 0101 0303 0000 0001 0001 0000 0000 0000 0005 0004 01   (13.0)
> 0805 ...                                       ... 000a 0004 01           (20.0)
> 070a ...                                       ... 000b 0804 01           (23.0)
Fields after `0303` (to confirm with more samples): 0000 0001 | 0001 0000 | float32.
Probably: scene (0001 = SC1), module (0000 = NR?), param index, value.

## A7-A9. Module ON/OFF override inside a scene (SC1, NR), same `0303` command
> 0c03 00010000000a 0101 0303 0000 0003 0001 0000 0000 0000 000b 0804 01   OFF  (flags 0003)
> 0b06 ...                    0000 0007 ...                                ON   (flags 0007)
> 070a ...                    0000 0001 ...                                BASE (flags 0001)
< ..0a 0102 0409 ... 00|01 ...   pedal applies it live (stock module-state push)
Reading: the 2nd field is a flags word (bit0 = scene override present, bit1 = module state set,
bit2 = module on). The record always carries the scene's knob value (23.0 here).

## Framing, decoded (see app/lib/protocol/sysex_write_frame.dart)
`8080 F0 <crc8 smbus> 01 00 <ll> <payload> F7`, every byte nibble-expanded. Collapsing the nibbles,
the payload starts `11 <register>`: stock registers 0x43 preset select, 0x47 effect type,
0x48 param, 0x49 module on/off. **The CFW adds 0x32 and 0x33.**

## Register 0x32: scene select — payload `11 32 <scene>` (0 BASE, 1 SC1, 2 SC2)

## Register 0x33: one module's whole scene record, re-sent on every change
payload: `11 33 <module> <flags> <sc1Mask> <sc2Mask> <float32 LE>...`
- module: physical id (0 NR, 1 FX1, 2 DRV, 3 AMP, ...).
- flags: bit0 = module takes part in scenes; bit1 = SC1 overrides on/off; bit2 = SC1 on.
  (SC2 on/off bits presumably bit3/bit4: to confirm.)
- sc1Mask / sc2Mask: bit n = param with algId n is overridden in that scene.
- then one float32 per set bit, SC1's params in algId order, then SC2's.
Verified samples (collapsed payload after `11 33`):
- NR scenes on:            00 01 00 00
- AMP scenes on:           03 01 00 00
- NR  SC1 THRE=23:         00 01 01 00 | 23.0
- NR  SC1 off / on / base: 00 03 01 00 | 23.0 ; 00 07 ... ; 00 01 ...
- AMP SC2 BASS=88:         03 01 00 02 | 88.0
- AMP SC1 BASS=96 + SC2:   03 01 02 02 | 96.0 88.0
- AMP SC1 VOL=46 too:      03 01 03 02 | 46.0 96.0 88.0
Note: AMP algIds in SonicMaster's effect_library: Vol 0, Bass 1 (Jazz 120) - matches the masks.
Every write is acked with `< ..0003 0104 0008 0000` (collapsed `14 08 00`).
- AMP SC2 off:             03 09 03 02 | ...  -> flags bit3 = SC2 overrides on/off, bit4 = SC2 on. Confirmed.
Scene state push from the pedal (`< ..0c 0102 0302 ...`, collapsed `12 32 ...`) carries the current scene.

## Licensing note (from the CFW app's own About dialog, read 2026-11-24)
The dialog states the CFW additions are "this fork, same MIT License", based on Skyggedans/SonicMaster
@ a3059cc. Listed additions: firmware detection (registers 12 28/29, 12 2A), 10 User IR + 10 Clone slots,
IR/Clone names up to 30 chars, read-back verification, CFW settings (Style, Brightness, I/O, MIDI), DSP load,
tap tempo, STOMP, scenes, TONE3000, phone layout, installable offline app, offline mock pedal.
Its source is not published anywhere we found; MIT would allow reuse with attribution if obtained.

## A15. STOMP per module = stock footswitch register 0x4D (already in SonicMaster)
> payload 11 4D 00 03 01  (FS1, module AMP, on)

## CFW settings
Display (all reverted after capture):
- ECO:        GlobalSettingWriter.dumpRecord(a0: 0x04, a1: 0x02, value 0/1)   [payload 11 11 04 02 00 00 <int32 LE>]
- Brightness: dumpRecord(a0: 0x03, a1: 0x02, value 10..100)                 [90% -> 5a 00 00 00]
- Theme:      register 0x2A, payload `11 2A 01 <theme>`; themes 0 Default, 1 Amber CRT, 2 Tube Amp,
              3 Synthwave, 4 Stage Hi-Contrast, 5 Game Boy.
  The pedal answers with a 54-byte `12 2A` block (CFW settings block) where the theme byte changes:
  this block is what the app reads at connect ("firmware detection 12 28/29, 12 2A").
Register 0x2A writes are `11 2A <key> <value>` (one byte each). Keys found so far:
| key  | setting            | values                                             |
|------|--------------------|----------------------------------------------------|
| 0x01 | Display theme      | 0 Default, 1 Amber CRT, 2 Tube Amp, 3 Synthwave, 4 Stage Hi-Contrast, 5 Game Boy |
| 0x03 | Direct Monitor     | 0 off, 1 on                                        |
| 0x04 | USB Rec            | 0 WET, 1 DRY DI, 2 DI L + WET R                    |
| 0x11 | Same preset again  | 0 OFF, 1 CYCLE, (2 BACK presumed)                  |
| 0x15 | MIDI map           | 0 Stock, 2 Generic MIDI, 3 Chocolate, (Custom: tbd)|
| 0x16 | Tempo scope        | 0 PRESET, 1 GLOBAL                                 |
| 0x27 | Drum Sync          | 0 off, 1 on                                        |
Reads issued when the MIDI section opens: `12 2A`, `12 2B`, `12 2C`, `12 2D`, `12 2E`, `12 3B`, `12 3F`,
and `12 3C 02 00`, `12 3C 02 08`, ... `12 3C 02 20` (paged table, likely the custom map / EXP table).
`12 2B` and `12 3B` are polled while the MIDI section is open (MIDI monitor?).
| 0x12 | MIDI channel       | 0 ALL, n = channel n (1..16)                       |
| 0x15 | MIDI map           | 0 Stock, 1 Custom, 2 Generic MIDI, 3 Chocolate     |
| 0x17 | Custom map options | bitfield: bit0 First PC = PC1 (else PC0), bit1 Level CC 0..127 (else 0..100) |
(First PC / Level CC range are only editable with the Custom map; Generic fixes them.)

## Register 0x39: Custom MIDI map upload (editor "Save to pedal"); all reverted to empty afterwards
1. header `11 39 00 | 50 4D 4D 4D | 01 00 | <count u16 LE> | 00 00 00 00 00 | <crc16?> | 00 00`
   ("PMMM" magic, version 1, entry count; crc D2 F2 with 1 entry, FA 1C with 0)
2. one `11 39 01 <index> <entry bytes>` per row; sample row CC 0 -> Tap tempo, MIDI CH (ALL), value any:
   `11 39 01 00 | 01 01 00 00 00 00 05 00 00` (to decode field-by-field with more rows)
3. commit `11 39 02 <same crc>`
Editor limits seen: name up to 10 chars, up to 64 entries; trigger/number/channel/value/function/which/switch.
| 0x06 | Pedal (footswitch) mode | 0 PRESET, 1 STOMP, 2 SCENE                   |

## Register 0x3A: Global EQ (whole block re-sent on every change); restored to OFF/Studio EQ/defaults
payload `11 3A <on> <model> <p1> <p2> <p3> <p4> <p5> <vol> <p7> <p8>` (10 bytes after `11 3A`)
- on: 0/1. model: 0 Studio EQ, 1 Parametric 3, (2 Cut 24, 3 Tilt EQ, 4 GT EQ 1, 5 GT EQ 2, 6 Bass EQ - order as listed in the app, to confirm).
- vol (byte 8 of 10): 50 = 0x32 default, same slot for every model.
- Studio EQ slots: p1 BASS (signed, 0.5 dB steps: +2.0 dB = 04), p2 MID FREQ (index, 0 = 800 Hz, 7 = 1.07 kHz),
  p3 MID (0.5 dB steps), p4 Q (index, 0 = 0.71, 1 = 0.74, 7 = 0.99), p5 TREBLE (0.5 dB),
  p7 LOW CUT (index, 0 = Off, 7 = 26 Hz), p8 HIGH CUT (index, 100 = Off, 93 = 16.2 kHz).
  Studio EQ defaults: 01 00 00 00 00 00 00 32 00 64 (with on=1).
- Parametric 3 defaults: 01 01 00 00 00 00 00 32 21 28 ; knobs LOW F 100 Hz, LOW, MID F 800 Hz, MID,
  HIGH F 3.03 kHz, HIGH, Q 0.71, VOL 50 -> each model maps the same slots to its own knobs.
- Reads when the section opens: `12 3A` (block), plus `12 2A/2C/2E/3F`.
TODO: per-model knob tables (name, range, index->Hz/Q) by stepping each model's knobs.

## Register 0x3E/0x3F: tuner (reverted: A4 440, output BYPASS, closed)
- open  `11 3E 01`  (pedal echoes `12 3E 01 01`); close `11 3E 00`
- A4    `11 3E 02 <Hz u16 LE>`   441 -> B9 01, 440 -> B8 01 (430..450; the pedal resets to 440 at power-on)
- output `11 3E 04 <0 MUTE | 1 BYPASS> 00`
- readings `12 3F 01 <note?> <cents i16? FF7F = no signal> 00 00 00 00 <float32 Hz?> ...` streamed while open
  (sample with no signal: 12 3f 01 15 ff 7f 00 00 00 00 c3 88 02 42 b8 01 e5 0e 00 00) - decode with a string played.

## Status reads (polled by the app)
- `12 2B` -> `12 2B 01 03 <dsp% u16 LE> ...` : 39 00 = 57 % DSP load (matches the top-bar chip), then floats.
- `12 2C` -> `12 2C 01 00 <bpm u16 LE> ...`  : 78 00 = 120 BPM (tempo chip).
- `12 2D` -> `12 2D 01 01 <mV u16 LE?> ...`   : 54 0F = 3924 -> likely battery voltage (to confirm vs. the battery icon).

## Preset load (CFW app, P02): after stock `11 43 01 00 00 00` it reads
`12 10` (stock), `12 2E`, `12 41`, `12 33` (scene records), `12 3D` (EXP A-D of the preset), `12 32` (current scene).
- `12 32` -> `01 <scene> 00 00 00 00 52 53 b9 03`   ("RS" + u16?)
- `12 2E` -> `01 00 00 50 51 09 00 00 00 00`          ("PQ"...)
- `12 41` -> TLV-like block with "EMQ" and the tempo 120 (0x78): per-preset tempo/sync data (to decode)
- `12 3D` -> `01 01 ff ff ...` (EXP A-D per preset; ff = free)

## Reading scene records: `12 33` -> (probed directly, live edits only, discarded by reloading presets)
`53 43 <count> <count?> <total len u16 LE> <crc16> <record>...`  ("SC")
record = `<module> <flags> <sc1Mask> <sc2Mask> <4 bytes effect key, pedal-filled> <float32 LE x popcount(masks)>`
- empty: `53 43 01 00 08 00 ff ff` (P02 had no scenes)
- 1 record (AMP, SC1 p0 = 33.0): `53 43 01 01 14 00 c3 c2 | 03 01 01 00 | 01 00 00 07 | 00 00 04 42`
- 2 records: `53 43 02 02 24 00 8a d7 | 00 07 01 01 | 1b 00 00 00 | 33.0 44.0 | 03 01 01 00 | 01 00 00 07 | 33.0`
The 4-byte effect key is not in effect_signatures.json; writes never carry it, so reads can skip it.
Probe tool: frames built as `8080 F0 nib(crc8smbus(01 00 len payload)) nib(01 00 len payload) F7`, verified
byte-for-byte against captured frames.

## Taps
TAP button: `11 2C 04 01` (the pedal computes the tempo; preset tempo when Tempo scope = PRESET).

## Data shipped by the CFW app (copied to docs/cfw-protocol/cfw-app-data/, see NOTICE.md)
Covers the extra effects, 10 IR/Clone slots and Global EQ knob tables, so these need no capture.

## Not captured yet (next capture session)
- EXP A-D assignment write (read is `12 3D`), preset reorder command, IR/Clone upload + 30-char names for slots 6-10,
  firmware detection replies `12 28/29`, tuner readings with a string playing, battery (`12 2D`) vs. the battery icon,
  custom-map row fields (more rows), Backup & restore traffic.

## Side effect to tell the user
P01 "Ponty" AMP BASS showed 100 at the start and 62 after reloading P01 (nothing was saved by us; NR THRE stayed 10).
Most likely 100 was an unsaved knob edit in the pedal's memory (e.g. from testing the iPhone app) and 62 is the saved value.

## Live gate 2026-11-24 (integration_test/cfw_scenes_geq_live_test.dart, iPad over BLE, CFW 1.0.2)
- Global EQ: wrote model 2 (Cut 24 defaults) and model 3 (Tilt defaults); `12 3A` read both back unchanged; original block restored.
  This proves the pedal accepts and stores models 2 and 3. That 2 = Cut 24 and 3 = Tilt (and not the reverse) is still
  the app-list-order assumption: confirm by ear / on the pedal's G-EQ screen.
- Scenes: `11 33 00 01 01 00 <23.0>` then `12 33` -> NR sc1 {0: 23}. `11 33 00 00 00 00` (clear) then `12 33` -> no record:
  the assumed "module out of scenes" frame works.
- `12 32` current scene = 0 (BASE). Nothing saved.
- 2026-11-25: the user confirmed on the pedal's G-EQ screen that model 2 is Cut 24 (so 3 = Tilt EQ).
- 2026-11-25 live gate (integration_test/cfw_scene_save_live_test.dart, User preset 50 "MegaVerb"): the stock Save (`040A`)
  keeps scene records — NR sc1 {0: 23} survived save + reload; clearing the record and saving again removed it.
- 2026-11-25 live gate (integration_test/cfw_effects_live_test.dart): a CFW Pocket Master takes the Smart Box effects with the
  stock `0407` select commands — AMP 329 (Superb CL), DLY 716 (Echo), FX1 601 (BBD Phaser) acked and read back from the state
  dump; reloading the preset discarded them.

## Capture session 2 (2026-11-25, CFW web app over BLE)
### Register 0x3D: EXP A-D of the loaded preset (assignment removed after capture)
- write `11 3D` + 4 x 6 bytes (EXP A, B, C, D): `<module> <algId> <mode> <min %> <max %> 00`; a free slot is `ff 00 00 00 00 00`.
  mode: 0 continuous, 1 toggle, 2 momentary. Sample (EXP A -> NR THRE, 0..35 %): `11 3d 00 00 00 00 23 00 ff 00 00 00 00 00 ...`
- read `12 3D` -> `01 01` + the same 24 bytes.
- The 24 bytes span two BLE packets: the frame is split by the transport, not by the protocol.
### Registers 0x28 / 0x29: names with 10 slots, read at connect
- `12 28` -> `01 0a 00` + 10 x 32-byte zero-padded ASCII names: the User IR names ("User IR 1" ...).
- `12 29` -> `01 0a 01` + 10 x 32-byte names: the Clone (User Profile) names ("Randall SATAN 50 Mic Center", "Empty" ...).
### Register 0x3F: tuner reading, decoded
The CFW web app polls `12 3F` (about 8 times a second) while its tuner is open; the pedal does not push readings.
Reply, little-endian, after `12 3F` (layout read from the web app's own parser, checked against the captured frames):
`<version = 1> <flags> <note u8> <octave i8> <cents f32> <Hz f32> <A4 u16> <seq u16> <age u8> 00`
- flags: bit0 tuner open, bit1 the pedal has a note (note / octave / cents valid). The web app also reads bit5
  (0x20); it most likely means "output muted" (not confirmed on the pedal). Seen with no signal: 0x15, and 0x10
  for the first frame after opening.
- note: 0..11 counting from A (A, A#, B, C ... G#); FF = none. octave: 7F = none.
- With no string playing: note FF, octave 7F, cents 0, and the Hz field wanders (noise).
- Not captured: a reading with a note (the guitar gave the pedal no signal during the session), so the note path
  is implemented from the parser only and needs the live check.
### EXP A-D sources
The CFW web app labels the four slots CC 16, CC 17, CC 18 and CC 19 (EXP A-D): they are driven by MIDI CCs, the
Pocket Master having no expression input.

## Live gate 2026-11-25 (integration_test/cfw_session2_live_test.dart, iPad over BLE, CFW 1.0.2)
- Slot names: `12 28` / `12 29` answer 324 payload bytes, not 325: the tenth name has 31 bytes. Both decode
  ("User IR 1" ..., "Randall SATAN 50 Mic Center", "Empty" ...).
- EXP: `11 3D` is acked; EXP D -> NR THRE toggle 10..90 read back from `12 3D`; original block (all free) restored.
- Tuner: open / close are acked; flags 0x10 closed, 0x15 open. A4 441 -> flags 0x1D and the A4 field reads 441
  (bit3 = A4 not 440); mute -> 0x05, bypass -> 0x15 (bit4 = output bypassed, clear = muted; bit5 was a wrong guess).
  A4 440 and bypass restored, tuner closed. No string was played: a reading with a note is still unverified.
