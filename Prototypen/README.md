# Prototypen

Der ursprüngliche Spike, mit dem geklärt wurde, ob sich das Laufband überhaupt
über FTMS auslesen lässt — bevor eine Zeile Swift existierte.

| Datei | Was es war |
|---|---|
| `dump.py` | BLE-Scan und GATT-Dump mit `bleak`, schrieb Notifications als JSONL |
| `mill.py` | erster Decoder für `0x2ACD`, tabellengesteuert |
| `flake.nix`, `flake.lock` | Nix-Shell mit der Python-Umgebung dafür |

**Nicht mehr in Benutzung.** Beides ist in Swift neu entstanden und dabei
deutlich weiter gekommen:

- `Sources/FTMSDump/` ersetzt `dump.py` und kann zusätzlich einen geführten
  Kalibrierungslauf ansagen.
- `Sources/FTMSKit/TreadmillDataDecoder.swift` ersetzt `mill.py` und behandelt
  zwei Dinge, die hier noch fehlten: die »Data Not Available«-Sentinels und
  Bytes, die die Flags nicht ankündigen.

Sie liegen hier, weil sie die Vorgeschichte sind — und weil `mill.py` die beiden
Protokollfallen (invertiertes Bit 0, uint24-Distanz) schon richtig hatte.
