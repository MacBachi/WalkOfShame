import Foundation
import CoreBluetooth
import FTMSKit

/// Bekannte FTMS-UUIDs.
enum UUIDs {
    nonisolated(unsafe) static let fitnessMachineService = CBUUID(string: "1826")
    nonisolated(unsafe) static let treadmillData = CBUUID(string: "2ACD")
    nonisolated(unsafe) static let fitnessMachineFeature = CBUUID(string: "2ACC")
    nonisolated(unsafe) static let trainingStatus = CBUUID(string: "2AD3")
    nonisolated(unsafe) static let unterstuetzteGeschwindigkeit = CBUUID(string: "2AD4")
    nonisolated(unsafe) static let unterstuetzteNeigung = CBUUID(string: "2AD5")
    nonisolated(unsafe) static let controlPoint = CBUUID(string: "2AD9")
    nonisolated(unsafe) static let fitnessMachineStatus = CBUUID(string: "2ADA")

    /// Device Information Service — beantwortet Hersteller/Modell.
    nonisolated(unsafe) static let deviceInformation = CBUUID(string: "180A")
    /// Textfelder in 180A, die als UTF-8 ausgegeben werden.
    nonisolated(unsafe) static let textFelder: [CBUUID: String] = [
        CBUUID(string: "2A29"): "Hersteller",
        CBUUID(string: "2A24"): "Modell",
        CBUUID(string: "2A25"): "Seriennummer",
        CBUUID(string: "2A26"): "Firmware",
        CBUUID(string: "2A27"): "Hardware",
        CBUUID(string: "2A28"): "Software",
        CBUUID(string: "2A23"): "System-ID"
    ]
}

/// Scannt nach dem Laufband, dumpt den kompletten GATT-Baum und schneidet
/// `0x2ACD`-Notifications mit. Bewusst read-only: der Control Point `0x2AD9`
/// wird nur *gefunden*, nie beschrieben.
// Invariante: alles läuft auf der Main-Queue. CBCentralManager wird mit
// `queue: nil` erzeugt (= Callbacks auf Main), und alle Timer laufen über
// DispatchQueue.main. Damit ist der Zugriff auf den Zustand serialisiert;
// Swift 6 kann das nur nicht selbst nachweisen.
final class FTMSDumper: NSObject, @unchecked Sendable {
    private let protokoll: DumpProtokoll
    private let aufzeichnungsdauer: TimeInterval
    private let namensFilter: String?
    private let sofortAlleScannen: Bool
    /// Gesprochener Kalibrierungsablauf statt stiller Aufzeichnung.
    private let mitRegie: Bool
    /// Aktuelle Phase — hängt an jedem aufgezeichneten Paket.
    private var phase = "-"
    private var erwarteteGeschwindigkeit: Double?

    private var central: CBCentralManager!
    private var geraet: CBPeripheral?
    private var gesehene: [UUID: String] = [:]

    /// Alle gefundenen `0x2ACD`-Instanzen in Entdeckungsreihenfolge.
    /// CoreBluetooth gibt keine GATT-Handles heraus — wir unterscheiden die
    /// Instanzen deshalb über Objektidentität und vergeben stabile Kennungen
    /// »2ACD#0«, »2ACD#1«, … inkl. Service-Instanz-Nummer.
    private var datenCharacteristics: [(kennung: String, characteristic: CBCharacteristic)] = []
    private var offeneServices = 0
    private var baumGedumpt = false
    private var notificationsGezaehlt = 0
    private var scanGestartet: Date?

    init(protokoll: DumpProtokoll,
         aufzeichnungsdauer: TimeInterval,
         namensFilter: String?,
         sofortAlleScannen: Bool,
         mitRegie: Bool = false) {
        self.protokoll = protokoll
        self.aufzeichnungsdauer = aufzeichnungsdauer
        self.namensFilter = namensFilter
        self.sofortAlleScannen = sofortAlleScannen
        self.mitRegie = mitRegie
    }

    func start() {
        protokoll.melde("start", "Protokoll: \(protokoll.pfad.path)")
        central = CBCentralManager(delegate: self, queue: nil)
    }

    private func beende(_ grund: String) {
        protokoll.melde("ende", "\(grund) — \(notificationsGezaehlt) Notification(s) aufgezeichnet")
        protokoll.melde("ende", "Datei: \(protokoll.pfad.path)")
        if let geraet { central.cancelPeripheralConnection(geraet) }
        protokoll.schliesse()
        exit(notificationsGezaehlt > 0 || baumGedumpt ? 0 : 2)
    }

    // MARK: - Scan

    private func starteScan(mitFilter: Bool) {
        scanGestartet = Date()
        if mitFilter {
            protokoll.melde("scan", "Suche nach Service 1826 …")
            central.scanForPeripherals(withServices: [UUIDs.fitnessMachineService])
            // Viele Bänder führen 1826 nicht im Advertising-Paket. Nach 12 s
            // ohne Treffer ungefiltert weitersuchen.
            DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
                guard let self, self.geraet == nil else { return }
                self.central.stopScan()
                self.protokoll.melde("scan", "Kein 1826 im Advertising — scanne jetzt ungefiltert.")
                self.starteScan(mitFilter: false)
            }
        } else {
            protokoll.melde("scan", "Ungefilterter Scan — alle sichtbaren Geräte werden gelistet.")
            central.scanForPeripherals(withServices: nil)
        }

        // Nicht nach 45 s stumm aufgeben: der Nutzer braucht Zeit, um die
        // iPhone-App zu beenden (die hält die Verbindung sonst im Hintergrund
        // und das Band hört auf zu werben) und ans Band zu gehen.
        planeErinnerungen()
        DispatchQueue.main.asyncAfter(deadline: .now() + 420) { [weak self] in
            guard let self, self.geraet == nil else { return }
            if self.mitRegie {
                Ansager.sprich("Das Band wurde nicht gefunden. Aufnahme abgebrochen.")
            }
            self.beende("Kein passendes Gerät gefunden. Band eingeschaltet und in Reichweite?")
        }
    }

    /// Meldet alle 45 s, solange nichts gefunden wurde — im Regie-Modus laut.
    private func planeErinnerungen() {
        for versuch in 1...8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(versuch) * 45) { [weak self] in
                guard let self, self.geraet == nil else { return }
                let text = "Band noch nicht gefunden. "
                    + "Bitte die App am iPhone ganz beenden und das Band einschalten."
                self.protokoll.melde("suche", text)
                if self.mitRegie, versuch % 2 == 1 { Ansager.sprich(text) }
            }
        }
    }

    // MARK: - Ausgabe

    private func kennung(fuer characteristic: CBCharacteristic) -> String {
        datenCharacteristics.first { $0.characteristic === characteristic }?.kennung
            ?? characteristic.uuid.uuidString
    }

    private func eigenschaften(_ p: CBCharacteristicProperties) -> String {
        var namen: [String] = []
        if p.contains(.read) { namen.append("read") }
        if p.contains(.write) { namen.append("write") }
        if p.contains(.writeWithoutResponse) { namen.append("writeNoResp") }
        if p.contains(.notify) { namen.append("notify") }
        if p.contains(.indicate) { namen.append("indicate") }
        return namen.isEmpty ? "—" : namen.joined(separator: ",")
    }
}

// MARK: - CBCentralManagerDelegate

extension FTMSDumper: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            starteScan(mitFilter: !sofortAlleScannen)
        case .unauthorized:
            protokoll.melde("fehler", "Bluetooth-Zugriff nicht erlaubt. In Systemeinstellungen → "
                + "Datenschutz & Sicherheit → Bluetooth den Terminal-Prozess freigeben.")
            beende("Abbruch: keine Berechtigung")
        case .poweredOff:
            beende("Abbruch: Bluetooth ist ausgeschaltet")
        case .unsupported:
            beende("Abbruch: kein Bluetooth-LE auf diesem Mac")
        default:
            protokoll.melde("bt", "Status: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "(ohne Namen)"

        let dienste = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?
            .map(\.uuidString).joined(separator: ",") ?? "—"

        // Jedes Gerät genau einmal listen, damit das Log lesbar bleibt.
        if gesehene[peripheral.identifier] == nil {
            gesehene[peripheral.identifier] = name
            protokoll.schreibe(DumpEreignis(
                zeit: Date(), art: "gerät",
                text: "\(name)  rssi=\(RSSI)  services=[\(dienste)]",
                quelle: peripheral.identifier.uuidString
            ))
        }

        let hatFTMS = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?
            .contains(UUIDs.fitnessMachineService) ?? false
        let passtZuName = namensFilter.map {
            name.localizedCaseInsensitiveContains($0)
        } ?? false

        // Ohne Namensfilter nur verbinden, wenn 1826 im Advertising steht —
        // sonst würden wir uns wahllos mit fremder Peripherie verbinden.
        guard hatFTMS || passtZuName else { return }

        central.stopScan()
        geraet = peripheral
        peripheral.delegate = self
        protokoll.melde("verbinde", "\(name) …")
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        protokoll.melde("verbunden", peripheral.name ?? "(ohne Namen)")
        peripheral.discoverServices(nil)     // nil = kompletter GATT-Baum
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral, error: Error?) {
        beende("Verbindung fehlgeschlagen: \(error?.localizedDescription ?? "unbekannt")")
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        protokoll.melde("getrennt", error?.localizedDescription ?? "sauber getrennt")
    }
}

// MARK: - CBPeripheralDelegate

extension FTMSDumper: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            beende("Keine Services gefunden: \(error?.localizedDescription ?? "—")")
            return
        }
        offeneServices = services.count
        protokoll.melde("gatt", "\(services.count) Service(s):")
        for service in services {
            protokoll.melde("gatt", "  Service \(service.uuid.uuidString)"
                + (service.isPrimary ? " (primary)" : " (secondary)"))
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let serviceIndex = peripheral.services?.firstIndex(where: { $0 === service }) ?? 0

        for characteristic in service.characteristics ?? [] {
            var zeile = "  \(service.uuid.uuidString) → \(characteristic.uuid.uuidString)"
                + "  [\(eigenschaften(characteristic.properties))]"

            if characteristic.uuid == UUIDs.treadmillData {
                let kennung = "2ACD#\(datenCharacteristics.count)"
                datenCharacteristics.append((kennung, characteristic))
                zeile += "  ⇒ \(kennung) (Service-Instanz \(serviceIndex))"
            }
            if characteristic.uuid == UUIDs.controlPoint {
                zeile += "  ⇒ Control Point vorhanden (wird NICHT beschrieben)"
            }
            protokoll.melde("gatt", zeile)
        }

        offeneServices -= 1
        guard offeneServices == 0, !baumGedumpt else { return }
        baumGedumpt = true
        starteAufzeichnung(peripheral)
    }

    private func starteAufzeichnung(_ peripheral: CBPeripheral) {
        protokoll.melde("gatt", "GATT-Baum vollständig. \(datenCharacteristics.count)× 0x2ACD gefunden.")

        for (_, service) in (peripheral.services ?? []).enumerated() {
            for characteristic in service.characteristics ?? [] {
                // Alles Lesbare einmal lesen — auch die Custom-Services.
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
                // Alles Notifizierbare abonnieren, damit ein evtl. proprietärer
                // Datenstrom in FFB0/FEE7 sichtbar wird. Der Control Point bleibt
                // bewusst unangetastet — wir schreiben in dieser Phase gar nichts.
                let istControlPoint = characteristic.uuid == UUIDs.controlPoint
                let kannNotify = characteristic.properties.contains(.notify)
                    || characteristic.properties.contains(.indicate)
                if kannNotify, !istControlPoint {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }

        if mitRegie {
            starteRegie()
        } else {
            protokoll.melde("aufnahme", "Zeichne \(Int(aufzeichnungsdauer)) s auf. "
                + "Jetzt wäre ein guter Moment, das Band laufen zu lassen.")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + aufzeichnungsdauer) { [weak self] in
            self?.beende("Aufzeichnung beendet")
        }
    }

    /// Plant alle Ansagen und spricht sie zur passenden Sekunde.
    private func starteRegie() {
        protokoll.melde("regie", "Kalibrierungsablauf, "
            + "\(Int(Kalibrierung.gesamtdauer / 60)) Minuten. Ansagen kommen per Sprachausgabe.")

        for anweisung in Kalibrierung.ablauf {
            DispatchQueue.main.asyncAfter(deadline: .now() + anweisung.beiSekunde) { [weak self] in
                guard let self else { return }
                self.phase = anweisung.phase
                self.erwarteteGeschwindigkeit = anweisung.erwarteteGeschwindigkeit
                var felder: [String: String] = ["phase": anweisung.phase]
                if let erwartet = anweisung.erwarteteGeschwindigkeit {
                    felder["erwartet_kmh"] = String(format: "%.1f", erwartet)
                }
                self.protokoll.schreibe(DumpEreignis(
                    zeit: Date(), art: "regie", text: anweisung.ansage,
                    hex: nil, quelle: anweisung.phase, dekodiert: felder
                ))
                Ansager.sprich(anweisung.ansage)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            protokoll.melde("fehler", "Notify \(characteristic.uuid.uuidString): \(error.localizedDescription)")
        } else {
            protokoll.melde("notify", "\(kennung(fuer: characteristic)) abonniert")
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let wert = characteristic.value else { return }

        switch characteristic.uuid {
        case UUIDs.treadmillData:
            notificationsGezaehlt += 1
            var felder: [String: String] = [:]
            var text = "Treadmill Data"
            do {
                let daten = try TreadmillDataDecoder.dekodiere(wert)
                felder["flags"] = String(format: "0x%04X", daten.flags.rohwert)
                if let v = daten.momentanGeschwindigkeit { felder["km/h"] = String(format: "%.2f", v) }
                if let v = daten.gesamtDistanz { felder["m"] = "\(v)" }
                if let v = daten.verstricheneZeit { felder["s"] = "\(v)" }
                if let v = daten.gesamtEnergie { felder["kcal"] = "\(v)" }
                if let v = daten.herzfrequenz { felder["bpm"] = "\(v)" }
                if let v = daten.neigung { felder["%"] = String(format: "%.1f", v) }
                if !daten.ueberschuessigeBytes.isEmpty {
                    felder["ÜBRIG"] = Data(daten.ueberschuessigeBytes).hexString
                }
                if !daten.nichtVerfuegbareFelder.isEmpty {
                    felder["n/a"] = daten.nichtVerfuegbareFelder.joined(separator: "|")
                }
                if mitRegie {
                    felder["phase"] = phase
                    if let erwartet = erwarteteGeschwindigkeit {
                        felder["erwartet"] = String(format: "%.1f", erwartet)
                    }
                }
            } catch {
                text = "Treadmill Data — DEKODIERFEHLER: \(error)"
            }
            protokoll.schreibe(DumpEreignis(
                zeit: Date(), art: "2acd", text: text,
                hex: wert.hexString, quelle: kennung(fuer: characteristic), dekodiert: felder
            ))

        case UUIDs.fitnessMachineFeature:
            var felder: [String: String] = [:]
            if let merkmale = FitnessMachineFeature(daten: wert) {
                felder["fitness"] = merkmale.unterstuetzteMerkmale.joined(separator: "|")
                felder["steuerung"] = merkmale.unterstuetzteZielwerte.joined(separator: "|")
            }
            protokoll.schreibe(DumpEreignis(
                zeit: Date(), art: "2acc", text: "Fitness Machine Feature",
                hex: wert.hexString, quelle: nil, dekodiert: felder
            ))

        default:
            var felder: [String: String] = [:]
            if let bezeichnung = UUIDs.textFelder[characteristic.uuid],
               let text = String(data: wert, encoding: .utf8) {
                felder[bezeichnung] = text.trimmingCharacters(in: .controlCharacters)
            } else if let text = String(data: wert, encoding: .utf8),
                      text.allSatisfy({ $0.isASCII && !$0.isNewline }) , !text.isEmpty {
                // Custom-Characteristics geben oft Klartext zurück — mitnehmen.
                felder["ascii"] = text
            }
            protokoll.schreibe(DumpEreignis(
                zeit: Date(), art: "wert",
                text: characteristic.uuid.uuidString,
                hex: wert.hexString, quelle: nil, dekodiert: felder
            ))
        }
    }
}
