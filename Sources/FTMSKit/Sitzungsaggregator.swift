import Foundation

/// Aufsummierter Stand einer Trainingseinheit.
public struct SitzungsStand: Equatable, Sendable {
    /// Meter seit Sitzungsbeginn — über Geräte-Resets hinweg aufaddiert.
    public var distanzMeter: Double = 0
    /// kcal seit Sitzungsbeginn.
    public var energieKcal: Double = 0
    /// Vom Gerät gemeldete Trainingszeit, über Resets hinweg aufaddiert.
    public var dauer: TimeInterval = 0
    /// Höchste je gemessene Momentangeschwindigkeit in km/h.
    public var maxGeschwindigkeit: Double = 0
    /// Zuletzt gemessene Momentangeschwindigkeit in km/h.
    public var letzteGeschwindigkeit: Double?
    /// Wie oft das Gerät seine Zähler zurückgesetzt hat (Neustart am Band).
    public var geraeteResets: Int = 0
    /// Anzahl verarbeiteter Pakete.
    public var pakete: Int = 0

    public var distanzKilometer: Double { distanzMeter / 1000 }

    public init() {}
}

/// Ein einzelner Zuwachs — genau das, was HealthKit als Sample braucht.
public struct Zuwachs: Equatable, Sendable {
    public let von: Date
    public let bis: Date
    public let distanzMeter: Double
    public let energieKcal: Double
    public let herzfrequenz: UInt8?

    public var istLeer: Bool { distanzMeter == 0 && energieKcal == 0 && herzfrequenz == nil }
}

/// Macht aus dem `0x2ACD`-Strom eine Trainingseinheit.
///
/// Das Band meldet **kumulative** Zähler, die es beim Start einer neuen Einheit
/// auf 0 zurücksetzt. Ein naiver `letzter - vorheriger`-Ansatz würde beim Reset
/// negative Werte liefern; hier wird der Reset erkannt und der bis dahin
/// erreichte Stand festgeschrieben.
///
/// Bewusst zustandsbehaftet, aber ohne I/O und ohne CoreBluetooth — damit ohne
/// Gerät testbar. Persistenz ist Sache der App-Schicht.
public struct Sitzungsaggregator {

    /// Ein kumulativer Gerätezähler, der jederzeit auf 0 springen kann.
    private struct Zaehler {
        var abgeschlossen: Double = 0
        var aktuell: Double = 0
        var gesamt: Double { abgeschlossen + aktuell }

        /// Gibt den Zuwachs zurück; erkennt dabei den Geräte-Reset.
        mutating func aktualisiere(_ neu: Double) -> (zuwachs: Double, reset: Bool) {
            if neu < aktuell {
                // Reset: bisherigen Stand festschreiben, neu von vorn zählen.
                abgeschlossen += aktuell
                aktuell = neu
                return (neu, true)
            }
            let zuwachs = neu - aktuell
            aktuell = neu
            return (zuwachs, false)
        }
    }

    private var distanz = Zaehler()
    private var energie = Zaehler()
    private var zeit = Zaehler()
    private var letzterZeitpunkt: Date?
    /// Sind wir gerade in einer Ruhephase (das Gerät sendet Nullframes)?
    private var ruhend = false
    /// Höchststand vor der Ruhephase — daran wird entschieden, ob das Gerät
    /// danach fortsetzt oder wirklich neu zählt.
    private var standVorRuhe: (distanz: Double, energie: Double, zeit: Double)?

    public private(set) var stand = SitzungsStand()

    public init() {}

    /// Verarbeitet ein dekodiertes Paket.
    ///
    /// - Returns: der Zuwachs seit dem letzten Paket, oder `nil` beim allerersten
    ///   Paket (da gibt es noch kein Intervall, das HealthKit füttern könnte).
    /// Erkennt den Ruheframe des Geräts: alle kumulativen Zähler gleichzeitig 0.
    ///
    /// Das Band (LJJ-sports `_SPORTS_HJL1.10`) sendet bei stehendem Gurt
    /// dauerhaft ein Paket mit Distanz = Zeit = Energie = 0 — und nimmt beim
    /// Weiterlaufen **den alten Stand wieder auf** (510 m → 0 → 520 m).
    /// Würde man das als Geräte-Reset werten, käme die Distanz doppelt in die
    /// Summe. Am 18.08.2026 gemessen und in `EchteDumpsTests` festgehalten.
    private func istRuheframe(_ daten: LaufbandDaten) -> Bool {
        let zaehler = [daten.gesamtDistanz.map(Double.init),
                       daten.gesamtEnergie.map(Double.init),
                       daten.verstricheneZeit.map(Double.init)].compactMap { $0 }
        return !zaehler.isEmpty && zaehler.allSatisfy { $0 == 0 }
    }

    @discardableResult
    public mutating func verarbeite(_ daten: LaufbandDaten, zeitpunkt: Date) -> Zuwachs? {
        stand.pakete += 1

        if let kmh = daten.momentanGeschwindigkeit {
            stand.letzteGeschwindigkeit = kmh
            stand.maxGeschwindigkeit = max(stand.maxGeschwindigkeit, kmh)
        }

        // Ruheframe: Zähler unangetastet lassen. Ob es ein echter Reset war,
        // entscheidet erst der nächste Wert ungleich null.
        if istRuheframe(daten), distanz.gesamt > 0 || zeit.gesamt > 0 {
            if !ruhend {
                ruhend = true
                standVorRuhe = (distanz.aktuell, energie.aktuell, zeit.aktuell)
            }
            defer { letzterZeitpunkt = zeitpunkt }
            guard let von = letzterZeitpunkt else { return nil }
            return Zuwachs(von: von, bis: zeitpunkt, distanzMeter: 0,
                           energieKcal: 0, herzfrequenz: nil)
        }

        if ruhend {
            ruhend = false
            // Nimmt das Gerät seinen alten Stand wieder auf, war die Null nur
            // eine Ruhepause — die Zähler stehen noch, es gibt nichts zu tun.
            // Zählt es dagegen von vorn, ist es ein echter Reset und der
            // Zaehler-Typ unten schreibt den bisherigen Stand fest.
            if let vorher = standVorRuhe,
               Double(daten.gesamtDistanz ?? 0) >= vorher.distanz {
                distanz.aktuell = vorher.distanz
                energie.aktuell = vorher.energie
                zeit.aktuell = vorher.zeit
            }
            standVorRuhe = nil
        }

        var resetGesehen = false
        var distanzZuwachs = 0.0
        var energieZuwachs = 0.0

        if let meter = daten.gesamtDistanz {
            let (zuwachs, reset) = distanz.aktualisiere(Double(meter))
            distanzZuwachs = zuwachs
            resetGesehen = resetGesehen || reset
        }
        if let kcal = daten.gesamtEnergie {
            let (zuwachs, reset) = energie.aktualisiere(Double(kcal))
            energieZuwachs = zuwachs
            resetGesehen = resetGesehen || reset
        }
        if let sekunden = daten.verstricheneZeit {
            let (_, reset) = zeit.aktualisiere(Double(sekunden))
            resetGesehen = resetGesehen || reset
        }

        if resetGesehen { stand.geraeteResets += 1 }

        stand.distanzMeter = distanz.gesamt
        stand.energieKcal = energie.gesamt
        stand.dauer = zeit.gesamt

        defer { letzterZeitpunkt = zeitpunkt }
        guard let von = letzterZeitpunkt else { return nil }

        return Zuwachs(
            von: von,
            bis: zeitpunkt,
            distanzMeter: distanzZuwachs,
            energieKcal: energieZuwachs,
            // 0 bpm heißt beim Gerät »kein Gurt verbunden«, nicht »Herzstillstand«.
            herzfrequenz: daten.herzfrequenz.flatMap { $0 == 0 ? nil : $0 }
        )
    }
}
