# Contributing

This is a private project that happens to be public. It was written for one
treadmill in one flat, and I am not looking to turn it into a product. That said,
contributions are welcome — especially the kind that make it work on hardware I
do not own.

## The most useful thing you can contribute

**A device that does not work.** FTMS is a standard, but firmware is firmware.
If the app connects to your treadmill and the numbers are wrong, missing, or
absurd, that is a bug worth fixing and I cannot find it without your data.

What I need:

1. Turn on **Settings → Debug mode**, then open **Settings → Inspect raw data**.
2. Walk for a minute so a few packets come in.
3. Tap **Share log** and send me the result.
4. Tell me what your treadmill's own display said at the same time — speed and
   distance are enough.

The raw hex is the important part. Decoded values tell me what my parser thinks;
the hex tells me what your treadmill actually sent, and the difference between
those two is the bug.

Manufacturer, model and firmware version (visible in the debug panel) help too.

## Reporting without the app

If you have a Mac and the treadmill nearby, you can produce a full GATT dump
without building the app at all:

```bash
swift build
lldb -b -o run -o quit -- ./.build/debug/ftms-dump --dauer 60
```

This writes a JSONL file to `dumps/`. Note that it contains your device's serial
number and system ID — strip those lines if you would rather not publish them.

The detour via `lldb` is not superstition: launched directly, macOS terminates
the process on first Bluetooth access with SIGABRT and no error message,
because TCC attributes the access to the calling terminal.

## Code

- **Identifiers, comments and commit messages are German.** The project was
  thought in German and stays consistent. User-facing strings are bilingual.
- **New user-facing text goes into both catalogues** in
  `App/Treadmill/Texte.swift` — never as a literal in a view. A test fails if a
  field is empty or identical in both languages.
- **Keep the layers apart.** `FTMSKit` has no CoreBluetooth, no SwiftUI and no
  I/O. That boundary is why the protocol logic is testable without hardware, and
  it is not negotiable.
- **The main screen must never scroll**, in either orientation. `LayoutTests`
  enforces this on an iPhone SE, which has the same screen area as the target
  device.
- **The Xcode project is generated.** Edit `App/project.yml` and run
  `xcodegen generate`. Changes made directly in `Treadmill.xcodeproj` are lost.
- **Never patch the decoder to fit one device.** If a machine reports different
  resolutions, override `FTMSSkalierung` for that device. The decoder implements
  the specification, and it should stay that way.

Before opening a pull request:

```bash
swift test
cd App && xcodegen generate && xcodebuild test -project Treadmill.xcodeproj \
  -scheme Treadmill -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'
```

## Anything touching the control point

Changes to `0x2AD9` handling get looked at more carefully than the rest, because
that code can accelerate a treadmill underneath a person. Three rules hold:

1. every speed command needs an explicit confirmation in the UI,
2. every target value is validated against the device's reported range before
   being sent,
3. the emergency stop bypasses both — an emergency stop that can fail validation
   is not one.

A pull request that weakens any of those will not be merged, however elegant it
is otherwise.

## Licence

By contributing, you agree that your contribution is licensed under the
[GPL-3.0](LICENSE), like the rest of the project.
