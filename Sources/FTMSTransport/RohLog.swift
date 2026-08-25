import Foundation
import FTMSKit

/// Ringpuffer für das Raw-Hex-Debug-Panel.
public struct RohLog: Sendable {

    /// Wie viel mitgeschrieben wird.
    public enum Modus: String, Sendable, CaseIterable {
        /// Jede Notification. Für Fehlersuche und Kalibrierung.
        case alles
        /// Nur Pakete, an denen etwas nicht stimmt: Dekodierfehler, nicht
        /// angekündigte Restbytes, »Data Not Available«-Sentinels.
        ///
        /// Der Normalfall im Alltag. Kostet fast nichts und lässt trotzdem
        /// genau die Pakete übrig, die man später sehen will — ein komplett
        /// abgeschaltetes Log heißt, dass eine Firmware-Abweichung unbemerkt
        /// vorbeigeht.
        case nurAuffaellige

        public var beschreibung: String {
            switch self {
            case .alles: return "Alle Pakete"
            case .nurAuffaellige: return "Nur Auffälligkeiten"
            }
        }
    }

    public struct Eintrag: Identifiable, Sendable, Equatable {
        public let id = UUID()
        public let zeit: Date
        public let quelle: String
        public let hex: String
        /// Fehlermeldung, falls das Paket nicht dekodiert werden konnte.
        public let fehler: String?
        /// Wurde als auffällig eingestuft.
        public let auffaellig: Bool
    }

    public private(set) var eintraege: [Eintrag] = []
    public let maximum: Int
    public var modus: Modus

    public init(maximum: Int = 500, modus: Modus = .alles) {
        self.maximum = maximum
        self.modus = modus
    }

    /// Hängt einen Eintrag an, sofern der Modus ihn zulässt.
    ///
    /// - Parameter auffaellig: erzwingt die Aufnahme unabhängig vom Modus.
    /// - Returns: ob der Eintrag aufgenommen wurde.
    @discardableResult
    public mutating func haenge(_ daten: Data, quelle: String,
                                fehler: String? = nil,
                                auffaellig: Bool = false) -> Bool {
        let istAuffaellig = auffaellig || fehler != nil
        guard modus == .alles || istAuffaellig else { return false }

        eintraege.append(Eintrag(zeit: Date(), quelle: quelle, hex: daten.hexString,
                                 fehler: fehler, auffaellig: istAuffaellig))
        if eintraege.count > maximum {
            eintraege.removeFirst(eintraege.count - maximum)
        }
        return true
    }

    public mutating func leere() {
        eintraege.removeAll()
    }

    /// Für »Log teilen« im Debug-Panel.
    public var alsText: String {
        let format = ISO8601DateFormatter()
        return eintraege.map { eintrag in
            let fehler = eintrag.fehler.map { "  FEHLER: \($0)" } ?? ""
            let marke = eintrag.auffaellig ? "  ⚠︎" : ""
            return "\(format.string(from: eintrag.zeit))  \(eintrag.quelle)  "
                + "\(eintrag.hex)\(marke)\(fehler)"
        }.joined(separator: "\n")
    }
}
