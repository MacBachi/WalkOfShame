#!/usr/bin/env python3
"""
Decoder für die FTMS Treadmill Data Characteristic (UUID 0x2ACD).

Feldreihenfolge + Flag-Bits nach Fitness Machine Service v1.0 (Bluetooth SIG),
Datentypen/Auflösungen nach GATT Specification Supplement.

⚠️ Auflösungen sind aus der Spec übernommen, aber EMPIRISCH zu verifizieren:
   China-Bänder halten sich oft nur teilweise an den Standard.
   Gegencheck: bei 5,0 km/h am Display muss speed_kmh ~5.0 rauskommen.
"""
import struct

# (Flag-Bit, Feldname, Typ, Faktor, Einheit)
# Typ: u8 / u16 / u24 / s16   -- alles little endian
# Flag-Bit None => Feld ist immer da
# Flag-Bit 0 ist INVERTIERT ("More Data": 0 = Speed vorhanden)
FELDER = [
    (0,    "speed_kmh",            "u16", 0.01, "km/h"),
    (1,    "avg_speed_kmh",        "u16", 0.01, "km/h"),
    (2,    "distanz_m",            "u24", 1,    "m"),
    (3,    "steigung_prozent",     "s16", 0.1,  "%"),
    (3,    "rampenwinkel_grad",    "s16", 0.1,  "deg"),
    (4,    "hoehengewinn_pos_m",   "u16", 0.1,  "m"),
    (4,    "hoehengewinn_neg_m",   "u16", 0.1,  "m"),
    (5,    "pace_km_pro_min",      "u8",  0.1,  "km/min"),
    (6,    "avg_pace_km_pro_min",  "u8",  0.1,  "km/min"),
    (7,    "energie_gesamt_kcal",  "u16", 1,    "kcal"),
    (7,    "energie_pro_h_kcal",   "u16", 1,    "kcal"),
    (7,    "energie_pro_min_kcal", "u8",  1,    "kcal"),
    (8,    "herzfrequenz_bpm",     "u8",  1,    "bpm"),
    (9,    "met",                  "u8",  0.1,  ""),
    (10,   "dauer_s",              "u16", 1,    "s"),
    (11,   "restzeit_s",           "u16", 1,    "s"),
    (12,   "kraft_band_n",         "s16", 1,    "N"),
    (12,   "leistung_w",           "s16", 1,    "W"),
]

GROESSE = {"u8": 1, "u16": 2, "u24": 3, "s16": 2}


def _lies(daten: bytes, pos: int, typ: str) -> int:
    """Liest ein Feld ab Position pos, little endian."""
    n = GROESSE[typ]
    roh = daten[pos:pos + n]
    if len(roh) < n:
        raise ValueError(f"Payload zu kurz: brauche {n} Bytes an Offset {pos}, habe {len(roh)}")
    if typ == "u24":
        return int.from_bytes(roh, "little", signed=False)
    if typ == "s16":
        return struct.unpack("<h", roh)[0]
    return int.from_bytes(roh, "little", signed=False)


def decode_treadmill_data(daten: bytes) -> dict:
    """Zerlegt eine 0x2ACD-Notification in ein dict. Wirft ValueError bei Längenfehler."""
    if len(daten) < 2:
        raise ValueError("Payload < 2 Bytes, keine Flags lesbar")
    flags = int.from_bytes(daten[0:2], "little")
    pos = 2
    ergebnis = {"_flags": f"0x{flags:04X}", "_raw": daten.hex()}

    for bit, name, typ, faktor, einheit in FELDER:
        if bit == 0:
            # "More Data": Bit 0 == 0 heisst Speed IST vorhanden (invertierte Logik!)
            vorhanden = not (flags & 1)
        else:
            vorhanden = bool(flags & (1 << bit))
        if not vorhanden:
            continue
        wert = _lies(daten, pos, typ)
        pos += GROESSE[typ]
        ergebnis[name] = round(wert * faktor, 3) if faktor != 1 else wert

    ergebnis["_bytes_ungenutzt"] = len(daten) - pos
    return ergebnis


# ---------------- Selbsttest mit synthetischen Payloads ----------------
def _selbsttest():
    # Flags: Speed(bit0=0) + Distanz(2) + Steigung(3) + Energie(7) + Dauer(10)
    flags = (1 << 2) | (1 << 3) | (1 << 7) | (1 << 10)
    p = struct.pack("<H", flags)
    p += struct.pack("<H", 500)                    # 5,00 km/h
    p += (1234).to_bytes(3, "little")              # 1234 m
    p += struct.pack("<hh", 15, 10)                # 1,5 % / 1,0 deg
    p += struct.pack("<HHB", 42, 300, 5)           # kcal gesamt / pro h / pro min
    p += struct.pack("<H", 600)                    # 600 s
    d = decode_treadmill_data(p)
    assert d["speed_kmh"] == 5.0, d
    assert d["distanz_m"] == 1234, d
    assert d["steigung_prozent"] == 1.5, d
    assert d["energie_gesamt_kcal"] == 42, d
    assert d["dauer_s"] == 600, d
    assert d["_bytes_ungenutzt"] == 0, d

    # Minimalfall: nur Speed
    p2 = struct.pack("<HH", 0, 812)
    d2 = decode_treadmill_data(p2)
    assert d2["speed_kmh"] == 8.12, d2
    assert d2["_bytes_ungenutzt"] == 0, d2

    # More-Data gesetzt => kein Speed
    p3 = struct.pack("<H", 0x0001 | (1 << 10)) + struct.pack("<H", 90)
    d3 = decode_treadmill_data(p3)
    assert "speed_kmh" not in d3, d3
    assert d3["dauer_s"] == 90, d3

    print("✅ Selbsttest OK")
    print(d)


if __name__ == "__main__":
    _selbsttest()
