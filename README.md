# Walk of Shame

[![CI](https://github.com/MacBachi/WalkOfShame/actions/workflows/ci.yml/badge.svg)](https://github.com/MacBachi/WalkOfShame/actions/workflows/ci.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
![Platform: iOS 16+](https://img.shields.io/badge/Platform-iOS%2016%2B-lightgrey.svg)

An iOS app that reads a Bluetooth treadmill over the **Fitness Machine Service
(FTMS, `0x1826`)**, writes the workout to Apple Health, and can optionally
control the belt.

No backend. No account. No analytics. No network traffic at all — everything
stays on the device.

*[Diese Datei auf Deutsch](README.de.md)*

## Why this exists

This is a private project. I own a walking pad, and the manufacturer's app was
not usable: it crashed reliably in the one flow you cannot avoid, it had not been
fixed in years, and it wanted an account and a network connection to arrange
something my phone and the treadmill can perfectly well settle between
themselves.

So I wrote my own — for one treadmill, in one flat, for one person. It exists
because I wanted my walks in Apple Health without handing my movement data to
anybody.

That said: FTMS is a Bluetooth SIG standard, not a vendor protocol. Nothing here
is reverse-engineered, and nothing is specific to my particular machine except
the notes in [CONTEXT.md](CONTEXT.md). So there is a fair chance this works for
your treadmill too, and I hope it does. If it does, I would like to hear about
it. If it does not, the raw-data panel exists precisely so we can find out why.

## What it does

- **Live view** — speed, distance, time, calories, heart rate. Never scrolls, in
  either orientation.
- **Automatic sessions** — starts when the belt starts moving, manual pause and
  resume, ends automatically after 30 minutes of standstill.
- **Apple Health** — writes distance, active energy and heart rate as a workout.
  Write-only; the app never reads your health data.
- **History and statistics** — every session, with a speed-over-time chart
  (green = slow, red = fast), and totals for today / 7 days / 4 weeks / 365 days
  / all time.
- **Achievements** — 53 distance milestones, from your first kilometre to the
  circumference of the Earth, with varying degrees of seriousness.
- **Treadmill control** *(optional)* — set the target speed over the FTMS control
  point, with a confirmation for every command and an emergency stop that never
  asks.
- **Bilingual** — German and British English, switchable at runtime.
- **Raw data panel** — every notification as hex, for when the numbers look wrong.

## Safety

The app can make a treadmill accelerate underneath a person. The control feature
is built accordingly:

- every speed command needs an explicit confirmation in the UI,
- every target value is validated against the range the device itself reports
  (`0x2AD4`) **before** anything is sent,
- the emergency stop bypasses both confirmation and validation.

Even so: **test the control feature standing next to the treadmill, not on it.**
How a given firmware reacts to a speed command is not something a standard can
promise you.

## Compatibility

Any treadmill implementing the FTMS Treadmill Data characteristic (`0x2ACD`)
should work. Development and verification happened against a *LJJ-sports
`_SPORTS_HJL1.10`* walking pad (1.0–6.0 km/h, firmware 6.1.2).

The decoder is driven entirely by the FTMS flags field, so it copes with devices
that send different field combinations — including the one in my flat, which
sends two different packet layouts depending on the session.

## Requirements

- macOS with Xcode 15 or newer
- An iOS device running **iOS 16.0 or newer** (the deployment target is 16.0
  because the target device is an iPhone 8)
- An Apple Developer account for signing — a free one works, but the build
  expires after seven days
- [`xcodegen`](https://github.com/yonaskolb/XcodeGen) — the Xcode project is
  generated, not committed
- [`ios-deploy`](https://github.com/ios-control/ios-deploy) if you want to
  install from the command line

```bash
brew install xcodegen ios-deploy
```

## Build

```bash
swift test                     # pure-logic tests, no device needed
cd App && xcodegen generate    # create Treadmill.xcodeproj from project.yml
```

Then open `App/Treadmill.xcodeproj`, pick your development team under the
target's *Signing & Capabilities* tab, and run.

Or from the command line:

```bash
cd App
xcodebuild -project Treadmill.xcodeproj -scheme Treadmill \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/dev \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=YOURTEAMID build
ios-deploy --id YOUR-DEVICE-UDID \
  --bundle /tmp/dev/Build/Products/Debug-iphoneos/Treadmill.app
```

Your team ID is in the `OU` field of your signing certificate — *not* the
identifier in brackets after the certificate name, which is the person ID.

On first launch, iOS refuses to open an app signed with a development
certificate until you approve it under *Settings → General → VPN & Device
Management*.

## Architecture

Three layers, and the boundaries between them are the reason most of this is
testable without owning a treadmill:

| Layer | Path | Rule |
|---|---|---|
| `FTMSKit` | `Sources/FTMSKit/` | pure logic — no CoreBluetooth, no SwiftUI, no I/O |
| `FTMSTransport` | `Sources/FTMSTransport/` | CoreBluetooth, persistence, HealthKit, analysis — no UI |
| App | `App/Treadmill/` | SwiftUI, strings, wiring |

Data flow: `Data` (notification) → `TreadmillDataDecoder` → `LaufbandDaten` →
`Sitzungsaggregator` → `Zuwachs` → HealthKit sample + JSONL line.

Everything derived — history, statistics, achievements — is recomputed from the
raw JSONL recordings on disk. Nothing is stored twice, so a later fix to the
decoder corrects the past along with the present.

`Sources/FTMSDump/` is a macOS command-line tool that scans for the treadmill,
dumps its full GATT tree and records notifications, including a guided
calibration mode that talks you through a measurement run over the speech
synthesiser. It produced the device notes in [CONTEXT.md](CONTEXT.md), and it
needs no iPhone.

**The source language is German.** Identifiers, comments and documentation are
written in German, because that is the language the project was thought in. The
user interface is fully bilingual.

## Privacy

There is no networking code in this project. No account, no telemetry, no crash
reporting, no cloud sync. Recordings live in the app's own container as plain
JSONL files, and HealthKit access is write-only.

If you would rather verify that than believe it, put the phone behind a proxy and
watch nothing happen.

## Tests

```bash
swift test                                    # 115 tests, pure logic
cd App && xcodebuild test -project Treadmill.xcodeproj -scheme Treadmill \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'
```

The suite includes tests against real recorded device data with the treadmill's
own display readings noted alongside — synthetic payloads only prove conformance
to the specification, never conformance to an actual machine.

## Documentation

- [CONTEXT.md](CONTEXT.md) — device facts, measurements, decisions, open points
- [CLAUDE.md](CLAUDE.md) — working rules, protocol pitfalls, hard-won traps
- [CONTRIBUTING.md](CONTRIBUTING.md) — how to report a treadmill that does not work

## Licence

[GNU General Public License v3.0](LICENSE).

A modified version you distribute has to stay free software under the same
licence. Given that this project started as a way out of closed fitness apps,
anything else would have been inconsistent.
