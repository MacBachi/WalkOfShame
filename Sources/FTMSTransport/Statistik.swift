import Foundation

/// Auswertungszeiträume der Statistikseite.
public enum Zeitraum: String, CaseIterable, Identifiable, Sendable {
    case heute
    case siebenTage
    case vierWochen
    case jahr
    case gesamt

    public var id: String { rawValue }

    /// Länge des Fensters. `nil` bedeutet »alles«.
    public var tage: Int? {
        switch self {
        case .heute: return 1
        case .siebenTage: return 7
        case .vierWochen: return 28
        case .jahr: return 365
        case .gesamt: return nil
        }
    }
}

/// Aufsummierte Werte eines Zeitraums.
public struct Statistikwerte: Equatable, Sendable {
    public var einheiten: Int = 0
    public var distanzMeter: Double = 0
    public var energieKcal: Double = 0
    public var dauer: TimeInterval = 0
    public var maxGeschwindigkeit: Double = 0
    /// Längste Einzeleinheit nach Strecke.
    public var laengsteEinheitMeter: Double = 0

    public var distanzKilometer: Double { distanzMeter / 1000 }

    /// Schnitt über alle Einheiten des Zeitraums, in km/h.
    public var durchschnittsgeschwindigkeit: Double {
        guard dauer > 0 else { return 0 }
        return (distanzMeter / dauer) * 3.6
    }

    public init() {}
}

public enum Statistik {

    /// Summiert die Einheiten eines Zeitraums.
    ///
    /// - Parameter jetzt: Bezugszeitpunkt — injizierbar, damit sich die
    ///   Zeitraumgrenzen ohne Warten testen lassen.
    public static func werte(_ einheiten: [Sitzungszusammenfassung],
                             zeitraum: Zeitraum,
                             jetzt: Date = Date(),
                             kalender: Calendar = .current) -> Statistikwerte {
        var ergebnis = Statistikwerte()

        for einheit in einheiten where liegtIm(zeitraum, einheit.beginn, jetzt, kalender) {
            ergebnis.einheiten += 1
            ergebnis.distanzMeter += einheit.distanzMeter
            ergebnis.energieKcal += einheit.energieKcal
            ergebnis.dauer += einheit.dauer
            ergebnis.maxGeschwindigkeit = max(ergebnis.maxGeschwindigkeit,
                                              einheit.maxGeschwindigkeit)
            ergebnis.laengsteEinheitMeter = max(ergebnis.laengsteEinheitMeter,
                                                einheit.distanzMeter)
        }
        return ergebnis
    }

    /// »Heute« heißt Kalendertag, nicht 24 Stunden rückwärts — sonst fiele die
    /// Einheit von gestern Abend am nächsten Morgen noch in »heute«.
    private static func liegtIm(_ zeitraum: Zeitraum, _ zeitpunkt: Date,
                                _ jetzt: Date, _ kalender: Calendar) -> Bool {
        switch zeitraum {
        case .gesamt:
            return true
        case .heute:
            return kalender.isDate(zeitpunkt, inSameDayAs: jetzt)
        case .siebenTage, .vierWochen, .jahr:
            guard let tage = zeitraum.tage,
                  let grenze = kalender.date(byAdding: .day, value: -tage,
                                             to: kalender.startOfDay(for: jetzt)) else {
                return false
            }
            return zeitpunkt > grenze && zeitpunkt <= jetzt
        }
    }
}
