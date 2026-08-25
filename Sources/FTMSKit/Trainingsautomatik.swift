import Foundation

/// Zustand einer Trainingseinheit.
public enum Trainingszustand: Equatable, Sendable {
    /// Keine Einheit aktiv — es wird auf den Bandstart gewartet.
    case wartet
    case laeuft
    /// Vom Nutzer angehalten. Es werden keine Daten mehr gesammelt.
    case pausiert
}

/// Warum eine Einheit beendet wurde.
public enum Beendigungsgrund: Equatable, Sendable {
    case vomNutzer
    /// Das Band stand länger als die eingestellte Grenze still.
    case stillstand(dauer: TimeInterval)

    public var beschreibung: String {
        switch self {
        case .vomNutzer:
            return "manuell beendet"
        case .stillstand(let dauer):
            return "automatisch beendet nach \(Int(dauer / 60)) min Stillstand"
        }
    }
}

/// Was die Automatik der App aufträgt.
public enum Trainingsereignis: Equatable, Sendable {
    case starte
    case beende(grund: Beendigungsgrund)
}

/// Startet und beendet Trainingseinheiten automatisch anhand der Banddaten.
///
/// **Bewegungssignal:** Geschwindigkeit **oder** Distanzzuwachs. Am 18.08.2026
/// gemessen: bei stehendem Gurt meldet das Gerät exakt `0.00` km/h, sonst den
/// tatsächlichen Wert — die Geschwindigkeit ist also verwertbar und reagiert
/// sofort. Die Distanz bleibt als zweites Signal drin, weil sie unabhängig davon
/// eindeutig ist; sie allein wäre träge, da das Band nur in 10-m-Schritten meldet
/// (bei 1 km/h bis zu 36 s Verzug).
///
/// Zustandsbehaftet, aber ohne I/O — vollständig ohne Gerät testbar.
public struct Trainingsautomatik {

    /// Nach so langem Stillstand wird automatisch beendet.
    public var stillstandsGrenze: TimeInterval
    /// Ob bei Bandbewegung automatisch gestartet wird.
    public var automatischerStart: Bool

    /// Karenz, bevor ein fehlender Zuwachs als Stillstand *angezeigt* wird.
    /// Zwischen zwei Paketen vergeht rund eine Sekunde — das ist kein Stillstand.
    /// Betrifft nur die Anzeige, nicht ``stillstandsGrenze``.
    public var stillstandsKarenz: TimeInterval = 45

    public private(set) var zustand: Trainingszustand = .wartet
    /// Wann sich das Band zuletzt bewegt hat.
    public private(set) var letzteBewegung: Date?
    /// Bewegte sich das Band im zuletzt verarbeiteten Paket?
    public private(set) var bandLaeuft = false

    public init(stillstandsGrenze: TimeInterval = 30 * 60, automatischerStart: Bool = true) {
        self.stillstandsGrenze = stillstandsGrenze
        self.automatischerStart = automatischerStart
    }

    /// Steht das Band gerade — und zwar lange genug, um es anzuzeigen?
    ///
    /// Bewusst getrennt von ``verbleibendBisEnde``: das ist reine Rechnung ab
    /// der letzten Bewegung und liefert auch bei laufendem Band einen Wert.
    /// Für die Anzeige braucht es zusätzlich die Aussage, dass das Band steht.
    public func stehtStill(jetzt: Date) -> Bool {
        guard zustand != .wartet, !bandLaeuft, let dauer = stillstandsdauer(jetzt: jetzt) else {
            return false
        }
        return dauer >= stillstandsKarenz
    }

    /// Wie lange das Band schon steht. `nil`, solange nie Bewegung gesehen wurde.
    public func stillstandsdauer(jetzt: Date) -> TimeInterval? {
        letzteBewegung.map { jetzt.timeIntervalSince($0) }
    }

    /// Verbleibende Zeit bis zum automatischen Ende.
    public func verbleibendBisEnde(jetzt: Date) -> TimeInterval? {
        guard zustand != .wartet, let dauer = stillstandsdauer(jetzt: jetzt) else { return nil }
        return max(0, stillstandsGrenze - dauer)
    }

    /// Füttert die Automatik mit einem Paket-Zuwachs.
    ///
    /// - Returns: das auszuführende Ereignis, oder `nil`, wenn nichts zu tun ist.
    /// - Parameter geschwindigkeit: Momentangeschwindigkeit in km/h, falls das
    ///   Paket sie enthält. `nil` fällt auf die reine Distanzregel zurück.
    public mutating func verarbeite(_ zuwachs: Zuwachs?,
                                    geschwindigkeit: Double? = nil,
                                    zeitpunkt: Date) -> Trainingsereignis? {
        let bewegt = (zuwachs?.distanzMeter ?? 0) > 0 || (geschwindigkeit ?? 0) > 0
        bandLaeuft = bewegt

        if bewegt {
            letzteBewegung = zeitpunkt

            if zustand == .wartet, automatischerStart {
                zustand = .laeuft
                return .starte
            }
            // Bewegung während einer manuellen Pause setzt die Einheit **nicht**
            // fort — Pause ist eine Nutzerentscheidung und wird nur vom Nutzer
            // aufgehoben.
            return nil
        }

        // Stillstand: nur relevant, wenn eine Einheit offen ist.
        guard zustand != .wartet, let letzteBewegung else { return nil }

        let dauer = zeitpunkt.timeIntervalSince(letzteBewegung)
        guard dauer >= stillstandsGrenze else { return nil }

        zustand = .wartet
        self.letzteBewegung = nil
        return .beende(grund: .stillstand(dauer: dauer))
    }

    // MARK: - Manuelle Eingriffe

    /// Startet von Hand, ohne auf Bandbewegung zu warten.
    @discardableResult
    public mutating func starteManuell(zeitpunkt: Date) -> Trainingsereignis? {
        guard zustand == .wartet else { return nil }
        zustand = .laeuft
        letzteBewegung = zeitpunkt
        return .starte
    }

    public mutating func pausiere() {
        guard zustand == .laeuft else { return }
        zustand = .pausiert
    }

    public mutating func setzeFort(zeitpunkt: Date) {
        guard zustand == .pausiert else { return }
        zustand = .laeuft
        // Die Stillstandsuhr neu anwerfen: sonst würde eine lange Pause die
        // Einheit direkt nach dem Fortsetzen beenden.
        letzteBewegung = zeitpunkt
    }

    @discardableResult
    public mutating func beendeManuell() -> Trainingsereignis? {
        guard zustand != .wartet else { return nil }
        zustand = .wartet
        letzteBewegung = nil
        return .beende(grund: .vomNutzer)
    }
}
