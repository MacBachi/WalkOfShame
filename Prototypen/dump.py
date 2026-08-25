#!/usr/bin/env python3
"""
FTMS-Laufband: scannen, verbinden, alles dumpen.

Läuft LOKAL auf deinem Mac/Linux-Rechner (braucht echte BLE-Hardware).
  pip install bleak
  python3 ftms_dump.py --scan                 # nur suchen
  python3 ftms_dump.py --addr <UUID/MAC>      # verbinden + dumpen
  python3 ftms_dump.py                        # erstes FTMS-Gerät nehmen

Schreibt jede Notification als JSON-Zeile nach ftms_log.jsonl (raw hex + decode).
Auf macOS ist --addr eine CoreBluetooth-UUID, keine MAC (Apple versteckt MACs).
"""
import argparse, asyncio, json, sys, time
from bleak import BleakClient, BleakScanner
from ftms_decode import decode_treadmill_data

FTMS_SERVICE = "00001826-0000-1000-8000-00805f9b34fb"

# Characteristics, die wir interessant finden
CHARS = {
    "2acc": ("Fitness Machine Feature",  "read"),
    "2acd": ("Treadmill Data",           "notify"),
    "2ad3": ("Training Status",          "notify"),
    "2ad4": ("Supported Speed Range",    "read"),
    "2ad5": ("Supported Inclination Range", "read"),
    "2ad9": ("Fitness Machine Control Point", "-"),
    "2ada": ("Fitness Machine Status",   "notify"),
}

LOG = "ftms_log.jsonl"


def kurz(uuid: str) -> str:
    """16-bit Kurzform aus einer 128-bit UUID."""
    return uuid.lower()[4:8]


def schreibe(eintrag: dict):
    eintrag["t"] = round(time.time(), 3)
    with open(LOG, "a") as f:
        f.write(json.dumps(eintrag, ensure_ascii=False) + "\n")


async def scannen(dauer=10.0):
    print(f"🔍 Scanne {dauer:.0f}s ...")
    geraete = await BleakScanner.discover(timeout=dauer, return_adv=True)
    treffer = []
    for adresse, (dev, adv) in geraete.items():
        dienste = [u.lower() for u in (adv.service_uuids or [])]
        ftms = FTMS_SERVICE in dienste
        markierung = "⭐ FTMS" if ftms else "      "
        print(f"{markierung}  {adresse}  rssi={adv.rssi:>4}  name={dev.name!r}")
        if dienste:
            print(f"          services: {dienste}")
        if adv.manufacturer_data:
            for mid, roh in adv.manufacturer_data.items():
                print(f"          mfg 0x{mid:04X}: {roh.hex()}")
        if ftms:
            treffer.append(adresse)
    return treffer


async def dumpen(adresse: str):
    print(f"🔌 Verbinde mit {adresse} ...")
    async with BleakClient(adresse, timeout=20.0) as client:
        print(f"✅ Verbunden. MTU={getattr(client, 'mtu_size', '?')}\n")

        # --- kompletter GATT-Baum ---
        print("=== GATT-Struktur ===")
        notify_ziele = []
        for service in client.services:
            print(f"Service {service.uuid}  ({service.description})")
            for c in service.characteristics:
                k = kurz(c.uuid)
                label = CHARS.get(k, ("", ""))[0]
                print(f"  Char {c.uuid} h={c.handle:<4} props={','.join(c.properties):<28} {label}")
                schreibe({"typ": "gatt", "service": service.uuid, "char": c.uuid,
                          "handle": c.handle, "props": list(c.properties), "label": label})
                # lesbare Chars gleich auslesen
                if "read" in c.properties:
                    try:
                        wert = await client.read_gatt_char(c)
                        print(f"       read -> {wert.hex()}")
                        schreibe({"typ": "read", "char": c.uuid, "handle": c.handle, "hex": wert.hex()})
                    except Exception as e:
                        print(f"       read fehlgeschlagen: {e}")
                # JEDE notify-fähige Char abonnieren -- auch mehrfach vorkommende 2ACD
                if "notify" in c.properties or "indicate" in c.properties:
                    notify_ziele.append(c)

        print(f"\n=== Abonniere {len(notify_ziele)} Characteristics ===")
        anzahl_2acd = sum(1 for c in notify_ziele if kurz(c.uuid) == "2acd")
        if anzahl_2acd > 1:
            print(f"⚠️  {anzahl_2acd}x 0x2ACD gefunden -- werden per Handle unterschieden.")

        def macher(char):
            def cb(_sender, daten: bytearray):
                k = kurz(char.uuid)
                eintrag = {"typ": "notify", "char": char.uuid, "handle": char.handle,
                           "hex": bytes(daten).hex(), "len": len(daten)}
                if k == "2acd":
                    try:
                        eintrag["decode"] = decode_treadmill_data(bytes(daten))
                    except Exception as e:
                        eintrag["decode_fehler"] = str(e)
                schreibe(eintrag)
                d = eintrag.get("decode", {})
                kompakt = {x: y for x, y in d.items() if not x.startswith("_")}
                print(f"[h{char.handle:<4} {k}] {bytes(daten).hex()}  {kompakt or ''}")
            return cb

        for c in notify_ziele:
            try:
                await client.start_notify(c, macher(c))
            except Exception as e:
                print(f"  start_notify {c.uuid} h={c.handle} fehlgeschlagen: {e}")

        print("\n▶️  Jetzt aufs Band steigen und losgehen. Strg-C beendet.\n")
        try:
            while True:
                await asyncio.sleep(1)
        except (KeyboardInterrupt, asyncio.CancelledError):
            print("\n⏹  Stoppe ...")
        for c in notify_ziele:
            try:
                await client.stop_notify(c)
            except Exception:
                pass


async def main():
    p = argparse.ArgumentParser()
    p.add_argument("--scan", action="store_true", help="nur scannen")
    p.add_argument("--addr", help="Adresse/UUID des Laufbands")
    p.add_argument("--dauer", type=float, default=10.0, help="Scan-Dauer in s")
    a = p.parse_args()

    if a.addr:
        await dumpen(a.addr)
        return
    treffer = await scannen(a.dauer)
    if a.scan:
        return
    if not treffer:
        print("\n❌ Kein Gerät mit FTMS im Advertising. Manche Bänder werben den Service nicht,")
        print("   bieten ihn aber trotzdem an -> nimm die Adresse aus der Liste und starte mit --addr.")
        sys.exit(1)
    print(f"\n➡️  Nehme {treffer[0]}")
    await dumpen(treffer[0])


if __name__ == "__main__":
    asyncio.run(main())
