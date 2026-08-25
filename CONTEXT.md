# Walk of Shame — Laufband (FTMS/BLE) → Apple Health

Native iOS-App, die ein Bluetooth-Laufband über den **Fitness Machine Service
`0x1826`** ausliest, Einheiten nach Apple Health schreibt und das Band optional
steuert. Ersatz für die unbrauchbare Hersteller-App.

**Harte Anforderung:** kein Backend, kein Account, keine Analytics, kein
Netzwerk-Traffic. Alles bleibt auf dem Gerät.

Zielgerät ist ein **iPhone 8 mit iOS 16.7** — das bestimmt das Deployment-Target
und schließt einiges an SwiftUI aus, siehe [CLAUDE.md](CLAUDE.md).

## Das Gerät

Am 18.08.2026 per `ftms-dump` vom Mac aus vollständig ausgelesen.

| | |
|---|---|
| BLE-Name | `LJJ-` + gerätespezifisches Suffix |
| Hersteller (`2A29`) | LJJ-sports |
| Modell (`2A24`) | `_SPORTS_HJL1.10` |
| Firmware / Hardware / Software | 6.1.2 / 1.0.0 / 6.3.0 |
| Geschwindigkeit (`2AD4`) | **1,00–6,00 km/h**, Schrittweite 0,10 |
| Neigung (`2AD5`) | min = max = 0 → **nicht vorhanden** |
| Herzfrequenz-Bereich (`2AD7`) | 0–199 bpm |

Wegen der 6-km/h-Obergrenze ist das ein **Walking Pad**, kein Laufband. Der
Workout-Typ in HealthKit ist deshalb `.walking`; `.running` wäre Schönfärberei
und führt Health bei der Kalorienschätzung in die Irre.

### GATT-Baum

```
180A  Device Information   2A29 2A24 2A25 2A27 2A26 2A28 2A23 2A2A 2A50   [read]
FEE7  Custom (Tuya-Muster) FEC7 [write]  FEC8 [indicate]  FEC9 [read]
FFB0  Custom               FFB1 [notify] FFB2 [writeNoResp] FFB3 [read]
1826  Fitness Machine      2AD3 [read,notify]   2ACD [notify]
                           2AD9 [write,indicate] 2ADA [notify]  2ACC [read]
                           2AD4 2AD7 2AD5 [read]
                           D18D2C10-C44C-11E8-A355-529269FB1459 [write]
```

### Fähigkeiten (`2ACC` = `0416000001000000`)

- Meldet: Total Distance, Expended Energy, Heart Rate Measurement, Elapsed Time
- Steuerbar: **nur Speed Target Setting** — keine Neigung, keine sonstigen Ziele

### Live-Daten (`2ACD`) — **zwei Paketformate**

Das Band wechselt das Format zwischen Sitzungen:

| Flags | Länge | Felder |
|---|---|---|
| `0x0584` | 15 B | Speed, Distance (uint24), Energy (3×), HR, Elapsed |
| `0x058C` | 19 B | dieselben **plus** Inclination + Ramp Angle (beide konstant 0) |

`0x058C` liefert Neigungsfelder, obwohl `0x2ACC` Inclination **nicht** als
unterstützt meldet. Genau dafür ist der Decoder flaggengesteuert: beide Formate
gehen restlos auf, ohne Codeänderung. Training Status (`2AD3`) meldet `0x0D` =
Manual Mode (Quick Start).

## Beantwortete Fragen aus dem Briefing

1. **`0x2ACD` genau einmal**, in einer einzigen `1826`-Instanz. Kein Handle-Problem.
2. **Ja, zwei Custom-Services**: `FEE7` (Tuya-typisch) und `FFB0`. `FEC8` sendet
   parallel einen proprietären Telemetrie-Stream (`faf123…`, enthält u. a.
   denselben Sekundenzähler wie FTMS). Ein **Session-Log wurde nicht beobachtet** —
   passiv kommt nichts Historisches. Herauszufinden, ob eins existiert, hieße auf
   `FEC7` bzw. `FFB2` zu schreiben; das wäre echtes Reverse Engineering und ist
   nicht nötig, weil FTMS live alles Gebrauchte liefert.
3. Apple Developer Account: **bezahlt** (eigene Team-ID, nicht im Repo).
4. Apple Watch: **vorhanden**, aber **kein Watch-Target gebaut**. Siehe offene
   Entscheidungen.
5. Scope: **Lesen und Steuern**, beschränkt auf Geschwindigkeit (mehr kann das
   Gerät nicht).
6. Marke/Modell: siehe oben.
7. Roh-Dumps: liegen in `dumps/*.jsonl`, ausgewertet in `EchteDumpsTests`.

## Stand

| Phase | Inhalt | Status |
|---|---|---|
| 1 | Decoder `0x2ACD` + Tests | ✅ gegen echte Gerätedaten bestätigt |
| 2 | BLE-Discovery, GATT-Dump, `0x2ACC` | ✅ per `ftms-dump` erledigt |
| 3 | Live-View, Raw-Hex-Panel, Reconnect | ✅ auf dem iPhone gelaufen |
| 4 | HealthKit-Write | ⚠️ gebaut — **noch nicht** in der Health-App gegengeprüft |
| 5 | Background-Härtung | ⚠️ konfiguriert — **noch nicht** empirisch getestet |
| 6 | Control Point `0x2AD9` (nur Speed) | ⚠️ gebaut — **noch nie** ans Gerät gesendet |

115 Package-Tests, 24 App-Tests, 7 UI-Tests. Die App ist per `ios-deploy` auf dem
iPhone installiert und verbindet sich mit dem Band.

**Was ⚠️ bedeutet:** der Code läuft, aber die Wirkung ist unbestätigt. HealthKit
schreibt — ob die Einheit in der Health-App richtig ankommt, hat noch niemand
nachgesehen. Der Control Point ist gegen die Spec verifiziert, aber es wurde noch
kein einziger Befehl an das Gerät geschickt.

## Kalibrierung — erledigt am 18.08.2026

Geführter 13-Minuten-Lauf (`ftms-dump --regie`), Phasen 1,0 → 3,0 → 5,0 → 6,0 km/h,
dazwischen Stillstand und Neustart. Display-Endwerte vom Nutzer abgelesen:
0,59 km / 9:58 / 19 kcal.

| Größe | dekodiert | Display | Ergebnis |
|---|---|---|---|
| Geschwindigkeit | 1,00 / 3,00 / 5,00 / 6,00 | 1,0 / 3,0 / 5,0 / 6,0 | **exakt**, über den ganzen Bereich |
| Zeit | 598 s | 9:58 | **exakt** |
| Kalorien | 19 | 19 | **exakt** |
| Distanz | 580 m | 590 m | 1,7 % — genau ein 10-m-Schritt |

**`FTMSSkalierung` bleibt unverändert.** Die Spec-Auflösungen stimmen an diesem
Gerät.

Wichtig bei der Auswertung: die **Plateaus** zählen, nicht die Mittelwerte. Über
eine ganze Phase gemittelt zeigte sich scheinbar ein Offset von −0,10 km/h — das
waren nur die Beschleunigungsrampen. Auf dem Plateau ist die Abweichung null.

### Zwei Verhaltensweisen, die erst dieser Lauf aufgedeckt hat

1. **Im Stillstand meldet das Band exakt `0.00` km/h.** Die konstante 1,00 aus dem
   Vormittags-Dump war *echte* langsame Bandbewegung, keine Ruheanzeige — eine
   Fehlinterpretation von zu wenig Daten. Die `Trainingsautomatik` nutzt deshalb
   Geschwindigkeit **und** Distanz als Bewegungssignal und startet sofort, statt
   auf den nächsten 10-m-Schritt zu warten (bei 1 km/h wären das bis zu 36 s).
2. **Ruheframes statt Zähler-Reset.** Bei stehendem Gurt sendet das Band dauerhaft
   ein Paket mit Distanz = Zeit = Energie = 0 — und nimmt beim Weiterlaufen den
   **alten Stand wieder auf** (510 m → 0 → 520 m). Der Aggregator hätte das als
   Geräte-Reset gewertet und die Distanz doppelt gezählt (510 + 520 statt 520).
   Gefixt: eine Null in allen Zählern gleichzeitig ist eine Ruhephase; ob es ein
   echter Reset war, entscheidet erst der nächste Wert ungleich null.

## Offen

Für den nächsten Testlauf, in dieser Reihenfolge:

1. **HealthKit prüfen:** erscheint die Einheit in der Health-App mit korrekter
   Dauer, Distanz, Kalorien?
2. **Background:** 30 min mit gesperrtem Screen, danach das Rohprotokoll im
   Debug-Panel auf Lücken prüfen.
3. **Steuerung** — zuletzt und mit Vorsicht: neben dem Band stehen, nicht darauf.
   Handshake anfordern, kleinsten Wert senden, Not-Stop testen, **bevor** jemand
   das Band betritt.
4. **Kein Netzwerk-Traffic** mit einem Proxy verifizieren.

Noch zu entscheiden:

- **Watch-Target ja/nein.** Die App ist iPhone-only. Ein Watch-Target brächte
  echte Herzfrequenz — das Band meldet konstant 0 bpm, weil kein Gurt verbunden
  ist — kostet aber ein zweites Target plus WatchConnectivity.

## Was in der App steckt

- **Trainingsautomatik:** startet automatisch, sobald sich das Band bewegt;
  manuelle Pause und Fortsetzen; beendet automatisch nach 30 min Stillstand und
  schreibt dabei nach Health. Bewegung während einer Pause setzt die Einheit
  bewusst **nicht** fort — Pause ist eine Nutzerentscheidung.
- **Live-View:** Geschwindigkeit, Distanz, Zeit, Kalorien, Puls,
  Verbindungsstatus, Trainingszustand, Restzeit bis zum automatischen Ende.
  Scrollt in keiner Lage.
- **Steuerung:** Handshake, Zielgeschwindigkeit per Slider innerhalb der vom
  Gerät gemeldeten Grenzen, Bestätigungsdialog, roter Not-Stop ohne Rückfrage.
- **Verlauf:** Liste aller Einheiten, pro Einheit eine Detailseite mit
  Geschwindigkeitsgrafik (grün langsam → rot schnell). Nach links wischen löscht
  eine Einheit samt Rohdatei — in Apple Health bleibt sie stehen und muss dort
  separat gelöscht werden.
- **Statistik:** heute / 7 Tage / 4 Wochen / 365 Tage / gesamt.
- **Erfolge:** 53 Wegmarken an der Gesamtstrecke, von 1 km bis zum Erdumfang.
  Hängen an `.gesamt`, nicht am gewählten Zeitraum — sonst ließen sie sich durch
  Umschalten wieder verlieren. Wer Einheiten löscht, kann sich einen Erfolg
  folgerichtig wieder abtrainieren.
- **Gerätewahl:** in den Einstellungen. Ohne Festlegung verbindet sich die App
  mit dem erstbesten Gerät, das `1826` funkt; mit Festlegung **nur** mit diesem.
  Überlebt Neustarts.
- **Zweisprachig:** Deutsch und britisches Englisch, zur Laufzeit umschaltbar.
- **Maßsystem-Schalter:** eine Attrappe. Wer auf imperial umstellt, bekommt eine
  Belehrung und die App beendet sich.
- **Debug-Panel:** abschaltbar, hinter den Einstellungen. Ist der Debug-Modus aus,
  verschwindet der Zugang aus der Toolbar und es werden **nur auffällige Pakete**
  protokolliert: Dekodierfehler, nicht angekündigte Restbytes, Sentinels und der
  gesamte Control-Point-Verkehr. Ein komplett totes Log hieße, dass eine
  Firmware-Abweichung unbemerkt vorbeigeht.
- **Persistenz:** jede Notification landet sofort als JSONL-Zeile in
  `Documents/sitzungen/`. Ein Kill mitten im Workout kostet maximal die letzte,
  halb geschriebene Zeile — getestet, indem eine Datei absichtlich abgeschnitten
  und wieder eingelesen wird.
- **Reconnect:** bei Verbindungsverlust wird automatisch neu gesucht, bevorzugt
  am zuletzt bekannten Gerät. Die Sitzung läuft weiter.
- **App-Icon:** eine gelieferte Grafik, siehe [CLAUDE.md](CLAUDE.md).

## Architektur-Entscheidungen

- **`FTMSKit`** ist ein reines Swift-Package ohne CoreBluetooth und ohne UI, damit
  Parser, Aggregator, Steuerungsgrenzen und Trainingsautomatik vollständig ohne
  Gerät testbar bleiben. Die App bindet es als lokales Package ein.
- **`ftms-dump`** ist ein separates macOS-CLI-Target. BLE-Zugriff bleibt damit aus
  der Bibliothek heraus, und Gerätefragen lassen sich ohne iPhone klären.
- **`FTMSSkalierung`** kapselt die Auflösungen und ist pro Gerät überschreibbar —
  weicht eine Firmware ab, wird dort korrigiert, nicht im Decoder.
- **Sentinel-Behandlung:** FTMS definiert »Data Not Available« (`0x7FFF`,
  `0xFFFF`, `0xFF`). Diese Werte werden zu `nil` und in `nichtVerfuegbareFelder`
  vermerkt, statt als Messwert durchzurutschen.

## Auswertung: woher die Zahlen kommen

Alles Abgeleitete wird aus den JSONL-Rohdateien gerechnet, nichts zusätzlich
gespeichert. Wird der Decoder korrigiert, stimmen Verlauf und Statistik nach
einem Neustart von selbst.

- `Sitzungsarchiv.fasseZusammen` liest eine Datei zu einer Zusammenfassung.
- `Sitzungsarchiv.verlauf` dünnt auf höchstens 400 Punkte aus — eine Stunde
  erzeugt 3.600 Zeilen, und mehr Punkte als Pixel bringt keine Grafik.
- `Statistik.werte` summiert über einen Zeitraum. »Heute« ist der Kalendertag,
  kein 24-Stunden-Fenster: sonst zählte die Einheit von gestern Abend am nächsten
  Morgen noch mit. Der Bezugszeitpunkt ist injizierbar, damit sich die Grenzen
  ohne Warten testen lassen.
- Einheiten unter 1 m Strecke werden ausgeblendet, sonst füllt sich die Liste mit
  Fehlstarts.

Die Farbskala der Grafik nutzt aus, dass die Geschwindigkeit auf der y-Achse
liegt: ein senkrechter Farbverlauf bildet sie ab, ohne jedes Liniensegment
einzeln einfärben zu müssen. Die y-Achse ist auf mindestens 0–6 km/h fixiert
(Gerätemaximum), damit dieselbe Geschwindigkeit in jeder Einheit dieselbe Farbe
hat.

## Wichtig beim Testen mit dem Mac

Die iPhone-App hält die BLE-Verbindung dank Background-Mode und Auto-Reconnect
auch im Hintergrund. Ein verbundenes BLE-Gerät wirbt nicht mehr — der Mac findet
das Band dann nicht. Vor einem `ftms-dump`-Lauf die App im App-Switcher **ganz
wegwischen**, Home-Taste reicht nicht.
