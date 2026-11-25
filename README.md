# SonicMaster for iOS (CFW fork)

A fork of **[SonicMaster](https://github.com/Skyggedans/SonicMaster)** by Andrii Klaptsov, the
editor for the **Sonicake Pocket Master** and **Smart Box** pedals. This fork adds two things:

1. **A native iOS / iPadOS app.** Browsers on iPhone and iPad cannot reach the pedal: WebKit has
   neither Web MIDI nor Web Bluetooth. This build talks to the pedal directly over Bluetooth LE.
2. **The features of the community custom firmware (CFW)** for the Pocket Master, brought over
   from the [Sonicake CFW web app](https://pocketmaster-cfw.guitar-training-generator.com/).
   The CFW web app is itself a fork of SonicMaster.

Everything from upstream is still here: presets, the full effect editor, signal chain,
footswitches, NAM to `.clo` conversion, user IRs, and JSON preset import/export. See the
[upstream README](https://github.com/Skyggedans/SonicMaster#readme) for those features.

> Not affiliated with, or endorsed by, Sonicake or the CFW authors.

---

## What this fork adds

### iOS / iPadOS

* Native iOS runner (iOS 15+), with a layout for the iPad and a compact layout for the iPhone.
* Bluetooth LE connection to the pedal (`Sonic Master BLE`), tested on an iPad.
* USB-MIDI goes through CoreMIDI. It is built in but has not been tested on an iOS device.
* **Demo mode** ("Try demo" on the start screen): a virtual CFW Pocket Master, for trying the UI
  without a pedal.
* Flat Material 3 dark look. Preset volume, BPM and a quick preset selector sit in the top bar.

### Custom firmware (CFW) features

These appear only when the connected pedal runs the CFW. On the stock firmware the app works
like upstream.

| Feature | Where |
| --- | --- |
| CFW settings (read and write) | Settings dialog |
| Global EQ, with response curve | Settings dialog |
| MIDI settings and a custom MIDI map editor | Settings dialog |
| DSP load and pedal battery | Top bar |
| Scenes (BASE / SC1 / SC2), per-scene module state | Module editor |
| EXP A-D assignment | Module editor |
| The Smart Box effect set on a CFW Pocket Master | Model dropdowns |
| The CFW's own models: 4 EQs, 6 delays, 5 reverbs | Model dropdowns |
| Community presets (Try / Save to…), not on web | Top bar (globe) |
| 10 User IR and 10 User Profile (Clone) slots: load, rename, clear | "Slots…" in the IR and Clone modules |
| Tuner mirrored from the pedal | Top bar |
| Move a User preset to another position | Settings dialog |

Each protocol register was decoded from captures of the CFW web app. Each one was then checked
on a real pedal (CFW 1.0.2 and 1.0.3) by a live integration test, run on an iPad over BLE. The
captures and results are in
[docs/cfw-protocol/capture-notes.md](docs/cfw-protocol/capture-notes.md).

**Not ported yet:** TONE3000 downloads per slot, backup/restore, and the extra knobs the CFW adds to the stock delays and reverbs.

---

## Building for iPhone / iPad

This app is not on the App Store. You build it and install it on your own device. You need a
Mac with Xcode and the **Flutter** SDK.

```bash
cd app
flutter pub get
```

1. Open `app/ios/Runner.xcworkspace` in Xcode.
2. Under *Signing & Capabilities*, set your own **Team**. The project has the fork author's team
   ID, which will not work for you.
3. Change the **Bundle Identifier** (`dev.sonicmasterfork.ios`) to one of your own.

Then build and run:

```bash
flutter run --release -d <your-device>
```

On first connect, iOS asks for Bluetooth permission. Turn on the pedal and pick
**Sonic Master BLE**.

Desktop and web builds work as upstream (see
[Building from source](https://github.com/Skyggedans/SonicMaster#building-from-source)).

### Tests

```bash
cd app
flutter test
```

The live tests in `app/integration_test/cfw_*_live_test.dart` need a real CFW pedal. Each one
restores what it changes.

---

## Credits and license

* **SonicMaster**: Andrii Klaptsov, MIT License ([LICENSE](LICENSE)).
* **Sonicake CFW web app**: the CFW data files in `app/assets/data/` and
  `docs/cfw-protocol/cfw-app-data/` come from it, under the same MIT License (see
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)).
* The bundled **Oswald** font is under the SIL Open Font License 1.1.

All product, amp and pedal names are trademarks of their owners and are used only to describe the
modeled gear.
