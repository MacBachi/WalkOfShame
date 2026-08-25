import Foundation
import CoreBluetooth
import Combine
import FTMSKit

/// Die BLE-Verbindung zum Laufband: Scan, Connect, Notifications, Reconnect,
/// Steuerung — und alles, was die UI dafür beobachten muss.
///
/// Läuft komplett auf dem Main-Actor: CoreBluetooth wird mit `queue: nil`
/// erzeugt, alle Callbacks kommen damit auf dem Main-Thread, und die UI kann
/// den Zustand ohne Sprünge lesen.
/// Hinweis: bewusst `ObservableObject` statt `@Observable` — die Ziel-Hardware
/// ist ein iPhone 8, das über iOS 16.7 nicht hinauskommt. `@Observable` gibt es
/// erst ab iOS 17.
@MainActor
public final class LaufbandVerbindung: NSObject, ObservableObject {

    // MARK: - Beobachtbarer Zustand

    @Published public private(set) var status: Verbindungsstatus = .bereit
    @Published public private(set) var steuerstatus: Steuerstatus = .nichtAngefordert
    @Published public private(set) var letzteDaten: LaufbandDaten?
    @Published public private(set) var stand = SitzungsStand()
    @Published public private(set) var trainingStatus: TrainingStatus?
    @Published public private(set) var merkmale: FitnessMachineFeature?
    @Published public private(set) var geschwindigkeitsbereich: UnterstuetzteGeschwindigkeit?
    @Published public private(set) var neigungsbereich: UnterstuetzteNeigung?
    @Published public private(set) var rohLog = RohLog()
    /// Alle Geräte, die im laufenden Scan mit Service 1826 gesehen wurden.
    @Published public private(set) var gefundeneGeraete: [GefundenesGeraet] = []
    /// Umfang des Rohprotokolls. `.nurAuffaellige` ist der Alltagsmodus.
    public var protokollModus: RohLog.Modus {
        get { rohLog.modus }
        set { rohLog.modus = newValue }
    }
    /// Letzter Fehler, den die UI anzeigen soll.
    @Published public private(set) var letzterFehler: String?
    /// Sekunden seit der letzten Notification — Frühwarnung für stille Verbindungen.
    @Published public private(set) var letzterEmpfang: Date?

    /// Sicherheitsgrenzen, gegen die jeder Steuerbefehl geprüft wird.
    public var grenzen: Steuerungsgrenzen {
        Steuerungsgrenzen(geschwindigkeit: geschwindigkeitsbereich,
                          neigung: neigungsbereich, merkmale: merkmale)
    }

    // MARK: - Intern

    private var central: CBCentralManager!
    private var geraet: CBPeripheral?
    private var controlPoint: CBCharacteristic?
    private var aggregator = Sitzungsaggregator()
    private var speicher: SitzungsSpeicher?
    /// Merkt sich das zuletzt verbundene Gerät, um nach einem Abbruch gezielt
    /// dorthin zurückzuverbinden statt blind zu scannen.
    private var bekanntesGeraet: UUID?
    /// Scannt gerade nur für die Geräteauswahl, ohne zu verbinden.
    private var nurAuflisten = false
    private let restoreIdentifier = "at.local.treadmill.central"
    private static let bevorzugtSchluessel = "bevorzugtesGeraet"

    /// Ein Gerät im Scan.
    public struct GefundenesGeraet: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let name: String
        public var rssi: Int
    }

    /// Festgelegtes Gerät. Ist es gesetzt, verbindet sich die App **nur** damit —
    /// sonst mit dem erstbesten, das den Fitness Machine Service funkt.
    @Published public var bevorzugtesGeraet: UUID? {
        didSet {
            guard bevorzugtesGeraet != oldValue else { return }
            UserDefaults.standard.set(bevorzugtesGeraet?.uuidString,
                                      forKey: Self.bevorzugtSchluessel)
            wechsleGeraet()
        }
    }

    /// Wird für jedes dekodierte Paket aufgerufen — Hook für HealthKit.
    public var beiPaket: ((LaufbandDaten, Zuwachs?) -> Void)?

    public init(mitStateRestoration: Bool = true) {
        bevorzugtesGeraet = UserDefaults.standard
            .string(forKey: Self.bevorzugtSchluessel).flatMap(UUID.init(uuidString:))
        super.init()
        var optionen: [String: Any] = [:]
        #if os(iOS)
        // Damit iOS die App nach einem Kill wieder aufweckt und die Verbindung
        // zurückgibt, statt die laufende Session zu verlieren.
        if mitStateRestoration {
            optionen[CBCentralManagerOptionRestoreIdentifierKey] = restoreIdentifier
        }
        #endif
        central = CBCentralManager(delegate: self, queue: nil, options: optionen)
    }

    // MARK: - Steuerung durch die App

    public func starteSuche() {
        guard central.state == .poweredOn else { return }
        letzterFehler = nil
        status = .suche
        nurAuflisten = false

        // Festgelegtes bzw. zuletzt verbundenes Gerät zuerst: spart Scan-Zeit.
        if let ziel = bevorzugtesGeraet ?? bekanntesGeraet,
           let bekannt = central.retrievePeripherals(withIdentifiers: [ziel]).first {
            verbinde(bekannt)
            return
        }
        if bevorzugtesGeraet == nil,
           let bereits = central.retrieveConnectedPeripherals(
               withServices: [FTMSUUIDs.service]).first {
            verbinde(bereits)
            return
        }
        central.scanForPeripherals(withServices: [FTMSUUIDs.service])
    }

    /// Scannt für die Geräteauswahl — listet auf, ohne zu verbinden.
    /// Läuft auch bei bestehender Verbindung, damit sich ein anderes Band
    /// auswählen lässt, ohne vorher zu trennen.
    public func sucheGeraete() {
        guard central.state == .poweredOn else { return }
        gefundeneGeraete.removeAll()
        nurAuflisten = true
        central.scanForPeripherals(withServices: [FTMSUUIDs.service])
    }

    public func beendeGeraetesuche() {
        nurAuflisten = false
        central.stopScan()
    }

    /// Trennt das aktuelle Gerät und verbindet mit dem neu gewählten.
    private func wechsleGeraet() {
        if let geraet {
            central.cancelPeripheralConnection(geraet)
            self.geraet = nil
        }
        bekanntesGeraet = nil
        controlPoint = nil
        steuerstatus = .nichtAngefordert
        starteSuche()
    }

    public func trenne() {
        if let geraet { central.cancelPeripheralConnection(geraet) }
        central.stopScan()
    }

    /// Startet eine neue Sitzung: Zähler auf null, neue Protokolldatei.
    public func starteSitzung() throws {
        aggregator = Sitzungsaggregator()
        stand = SitzungsStand()
        speicher?.schliesse()
        speicher = try SitzungsSpeicher()
    }

    public func beendeSitzung() {
        speicher?.schliesse()
        speicher = nil
    }

    // MARK: - Control Point

    /// Handshake laut Spec: erst `0x00` Request Control, nach der Erfolgs-
    /// Indication `0x01` Reset.
    public func fordereSteuerungAn() {
        guard let merkmale, merkmale.geschwindigkeitSteuerbar || merkmale.neigungSteuerbar else {
            steuerstatus = .nichtVerfuegbar
            return
        }
        steuerstatus = .wirdAngefordert
        schreibe(.kontrolleAnfordern)
    }

    /// Sendet einen Steuerbefehl — nach Prüfung gegen die Gerätegrenzen.
    ///
    /// - Throws: ``Steuerungsgrenzen/Ablehnung``, wenn der Wert unzulässig ist.
    ///   Der Befehl geht dann gar nicht erst raus.
    public func sende(_ befehl: Steuerbefehl) throws {
        try grenzen.pruefe(befehl)
        schreibe(befehl)
    }

    /// Not-Stop. Umgeht bewusst jede Bereichsprüfung und jede Bestätigung —
    /// der rote Knopf muss immer durchkommen.
    public func notStop() {
        schreibe(.notStop)
    }

    private func schreibe(_ befehl: Steuerbefehl) {
        guard let geraet, let controlPoint else {
            letzterFehler = "Nicht verbunden — Befehl nicht gesendet."
            return
        }
        geraet.writeValue(befehl.nutzlast(), for: controlPoint, type: .withResponse)
        rohLog.haenge(befehl.nutzlast(), quelle: "2AD9 →", auffaellig: true)
    }

    // MARK: - Verbindungsaufbau

    private func verbinde(_ peripheral: CBPeripheral) {
        central.stopScan()
        geraet = peripheral
        peripheral.delegate = self
        status = .verbinde(name: peripheral.name ?? "Laufband")
        central.connect(peripheral, options: nil)
    }

    private func verarbeite(_ wert: Data, von characteristic: CBCharacteristic) {
        switch characteristic.uuid {
        case FTMSUUIDs.treadmillData:
            letzterEmpfang = Date()
            do {
                let daten = try TreadmillDataDecoder.dekodiere(wert)
                letzteDaten = daten
                let zuwachs = aggregator.verarbeite(daten, zeitpunkt: Date())
                stand = aggregator.stand
                // Restbytes und Sentinels sind die Frühwarnzeichen für eine
                // Firmware-Abweichung — die kommen ins Log, egal welcher Modus.
                let auffaellig = !daten.ueberschuessigeBytes.isEmpty
                    || !daten.nichtVerfuegbareFelder.isEmpty
                rohLog.haenge(wert, quelle: "2ACD", auffaellig: auffaellig)

                speicher?.schreibe(SitzungsZeile(
                    zeit: Date(), hex: wert.hexString,
                    distanzMeter: stand.distanzMeter, energieKcal: stand.energieKcal,
                    dauer: stand.dauer, geschwindigkeit: daten.momentanGeschwindigkeit,
                    herzfrequenz: zuwachs?.herzfrequenz
                ))
                beiPaket?(daten, zuwachs)
            } catch {
                // Undekodierbare Pakete niemals verschlucken — sie sind der
                // einzige Hinweis auf eine Firmware-Abweichung.
                rohLog.haenge(wert, quelle: "2ACD", fehler: "\(error)")
                letzterFehler = "Paket nicht dekodierbar: \(error)"
            }

        case FTMSUUIDs.feature:
            merkmale = FitnessMachineFeature(daten: wert)
            rohLog.haenge(wert, quelle: "2ACC", auffaellig: true)
            if let merkmale, !merkmale.geschwindigkeitSteuerbar, !merkmale.neigungSteuerbar {
                steuerstatus = .nichtVerfuegbar
            }

        case FTMSUUIDs.speedRange:
            geschwindigkeitsbereich = UnterstuetzteGeschwindigkeit(daten: wert)
            rohLog.haenge(wert, quelle: "2AD4", auffaellig: true)

        case FTMSUUIDs.inclinationRange:
            neigungsbereich = UnterstuetzteNeigung(daten: wert)
            rohLog.haenge(wert, quelle: "2AD5", auffaellig: true)

        case FTMSUUIDs.trainingStatus:
            trainingStatus = TrainingStatus(daten: wert)
            rohLog.haenge(wert, quelle: "2AD3", auffaellig: true)

        case FTMSUUIDs.controlPoint:
            rohLog.haenge(wert, quelle: "2AD9 ←", auffaellig: true)
            guard let antwort = Steuerantwort(daten: wert) else { return }
            if antwort.erfolgreich {
                // Nach erfolgreichem Request Control folgt laut Spec der Reset.
                if antwort.angefragterOpCode == 0x00 {
                    schreibe(.zuruecksetzen)
                    steuerstatus = .aktiv
                }
            } else {
                steuerstatus = .abgelehnt(grund: antwort.text)
                letzterFehler = "Gerät lehnte Befehl ab: \(antwort.text)"
            }

        default:
            rohLog.haenge(wert, quelle: characteristic.uuid.uuidString)
        }
    }
}

// MARK: - CBCentralManagerDelegate

// @preconcurrency, weil CoreBluetooth seine Delegate-Typen nicht als Sendable
// deklariert. Die Isolation stimmt trotzdem: der Manager wird mit `queue: nil`
// erzeugt, also kommen alle Callbacks auf dem Main-Thread an.
extension LaufbandVerbindung: @preconcurrency CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            status = .bereit
            starteSuche()
        case .poweredOff:
            status = .bluetoothAus
        case .unauthorized:
            status = .keineBerechtigung
        default:
            status = .bereit
        }
    }

    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any],
                               rssi RSSI: NSNumber) {
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "Laufband"
        let eintrag = GefundenesGeraet(id: peripheral.identifier, name: name,
                                       rssi: RSSI.intValue)
        if let index = gefundeneGeraete.firstIndex(where: { $0.id == eintrag.id }) {
            gefundeneGeraete[index] = eintrag
        } else {
            gefundeneGeraete.append(eintrag)
        }

        // Beim reinen Auflisten wird nichts verbunden.
        guard !nurAuflisten, geraet == nil else { return }
        // Ist ein Gerät festgelegt, kommt nur dieses infrage — sonst würde die
        // App sich beim Nachbarn mit Laufband anmelden.
        if let bevorzugtesGeraet, peripheral.identifier != bevorzugtesGeraet { return }
        verbinde(peripheral)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        bekanntesGeraet = peripheral.identifier
        status = .verbunden(name: peripheral.name ?? "Laufband")
        peripheral.discoverServices([FTMSUUIDs.service])
    }

    public func centralManager(_ central: CBCentralManager,
                               didFailToConnect peripheral: CBPeripheral, error: Error?) {
        geraet = nil
        status = .getrennt(grund: error?.localizedDescription ?? "Verbindung fehlgeschlagen")
        starteSuche()
    }

    public func centralManager(_ central: CBCentralManager,
                               didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        geraet = nil
        controlPoint = nil
        steuerstatus = .nichtAngefordert
        status = .getrennt(grund: error?.localizedDescription ?? "Verbindung beendet")
        // Sofort neu verbinden: die Sitzung läuft weiter, nur der Funk war weg.
        starteSuche()
    }

    /// State Restoration: iOS gibt die Verbindung nach einem Kill zurück.
    public func centralManager(_ central: CBCentralManager,
                               willRestoreState dict: [String: Any]) {
        let wiederhergestellt = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]
        guard let peripheral = wiederhergestellt?.first else { return }
        geraet = peripheral
        peripheral.delegate = self
        status = .verbunden(name: peripheral.name ?? "Laufband")
        peripheral.discoverServices([FTMSUUIDs.service])
    }
}

// MARK: - CBPeripheralDelegate

extension LaufbandVerbindung: @preconcurrency CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            if FTMSUUIDs.zuLesen.contains(characteristic.uuid),
               characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
            if FTMSUUIDs.zuAbonnieren.contains(characteristic.uuid),
               characteristic.properties.contains(.notify)
                || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == FTMSUUIDs.controlPoint {
                controlPoint = characteristic
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let wert = characteristic.value else { return }
        verarbeite(wert, von: characteristic)
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let error else { return }
        letzterFehler = "Schreiben auf \(characteristic.uuid.uuidString) fehlgeschlagen: "
            + error.localizedDescription
    }
}
