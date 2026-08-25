# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Sprache

Code-Kommentare, Bezeichner, Doc-Comments und Commit-Messages sind **auf Deutsch**.
Antworten an den User ebenfalls: knapp, Listen statt Fließtext, Wichtiges zuerst.

## Was das hier ist

iOS-App »Walk of Shame«, die ein Bluetooth-Laufband über den FTMS-Standard
(Fitness Machine Service `0x1826`) ausliest, Einheiten nach Apple Health schreibt
und das Band optional steuert. **Kein** Reverse Engineering — das Gerät
implementiert die Bluetooth-SIG-Spec v1.0.

**Harte Anforderung, kein Nice-to-have:** kein Backend, kein Account, keine
Analytics, kein Netzwerk-Traffic. Alles bleibt auf dem Gerät. Keine
Cloud-Dependencies vorschlagen.

Gerätedaten, Messergebnisse und offene Punkte stehen in [CONTEXT.md](CONTEXT.md) —
das ist die Quelle der Wahrheit, nicht diese Datei.

## Zielgerät: iPhone 8 mit iOS 16.7

Das bestimmt mehr, als es klingt. Das Gerät bekommt **nie** iOS 17, das
Deployment-Target ist iOS 16.0 und bleibt es.

Konkret nicht verfügbar und deshalb nicht vorschlagen:

- `@Observable` / `@Bindable` (Observation-Framework, ab iOS 17). Der Zustand
  läuft über `ObservableObject` mit `@Published`.
- `ContentUnavailableView` (ab iOS 17) — Ersatz: `ContentUnavailableErsatz`.
- `MainActor.assumeIsolated`, `chartScrollableAxes`, `onChange` mit zwei
  Parametern.

Swift Charts gibt es ab iOS 16, das ist erlaubt.

**Verschachtelte `ObservableObject`s lösen keine View-Updates aus.**
`SitzungsSteuerung` leitet deshalb `objectWillChange` von `LaufbandVerbindung`
und `Sprachverwaltung` explizit weiter. Ohne das bleibt die Live-Ansicht stehen,
obwohl Pakete ankommen — und man sucht den Fehler im BLE-Stack.

Fläche: 375 × 667 pt. Zum Prüfen den Simulator **SE-Test** (iPhone SE 3) nehmen,
nicht ein Pro Max, auf dem ohnehin alles passt.

## Kommandos

```bash
swift test                                                    # Package-Tests
swift test --filter TreadmillDataDecoderTests                  # eine Suite
swift test --filter TreadmillDataDecoderTests/testGesamtDistanzIstUint24   # ein Test

cd App && xcodegen generate                                    # Xcode-Projekt neu bauen
xcodebuild test -project Treadmill.xcodeproj -scheme Treadmill \
  -destination 'platform=iOS Simulator,name=SE-Test'           # App- und UI-Tests
```

Aufs Gerät bauen und installieren:

```bash
TEAM=$(security find-certificate -c "$(security find-identity -v -p codesigning \
  | head -1 | sed 's/.*"\(.*\)"/\1/')" -p | openssl x509 -noout -subject \
  | sed 's/.*OU=\([^,]*\).*/\1/')
UDID=$(xcrun xctrace list devices | grep -m1 iPhone | grep -o '[0-9a-f]\{40\}')

cd App && xcodebuild -project Treadmill.xcodeproj -scheme Treadmill \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/dev \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM" build \
&& ios-deploy --id "$UDID" \
  --bundle /tmp/dev/Build/Products/Debug-iphoneos/Treadmill.app --no-wifi
```

Die Team-ID steht im `OU`-Feld des Zertifikats, **nicht** in der Klammer des
Zertifikatsnamens — die ist die Personen-ID. Mit der falschen scheitert der Build
an »No Account for Team«. Sie steht bewusst **nicht** in `project.yml`: das Repo
ist öffentlich, und jeder baut mit seiner eigenen.

Das Xcode-Projekt ist **generiert**: `App/Treadmill.xcodeproj` entsteht aus
`App/project.yml` und ist kein Bearbeitungsziel. Build-Einstellungen,
Info.plist-Schlüssel und Dateilisten gehören in `project.yml`, danach
`xcodegen generate`.

## Architektur

Drei Schichten; die Grenze dazwischen ist der Grund, warum sich das Ding ohne
Gerät testen lässt — **nicht aufweichen**:

| Schicht | Ort | Regel |
|---|---|---|
| `FTMSKit` | `Sources/FTMSKit/` | reine Logik: kein CoreBluetooth, kein SwiftUI, keine I/O |
| `FTMSTransport` | `Sources/FTMSTransport/` | CoreBluetooth, Persistenz, HealthKit, Auswertung — kein UI |
| App | `App/Treadmill/` | nur SwiftUI, Texte und Verdrahtung |

`Sources/FTMSDump/` ist ein macOS-CLI zum Ausmessen des Geräts, nicht Teil der App.

Datenfluss: `Data` (Notification) → `TreadmillDataDecoder.dekodiere` →
`LaufbandDaten` → `Sitzungsaggregator` → `Zuwachs` → HealthKit-Sample +
JSONL-Zeile. Der Decoder ist zustandslos; alles Kumulative macht der Aggregator.

Verlauf und Statistik werden **immer** aus den JSONL-Rohdateien gerechnet, nie
zusätzlich gespeichert. Wird der Decoder korrigiert, stimmen sie von selbst.

## FTMS `0x2ACD` — die Fallen

Aufbau: `Flags` (uint16 LE), danach **nur die gesetzten Felder, in exakt der
Bit-Reihenfolge**, alles Little Endian. `ByteLeser` liest strikt sequenziell. Wer
eine `if`-Reihenfolge in `dekodiere` umsortiert, zerstört das Format.

1. **Bit 0 ist invertiert** ("More Data"): Bit = 0 heißt *Momentangeschwindigkeit
   vorhanden*. Gekapselt in `TreadmillFlags.momentanGeschwindigkeitVorhanden` —
   nie direkt gegen das Bit prüfen.
2. **Total Distance ist uint24**, nicht uint16. Wer 2 Bytes liest, verschiebt
   alle Folgefelder; der Fehler wird erst weiter hinten sichtbar und sieht aus
   wie ein Firmware-Bug. Ist er nicht.
3. **Das Gerät sendet zwei Paketformate** (`0x0584`/15 B und `0x058C`/19 B, das
   zweite mit Neigungsfeldern, die `0x2ACC` gar nicht als unterstützt meldet).
   Genau deshalb ist der Decoder flaggengesteuert und nicht auf ein Layout
   verdrahtet. Nie auf eine feste Paketlänge optimieren.
4. **»Data Not Available«-Sentinels** (`0x7FFF`, `0xFFFF`, `0xFF`) werden zu `nil`
   und in `nichtVerfuegbareFelder` vermerkt. Ohne das liefert eine nicht
   unterstützte Neigung 3276,7 % als Messwert.

## Konventionen, die nicht offensichtlich sind

- **Ruheframes sind kein Reset.** Bei stehendem Gurt sendet das Band dauerhaft
  Distanz = Zeit = Energie = 0 und nimmt danach den **alten Stand wieder auf**
  (510 m → 0 → 520 m). Als Geräte-Reset gewertet, zählt der Aggregator die
  Strecke doppelt. Eine Null in allen Zählern gleichzeitig ist eine Ruhephase;
  ob es ein echter Reset war, entscheidet erst der nächste Wert ungleich null.
- **Bewegungssignal ist Geschwindigkeit *und* Distanz.** Im Stillstand meldet das
  Band exakt `0.00` km/h — gemessen, nicht angenommen. Die Distanz allein wäre
  träge, weil das Band nur in 10-m-Schritten meldet.
- **Auflösungen sind gegen das Display geprüft** (18.08.2026, siehe CONTEXT.md):
  `FTMSSkalierung` stimmt an diesem Gerät. Weicht eine andere Firmware ab, wird
  `FTMSSkalierung` gerätespezifisch überschrieben — **niemals der Decoder
  gepatcht**.
- **`LaufbandDaten.ueberschuessigeBytes`** sind Bytes, die die Flags nicht
  ankündigen. Sie werden nicht verworfen, sondern gemeldet: Frühwarnung für
  Firmware-Abweichungen. Tests mit vollständigem Paket asserten auf leer.
- **`rohbytes` hängt an jedem dekodierten Paket.** Auch mit abgeschaltetem
  Debug-Modus werden auffällige Pakete protokolliert (Dekodierfehler, Restbytes,
  Sentinels, Control-Point-Verkehr). Ein komplett totes Log heißt, dass eine
  Firmware-Abweichung unbemerkt vorbeigeht.
- **`NutzlastBauer`** (Testtarget) baut Bytes unabhängig vom Decoder auf. Nicht
  durch Wiederverwendung von Decoder-Code »vereinfachen« — sonst maskiert
  derselbe Bug sich selbst.
- **`EchteDumpsTests`** prüft gegen echte Gerätedaten inklusive abgelesener
  Display-Werte. Synthetische Tests beweisen nur Spec-Konformität, nicht
  Geräte-Konformität; beide Suiten müssen grün bleiben.

## Sicherheit (Control Point `0x2AD9`)

Das Band beschleunigt unter dem User. Drei Regeln, die nicht verhandelbar sind:

1. **Jeder** Speed-Befehl braucht eine explizite Bestätigung im UI.
2. Jeder Zielwert wird vorher durch `Steuerungsgrenzen.pruefe` gegen `0x2AD4`
   geprüft. Sich darauf zu verlassen, dass das Gerät »Invalid Parameter«
   zurückgibt, heißt dem Gerät zu vertrauen, während jemand darauf steht.
3. Der Not-Stop (`LaufbandVerbindung.notStop()`) umgeht Bestätigung **und**
   Bereichsprüfung. Ein Not-Stop, der nachfragt oder an einer Validierung
   scheitern kann, ist keiner.

Handshake: `0x00` Request Control, nach der Erfolgs-Indication `0x01` Reset.
`stopp` und `pause` teilen sich Op Code `0x08` und unterscheiden sich nur im
Parameter (`0x01` / `0x02`) — eine Verwechslung heißt »Pause statt Not-Stop«.

## UI-Regeln, die nicht verhandelbar sind

- **Der Hauptbildschirm scrollt nie** — weder hoch noch quer. Keine `ScrollView`
  in `LiveView`, feste Aufteilung, `minimumScaleFactor` an jedem Text, eigenes
  Layout für `verticalSizeClass == .compact`. Abgesichert durch `LayoutTests`:
  die Suite prüft auf dem SE-Simulator, dass keine ScrollView existiert und alle
  Kacheln plus Startknopf im Fenster liegen.
- **Verlauf, Statistik und Einstellungen dürfen scrollen** — nur der
  Hauptbildschirm nicht. Beim Blättern durch die Historie steht niemand auf dem
  Band.
- **Einstellungen gehören nicht auf den Hauptbildschirm.** Health-Schalter,
  Autostart, Sprache, Gerätewahl und Debug-Modus liegen in `EinstellungenView`
  hinter dem Zahnrad, der Rohdaten-Zugang wiederum darin.
- **Erfolge hängen an der Gesamtstrecke**, nie am gewählten Zeitraum — sonst
  ließen sie sich durch Umschalten wieder verlieren.

## Zweisprachigkeit

Die App ist Deutsch **und** britisches Englisch. Kein `.strings`-Bundle, sondern
ein typisierter Katalog (`App/Treadmill/Texte.swift`): die Sprache ist zur
Laufzeit umschaltbar, und ein fehlendes Feld ist ein Compile-Fehler statt eines
leeren Labels. `SpracheTests` prüft zusätzlich auf leere und auf unübersetzte
(in beiden Katalogen identische) Felder — echte Gleichheit gehört in die
Ausnahmeliste, nicht in eine Lockerung des Tests.

`Sprachverwaltung.loese`: Deutsch nur bei deutscher Systemsprache oder deutschem
Dialekt (`de`, `gsw`, `bar`, `nds`, …), sonst Englisch. Manuelle Wahl schlägt die
Systemsprache.

Zahlen und Datumsangaben hängen ebenfalls an der Sprache: `Texte.gebietsschema`
setzt `de_AT` bzw. `en_GB`, die Wurzel-View schiebt es in `\.locale`. Für Zahlen
`Texte.zahl(_:_:)` benutzen statt `String(format:)` — sonst steht in der
deutschen Oberfläche »10.50 km«. `formatted()` direkt aufgerufen kennt die
Umgebung nicht und braucht `.locale(...)` explizit.

**Neue sichtbare Texte gehören in beide Kataloge** — nie als Literal in eine
View. UI-Tests erzwingen die Sprache über
`launchArguments = ["-sprachwahl", "deutsch"]`, sonst hingen sie an der
Systemsprache des Simulators.

## App-Icon

`App/Treadmill/Assets.xcassets/AppIcon.appiconset/icon.png` ist eine **gelieferte
Grafik**, kein generiertes Bild. `Werkzeuge/icon.swift` zeichnet eine
geometrische Alternative und ist ausdrücklich *nicht* die Quelle — ein Aufruf mit
dem dort dokumentierten Pfad überschreibt das echte Icon.

Prozedural gezeichnete Illustrationen (Figuren, Schuhe) werden nichts. Flache
geometrische Formen funktionieren, alles andere braucht eine echte Grafik.

## Geräte-Dump ohne iPhone

```bash
lldb -b -o run -o quit -- ./.build/debug/ftms-dump --dauer 60   # stiller Mitschnitt
lldb -b -o run -o quit -- ./.build/debug/ftms-dump --regie      # geführte Kalibrierung
./.build/debug/ftms-dump --auswerten dumps/ftms-….jsonl         # Auswertung, ohne BLE
```

`--regie` sagt über die macOS-Sprachausgabe an, welches Tempo einzustellen ist,
und schreibt die Phase zu jedem Paket ins Protokoll. Damit lässt sich ohne
zweite Person kalibrieren.

Zwei Voraussetzungen:

- **Die iPhone-App muss ganz beendet sein** (App-Switcher, nicht nur Home). Sie
  hält die Verbindung dank Background-Mode und Auto-Reconnect auch im
  Hintergrund, und ein verbundenes BLE-Gerät wirbt nicht mehr — der Mac findet
  das Band dann nicht.
- **Bluetooth-Berechtigung.** Direkt gestartet beendet macOS den Prozess sofort
  mit SIGABRT und **ohne Fehlermeldung**: TCC rechnet den Zugriff dem aufrufenden
  Terminal zu, und die eingebettete Info.plist allein reicht nicht. Der Umweg
  über `lldb` funktioniert zuverlässig; alternativ dem Terminal in
  Systemeinstellungen → Datenschutz & Sicherheit → Bluetooth die Freigabe geben.

## API-Unsicherheit

Bei Unsicherheit über Apple-API-Signaturen (HealthKit, CoreBluetooth State
Restoration): sagen und auf die aktuelle Apple-Doku verweisen — **nicht raten**,
keine erfundenen Zahlen oder Quellen. Ein iOS-Build ist die billigste
Verifikation: er prüft die Signaturen gegen das echte SDK.

## Fallen, die je einen Absturz oder eine Fehlersuche gekostet haben

- **`xcodegen` überschreibt die Info.plist.** Steht in `project.yml` ein
  `info: path:`, wird die Datei dort *generiert* — eine handgeschriebene
  Info.plist ist nach dem nächsten `xcodegen generate` weg. Alle Schlüssel
  gehören unter `info.properties`. Symptom: `NSInternalInconsistencyException —
  State restoration of CBCentralManager is only allowed for applications that
  have specified the "bluetooth-central" background mode`, direkt beim Start.
- **CoreBluetooth und Swift 6.** Die Delegate-Protokolle sind nicht Sendable.
  Die Conformance ist `@preconcurrency`, die Klasse `@MainActor`; korrekt ist das,
  weil der `CBCentralManager` mit `queue: nil` erzeugt wird und alle Callbacks
  auf dem Main-Thread ankommen. Wer die Queue ändert, bricht diese Annahme.
- **XCUITest tippt Toggles in der Zeilenmitte an** — das trifft die Beschriftung,
  und in einem Form schaltet das nicht um. Gezielt auf das Bedienelement rechts
  tippen (`coordinate(withNormalizedOffset:)`).
- **SwiftUI erzeugt in einem Form nur sichtbare Zeilen.** Ein Element außerhalb
  des Sichtbereichs *existiert* für den UI-Test nicht; erst scrollen, dann
  prüfen.
