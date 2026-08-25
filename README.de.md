# Walk of Shame

[![CI](https://github.com/MacBachi/WalkOfShame/actions/workflows/ci.yml/badge.svg)](https://github.com/MacBachi/WalkOfShame/actions/workflows/ci.yml)
[![Lizenz: GPL v3](https://img.shields.io/badge/Lizenz-GPLv3-blue.svg)](LICENSE)
![Plattform: iOS 16+](https://img.shields.io/badge/Plattform-iOS%2016%2B-lightgrey.svg)

Eine iOS-App, die ein Bluetooth-Laufband über den **Fitness Machine Service
(FTMS, `0x1826`)** ausliest, die Einheit nach Apple Health schreibt und das Band
optional steuert.

Kein Backend, kein Account, keine Analytics, kein Netzwerk-Traffic — alles bleibt
auf dem Gerät.

*[This file in English](README.md)*

## Warum es das gibt

Das hier ist ein privates Projekt. Ich habe ein Walking Pad zu Hause, und die App
des Herstellers war unbrauchbar: sie stürzte zuverlässig in genau dem Ablauf ab,
an dem man nicht vorbeikommt, wurde seit Jahren nicht repariert, und sie wollte
einen Account und eine Netzwerkverbindung für etwas, das mein Telefon und das
Laufband problemlos unter sich ausmachen können.

Also habe ich meine eigene geschrieben — für ein Laufband, in einer Wohnung, für
eine Person. Sie existiert, weil ich meine Spaziergänge in Apple Health haben
wollte, ohne meine Bewegungsdaten dafür irgendwem zu geben.

Andererseits: FTMS ist ein Standard der Bluetooth SIG, kein Hersteller-Protokoll.
Hier ist nichts reverse-engineered, und außer den Notizen in
[CONTEXT.md](CONTEXT.md) ist nichts an mein Gerät gebunden. Die Chance steht also
gut, dass es auch mit deinem Laufband funktioniert, und ich hoffe, dass es das
tut. Wenn ja, würde ich gern davon hören. Wenn nicht, ist das Rohdaten-Panel
genau dafür da, dass wir herausfinden, woran es liegt.

## Was sie kann

- **Live-Ansicht** — Geschwindigkeit, Distanz, Zeit, Kalorien, Puls. Scrollt in
  keiner Lage.
- **Automatische Einheiten** — startet, sobald sich das Band bewegt, manuelle
  Pause und Fortsetzen, endet automatisch nach 30 Minuten Stillstand.
- **Apple Health** — schreibt Distanz, Aktivenergie und Herzfrequenz als Workout.
  Nur schreibend; die App liest nie deine Gesundheitsdaten.
- **Verlauf und Statistik** — jede Einheit mit Geschwindigkeitsgrafik (grün =
  langsam, rot = schnell), dazu Summen für heute / 7 Tage / 4 Wochen / 365 Tage /
  gesamt.
- **Erfolge** — 53 Wegmarken von deinem ersten Kilometer bis zum Erdumfang, in
  unterschiedlichen Graden von Ernsthaftigkeit.
- **Steuerung** *(optional)* — Zielgeschwindigkeit über den FTMS Control Point,
  mit Bestätigung für jeden Befehl und einem Not-Stop, der nie nachfragt.
- **Zweisprachig** — Deutsch und britisches Englisch, zur Laufzeit umschaltbar.
- **Rohdaten-Panel** — jede Notification als Hex, für den Fall, dass die Zahlen
  komisch aussehen.

## Sicherheit

Die App kann ein Laufband unter einem Menschen beschleunigen. Die Steuerung ist
entsprechend gebaut:

- jeder Geschwindigkeitsbefehl braucht eine ausdrückliche Bestätigung im UI,
- jeder Zielwert wird gegen den vom Gerät selbst gemeldeten Bereich (`0x2AD4`)
  geprüft, **bevor** irgendetwas gesendet wird,
- der Not-Stop umgeht Bestätigung und Prüfung.

Trotzdem: **die Steuerung neben dem Band stehend testen, nicht darauf.** Wie eine
konkrete Firmware auf einen Geschwindigkeitsbefehl reagiert, kann kein Standard
garantieren.

## Kompatibilität

Jedes Laufband, das die FTMS Treadmill Data Characteristic (`0x2ACD`)
implementiert, sollte funktionieren. Entwickelt und verifiziert wurde gegen ein
*LJJ-sports `_SPORTS_HJL1.10`* Walking Pad (1,0–6,0 km/h, Firmware 6.1.2).

Der Decoder wird vollständig vom Flags-Feld gesteuert und kommt deshalb mit
Geräten zurecht, die andere Feldkombinationen senden — auch mit dem in meiner
Wohnung, das je nach Sitzung zwei verschiedene Paketformate schickt.

## Voraussetzungen

- macOS mit Xcode 15 oder neuer
- ein iOS-Gerät mit **iOS 16.0 oder neuer** (das Deployment-Target ist 16.0, weil
  das Zielgerät ein iPhone 8 ist)
- ein Apple-Developer-Account zum Signieren — ein kostenloser reicht, dann läuft
  der Build nach sieben Tagen ab
- [`xcodegen`](https://github.com/yonaskolb/XcodeGen) — das Xcode-Projekt wird
  erzeugt, nicht eingecheckt
- [`ios-deploy`](https://github.com/ios-control/ios-deploy), falls du von der
  Kommandozeile installieren willst

```bash
brew install xcodegen ios-deploy
```

## Bauen

```bash
swift test                     # reine Logik-Tests, ohne Gerät
cd App && xcodegen generate    # erzeugt Treadmill.xcodeproj aus project.yml
```

Danach `App/Treadmill.xcodeproj` öffnen, im Target unter *Signing &
Capabilities* dein Team wählen und starten.

Oder von der Kommandozeile:

```bash
cd App
xcodebuild -project Treadmill.xcodeproj -scheme Treadmill \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/dev \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=DEINETEAMID build
ios-deploy --id DEINE-GERAETE-UDID \
  --bundle /tmp/dev/Build/Products/Debug-iphoneos/Treadmill.app
```

Die Team-ID steht im `OU`-Feld deines Signaturzertifikats — *nicht* die Kennung
in der Klammer hinter dem Zertifikatsnamen, das ist die Personen-ID.

Beim ersten Start weigert sich iOS, eine mit Entwicklerzertifikat signierte App
zu öffnen, bis du sie unter *Einstellungen → Allgemein → VPN & Geräteverwaltung*
freigibst.

## Architektur

Drei Schichten, und die Grenzen dazwischen sind der Grund, warum sich das meiste
davon ohne Laufband testen lässt:

| Schicht | Ort | Regel |
|---|---|---|
| `FTMSKit` | `Sources/FTMSKit/` | reine Logik — kein CoreBluetooth, kein SwiftUI, keine I/O |
| `FTMSTransport` | `Sources/FTMSTransport/` | CoreBluetooth, Persistenz, HealthKit, Auswertung — kein UI |
| App | `App/Treadmill/` | SwiftUI, Texte, Verdrahtung |

Datenfluss: `Data` (Notification) → `TreadmillDataDecoder` → `LaufbandDaten` →
`Sitzungsaggregator` → `Zuwachs` → HealthKit-Sample + JSONL-Zeile.

Alles Abgeleitete — Verlauf, Statistik, Erfolge — wird aus den JSONL-Rohdateien
neu gerechnet. Nichts wird doppelt gespeichert, eine spätere Korrektur am Decoder
repariert damit auch die Vergangenheit.

`Sources/FTMSDump/` ist ein macOS-Kommandozeilenwerkzeug, das nach dem Laufband
scannt, den kompletten GATT-Baum dumpt und Notifications mitschneidet — inklusive
eines geführten Kalibrierungsmodus, der einen per Sprachausgabe durch einen
Messlauf führt. Damit sind die Gerätenotizen in [CONTEXT.md](CONTEXT.md)
entstanden, ganz ohne iPhone.

**Die Quellsprache ist Deutsch.** Bezeichner, Kommentare und Dokumentation sind
auf Deutsch, weil das die Sprache ist, in der das Projekt gedacht wurde. Die
Oberfläche ist vollständig zweisprachig.

## Datenschutz

In diesem Projekt gibt es keinen Netzwerkcode. Keinen Account, keine Telemetrie,
kein Crash-Reporting, keine Cloud-Synchronisation. Aufzeichnungen liegen als
einfache JSONL-Dateien im Container der App, der HealthKit-Zugriff ist rein
schreibend.

Wer das lieber prüfen als glauben möchte: Telefon hinter einen Proxy hängen und
zusehen, wie nichts passiert.

## Tests

```bash
swift test                                    # 115 Tests, reine Logik
cd App && xcodebuild test -project Treadmill.xcodeproj -scheme Treadmill \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'
```

Dazu gehören Tests gegen echte aufgezeichnete Gerätedaten mit den daneben
abgelesenen Display-Werten — synthetische Pakete beweisen nur Konformität zur
Spezifikation, nie Konformität zu einer echten Maschine.

## Dokumentation

- [CONTEXT.md](CONTEXT.md) — Gerätefakten, Messungen, Entscheidungen, offene Punkte
- [CLAUDE.md](CLAUDE.md) — Arbeitsregeln, Protokollfallen, teuer bezahlte Stolpersteine
- [CONTRIBUTING.md](CONTRIBUTING.md) — wie man ein Laufband meldet, das nicht läuft

## Lizenz

[GNU General Public License v3.0](LICENSE).

Eine veränderte Fassung, die du weitergibst, muss freie Software unter derselben
Lizenz bleiben. Für ein Projekt, das als Ausweg aus geschlossenen Fitness-Apps
angefangen hat, wäre alles andere inkonsequent.
