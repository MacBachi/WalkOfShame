import Foundation
import Combine
import FTMSKit
import FTMSTransport
#if canImport(HealthKit)
import HealthKit
#endif

/// Verbindet BLE-Strom, Automatik, Persistenz und HealthKit zu einer
/// Trainingseinheit.
@MainActor
final class SitzungsSteuerung: ObservableObject {

    let verbindung = LaufbandVerbindung()
    private let sprachen: Sprachverwaltung

    /// Verschachtelte ObservableObjects lösen keine View-Updates aus. Ohne diese
    /// Weiterleitung bliebe die Live-Ansicht stehen, obwohl Pakete ankommen.
    private var weiterleitungen: [AnyCancellable] = []

    private var texte: Texte { sprachen.texte }

    @Published private(set) var zustand: Trainingszustand = .wartet
    @Published private(set) var meldung: String?
    /// In Health geschriebene Einheit, sobald fertig.
    @Published private(set) var zuletztGespeichert: String?
    /// Sekunden bis zum automatischen Ende, solange das Band steht.
    @Published private(set) var restzeitBisEnde: TimeInterval?
    /// Steht das Band gerade still (inkl. Karenz)? Nur dann wird die Restzeit
    /// angezeigt — sonst stünde »Band steht« schon eine Sekunde nach dem
    /// letzten Paket da, also praktisch immer.
    @Published private(set) var bandSteht = false

    /// Schreiben nach Apple Health — abschaltbar, falls nur beobachtet werden soll.
    @Published var healthAktiv = true
    /// Bei Bandbewegung automatisch starten.
    @Published var automatischerStart = true {
        didSet { automatik.automatischerStart = automatischerStart }
    }

    private var automatik = Trainingsautomatik()
    /// Läuft nur, solange eine Einheit offen ist — hält die Restzeit-Anzeige
    /// aktuell, auch wenn gerade keine Pakete etwas ändern.
    private var uhr: AnyCancellable?

    #if canImport(HealthKit)
    private let health = HealthKitSchreiber()
    #endif

    init(sprachen: Sprachverwaltung) {
        self.sprachen = sprachen
        for quelle in [verbindung.objectWillChange.eraseToAnyPublisher(),
                       sprachen.objectWillChange.eraseToAnyPublisher()] {
            weiterleitungen.append(quelle.sink { [weak self] _ in
                self?.objectWillChange.send()
            })
        }
        verbindung.beiPaket = { [weak self] daten, zuwachs in
            self?.verarbeite(zuwachs, geschwindigkeit: daten.momentanGeschwindigkeit)
        }
        uhr = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.aktualisiereRestzeit() }
    }

    var laeuft: Bool { zustand == .laeuft }
    var pausiert: Bool { zustand == .pausiert }
    var offen: Bool { zustand != .wartet }

    var dauerText: String {
        let sekunden = Int(verbindung.stand.dauer)
        return String(format: "%02d:%02d:%02d", sekunden / 3600, (sekunden % 3600) / 60, sekunden % 60)
    }

    /// „noch 12 min", solange das Band steht.
    var restzeitText: String? {
        guard offen, bandSteht, let rest = restzeitBisEnde else { return nil }
        return texte.stillstandstext(restSekunden: rest)
    }

    // MARK: - Paketverarbeitung

    private func verarbeite(_ zuwachs: Zuwachs?, geschwindigkeit: Double?) {
        let jetzt = Date()

        if let ereignis = automatik.verarbeite(zuwachs, geschwindigkeit: geschwindigkeit,
                                               zeitpunkt: jetzt) {
            switch ereignis {
            case .starte:
                Task { await self.starteEinheit() }
            case .beende(let grund):
                Task { await self.beendeEinheit(grund: grund) }
            }
        }
        zustand = automatik.zustand
        aktualisiereRestzeit()

        // Nur während einer laufenden Einheit sammeln — in Pause bewusst nicht.
        guard automatik.zustand == .laeuft, healthAktiv, let zuwachs else { return }
        #if canImport(HealthKit)
        Task { try? await health.fuegeHinzu(zuwachs) }
        #endif
    }

    private func aktualisiereRestzeit() {
        let jetzt = Date()
        restzeitBisEnde = automatik.verbleibendBisEnde(jetzt: jetzt)
        bandSteht = automatik.stehtStill(jetzt: jetzt)
    }

    // MARK: - Einheit starten und beenden

    private func starteEinheit() async {
        meldung = nil
        zuletztGespeichert = nil
        do {
            try verbindung.starteSitzung()
            #if canImport(HealthKit)
            if healthAktiv, HealthKitSchreiber.verfuegbar {
                try await health.frageBerechtigungAn()
                try await health.starte(beginn: Date())
            }
            #endif
            zustand = automatik.zustand
        } catch {
            meldung = String(format: texte.startFehlgeschlagen, "\(error)")
        }
    }

    private func beendeEinheit(grund: Beendigungsgrund) async {
        zustand = automatik.zustand
        verbindung.beendeSitzung()
        restzeitBisEnde = nil
        bandSteht = false

        #if canImport(HealthKit)
        guard healthAktiv, health.laeuft else {
            meldung = String(format: texte.nichtNachHealth, texte.beendigungstext(grund))
            return
        }
        do {
            if try await health.beende() != nil {
                zuletztGespeichert = String(
                    format: texte.inHealthGespeichert,
                    String(format: "%.2f", verbindung.stand.distanzKilometer),
                    dauerText, texte.beendigungstext(grund)
                )
            }
        } catch {
            meldung = String(format: texte.healthFehlgeschlagen, "\(error)")
        }
        #endif
    }

    // MARK: - Manuelle Eingriffe

    func starteManuell() {
        guard automatik.starteManuell(zeitpunkt: Date()) != nil else { return }
        zustand = automatik.zustand
        Task { await starteEinheit() }
    }

    func pausiere() {
        automatik.pausiere()
        zustand = automatik.zustand
    }

    func setzeFort() {
        automatik.setzeFort(zeitpunkt: Date())
        zustand = automatik.zustand
        aktualisiereRestzeit()
    }

    func beendeManuell() {
        guard case .beende(let grund)? = automatik.beendeManuell() else { return }
        zustand = automatik.zustand
        Task { await beendeEinheit(grund: grund) }
    }

    /// Bricht ab, ohne nach Health zu schreiben. Das Rohprotokoll bleibt liegen.
    func verwirf() {
        _ = automatik.beendeManuell()
        zustand = automatik.zustand
        verbindung.beendeSitzung()
        restzeitBisEnde = nil
        #if canImport(HealthKit)
        health.verwirf()
        #endif
        meldung = texte.verworfen
    }
}
