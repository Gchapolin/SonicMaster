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

## Capture session 3 (2026-11-25, CFW web app over BLE)
### Register 0x37: preset order (User bank), moved P18 <-> P17 and moved back
- read `12 37` -> `12 37 01 <state> <token> <50 entries>`: entry i = the stored slot (0-based) shown at position i.
  Identity order: state 02, token 83, entries 00..31. After the swap: state 00, token CB, entries ... 0F 11 10 12 ...
- write `11 37 01 <token of the table read just before> <50 entries>` (54 bytes). The second write (back to
  identity) carried CB, so the byte is the current table's token (compare-and-swap), not one of the new table.
- The write is a multi-packet frame: 3 packets with header `<crc> <total = 03> <index 00..02> <len>` and at most
  19 payload bytes each (19 + 19 + 16); the pedal acks each (`14 08 00`). Then the app reads `12 37` again.
- "No preset is changed, only their positions" (web app text): the pedal remaps; presets are not rewritten.
- The web app downloads `preset-order-<date>-<time>.json` (2213 bytes) before each write.
- Not known: how the token is computed (not needed to write), state values other than 00 / 02.
### Whole-pedal backup ("Back up now"): reads only, in this order
- `12 4F <slot 0..49> 00 00 00` x 50: the stored preset, a 5-packet reply (4 x 424 + 1 x 408 hex chars on the wire).
- per slot 0..49: `12 34 <slot>` (that preset's scene records, same "SC" block as `12 33`: empty = `53 43 01 00 08 00 ff ff`)
  and `12 3D <slot>` (that preset's EXP A-D; `12 3D` with no argument is the loaded preset).
- then `12 39 00` (custom MIDI map), `12 2A`, `12 3A`, `12 37`, `12 28`, `12 29`, `12 38 00 00 <page 0..5>` (the data of
  the one stored Clone, six pages), `12 10`.
- File: `sonicake-cfw-backup-CFW1.0.2-<date>-<time>.smbackup.json` (61 KB), type `sonicmaster-cfw-backup`, format 1, with
  sections presets / scenes / midiPedals / midiMap / order / globals / cfwSettings / globalEq / irs / clones.
- Restore was NOT run (it rewrites all 50 presets), so the write side (`11 4F` ...?) is unknown.

## Live gate 2026-11-25 (integration_test/cfw_order_live_test.dart, iPad over BLE, CFW 1.0.2)
- Preset order: swapped P50 / P49 with the app's own three packets (all acked): `12 37` read back ... 49, 48 with token
  0x91, and the stock preset-names dump came back in the new order (P49 = MegaVerb, P50 = MVerbOCdrv). Swapped back:
  identity, token 0x83, names as before.

## Capture session 4 (2026-11-25, CFW web app over BLE): files into slot 6
Slots 6-10 take the stock commands with slot index 5..9; only the index differs.
- IR upload (User IR 6, a 1024-sample synthetic wav named "test_ir"): reads `12 28`, `12 20`, then the stock blob
  `11 21 00 00 00 00 <slot 05> 00 10 0A <64-byte name> <512 x int32 LE>` (2122 bytes, 112 packets, each acked), then the
  commit notification `12 1B 04 00 00 00` and `12 28` again.
- IR clear: `11 23 05 00 10 0A` -> ack, `12 1B 04 ...`.
- Clone upload (User Profile 6, a .nam through "Convert"): reads `12 29`, `12 24`, then the stock blob
  `11 25 00 00 00 00 <slot 05> 00 00 0F <name> ...` (146 packets), commit `12 1B 03 00 00 00`.
- Clone clear: `11 27 05 00 00 0F` -> ack, `12 1B 03 ...`.
- Both test slots were cleared again; both clears committed without a power cycle.
- Not captured: rename of slots 6-10, the web app's "Import as is" NAM path, names longer than 10 characters.

## Live gate 2026-11-25 (integration_test/cfw_slot_upload_live_test.dart, iPad over BLE, CFW 1.0.2)
- User IR 10 (slot index 9), with the app's own frames: upload committed and `12 28` read "LiveTest"; rename
  (`11 22`, slot 9) committed and read "Renamed"; clear committed and the name is "User IR 10" again.
  So rename works on slots 6-10 too, and three writes in a row committed without a power cycle.
- Clone slots 6-10 from the app are not live-checked (only the web app's upload to slot 6 was captured).

## Capture session 5 (2026-11-25): custom MIDI map (register 0x39), decoded
Saved a copy of the Generic MIDI map (34 rows) as Custom, then an empty map; map set back to Stock, options 0.
- Row = 8 bytes: `<trigger 01 CC | 02 PC> <channel 0 = the pedal's MIDI CH, 1..16> <number from> <number to>
  <value> <function> <which> <switch>`.
  - value: 00 any, 01 ">= 64", 02 "< 64", 80|n "= n" (from the web app's code; only 00 and 01 seen on the wire).
  - function 1..25: 1 Select preset, 2 Bank -/+, 3 Preset -/+, 4 Tuner on/off, 5 Tap tempo, 6 Tap + division,
    7 Looper window, 8 Looper rec/play/clear, 9 Looper volume, 10 Looper Pre/Post, 11 Drum, 12 Block on/off,
    13 STOMP FS1/FS2, 14 Scene, 15 Volume, 16 Knob role, 17 Freeze, 18 EXP A-D, 19 Global EQ on/off,
    20 Footswitch mode cycle, 21 Ignored, 22 Expression, 23 Tempo set, 24 Sync on/off, 25 Delay note -/+.
  - which: index of the first option of that function; a number range walks the options (PC 101-102 -> Bank -, Bank +).
    Option lists (web app): 2 Bank -/+; 3 Preset -/+; 6 1/4, 1/8., 1/8, 1/2, 1/16, 1/8T, 1/4., 1/4T, 1/16T;
    8 Rec/overdub, Play/stop, Clear, Rec/Play, Stop; 9 Rec volume, Play volume; 11 Window, Play/stop, Rhythm, Volume;
    12 NR..RVB; 13 FS1, FS2; 14 SC1, SC2, BASE; 15 Master, Preset; 16 IR Vol, EQ Vol, DRV Gain, DRV Vol, AMP Gain,
    AMP Vol, DLY Mix, RVB Mix; 18 EXP A..D; 23 BPM range, BPM value; 24 DLY, FX1, FX2; 25 Shorter, Longer, Back to the
    preset note. Function 1: 0..99 = P01..P50, F01..F50.
  - switch (& 3): 0 ">= 64 on", 1 toggle, 2 momentary (for the on/off functions 4, 7, 8, 10, 11, 12, 17, 19).
- "Preset selection PC 1-100" is two rows: `02 00 01 64 00 01 00 00` (PC 1..100 select preset) and `02 00 00 00 00 15 00 00`
  (PC 0 ignored).
- Write: header `11 39 00 "PMMM" 01 <options> <count u16 LE> 00 00 00 00 <crc16 LE> 00 00`, then batches
  `11 39 01 <first index> <n <= 8> <n x 8 bytes>` (multi-packet, 19 payload bytes per packet, each acked), then commit
  `11 39 02 <crc16 LE>`. options: bit0 first PC is PC 1, bit1 level CCs 0..127 (the same bits as setting 0x17).
- crc16 = CRC-16/MODBUS over `"PMMM" 01 <options> <count u16 LE>` + all rows (matches the four captured maps).
- Read: `12 39 00` -> `12 39 00 01 01 <flags> <count> <max 40> <options> ..  .. .. .. <crc16 LE> ...`;
  `12 39 01 <first index>` -> `12 39 01 <first index> <n> <n x 8 bytes>` (pages of 8).

## Live gate 2026-11-25 (integration_test/cfw_midi_map_live_test.dart, iPad over BLE, CFW 1.0.2)
- Custom MIDI map: wrote 10 rows with the app's own frames (all acked); `12 39 00` read count 10 and the CRC the app
  computed (0xD883 with options 0); the pages read back the same rows. Wrote the empty map again: count 0, CRC 0x1CFA,
  as before the captures.
- The map header's options and setting 0x17 are separate values: after the web app saved an empty map with options 1
  and then wrote `11 2A 17 00`, the header still read 1 while 0x17 read 0. Both are 0 again now. Which one the pedal
  obeys when they differ is not known.
- The MIDI map setting itself stayed on Stock throughout; the gate ran without the app's heartbeat.

## Capture session 6 (2026-11-25, CFW web app over USB in Chrome): battery `12 2D`, decoded from the app
Reply `12 2D <ver 1> <flags> <mV u16 LE> <charge> <e> <f> <bars> <emptyMv u16 LE>`; sample on USB:
`12 2d 01 01 28 0f 01 02 05 02 d4 0d` (3880 mV, charging, 2 bars, empty below 3540 mV).
- flags: bit0 battery present (clear = unknown), bit2 empty, bit3 "Batt Only: not charging from USB".
- charge: 0 on battery, 1 charging, 2 charged (on USB), other = charging.
- bars 0..4 = byte 9; when byte 7 is 255 the app instead counts mV > 3540 / 3620 / 3760 / 3900.
- Tooltip texts: "Charging (USB power)", "Charged (on USB power)", "Battery empty (below X V): charge the pedal",
  "Battery low: 1 of 4 · X V", "Battery: N of 4 · X V".
Bytes 7 and 8 (02 05 here) not decoded beyond the 255 check.
Other CFW app features not in SonicMaster: Community presets (catalog with Try / Save to), TONE3000 download per IR/Clone slot.
CFW 1.0.3 is out (Pocket Control / Stock-map CC fixes, .prst import messages, tuner close fix); the pedal runs 1.0.2.

## Live gate 2026-11-25 (integration_test/cfw_battery_live_test.dart, iPad over BLE, CFW 1.0.3)
`12 2D` read 3 times: 4134 mV, charging (pedal on USB power), 4 bars, flags 0x01, empty 3540 mV. Same layout on 1.0.3.

## CFW effect models in the modules (2026-11-25, from the CFW web app's code and data, no capture)
The CFW app builds both frames itself (main.dart.js, functions a9V / zQ):
- select: `11 47 <module u32> <module u32> <effectId u32>`, all little-endian. Matches every captured stock
  select frame (stock ids from cfw_fx_models.json `stockIds`).
- knob: `11 48 <module u32> <algId u32> <value float32>`. The value is the knob value itself, snapped to its step
  (EQ dB knobs send -3.5, not a slot index). Matches the captured knob frames, except 39 (two FX2 knobs) whose
  float is one bit higher, and one bad upstream capture: RVB algId 5 = 4 carried 2.0 (entry dropped).
- models: EQ 504-507 (module 5, effectId 0x010000c0-c3), DLY 751-756 (0x0b0000c0-c5), RVB 851-855 (0x0c0000c0-c4).
  Dump signatures (effect_signatures.json, from the CFW app): EQ `0A0C0x`, DLY/RVB `0C0x`.
- CFW delays, slot 7 (CFW 0.9.4 on, `tempo094.cfwDelaySync`): 0 Off, 1 Trail, 2 Sync, 3 Both; with the Sync bit
  set, Time is a note-division index (community preset MB-Thall-D: Trails 3, Time 4 = 1/4).
- Param slots the stock tables lacked, by the 8-slots x 8-bytes layout: 5_6 (3,69), 5_7 (3,77), 7_7 (3,205),
  8_3 (4,37), 8_6 (4,61), 8_7 (4,69). Values outside the captured lookup decode from the float itself.
- Not done: the stock delays/reverbs' extra knobs on the CFW (`stockExtraParams`: DLY Tone/Duck/Trail at 5/6/7,
  RVB High Cut/Low Cut/Trail at 3/6/7), and the Swell Delay variant some CFW versions use for slot 6.

- Swell Delay variant (done): the CFW app's `AW.kC` swaps slot 6 for `B.NM` = Sens (-50..50, step 1, default 0,
  no texts) when its flags' `b` is set. On a Pocket Master that is capability bit 31 (`sbModels097`; demo
  profiles: 0.9.6 caps 0x4fff8f7f without, 0.9.7 / 0.9.8 0xcfff8f7f with; the captured 1.0.2 has it), off on a
  NAM build (second capability word, the `04 <u32>` after the pairs, bit 4096, or "-NAM" in the version). Its
  `a` flag (display index shift `B.a7p`) and the stock extra-param sets (`AX.kC`) are Smart Box only.
