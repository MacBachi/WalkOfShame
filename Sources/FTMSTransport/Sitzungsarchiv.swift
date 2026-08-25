import Foundation
import FTMSKit

/// Ein Messpunkt für die Verlaufsgrafik.
public struct Verlaufspunkt: Equatable, Sendable, Identifiable {
    public var id: TimeInterval { sekunde }
    /// Sekunden seit Beginn der Einheit.
    public let sekunde: TimeInterval
    public let geschwindigkeit: Double
    public let distanzMeter: Double
}

/// Was von einer aufgezeichneten Einheit übrig bleibt, ohne die Datei komplett
/// im Speicher zu halten.
public struct Sitzungszusammenfassung: Equatable, Sendable, Identifiable {
    public var id: URL { pfad }
    public let pfad: URL
    public let beginn: Date
    public let ende: Date
    /// Vom Gerät gemeldete Trainingszeit.
    public let dauer: TimeInterval
    public let distanzMeter: Double
    public let energieKcal: Double
    public let maxGeschwindigkeit: Double
    public let pakete: Int

    /// Vergangene Uhrzeit zwischen erstem und letztem Paket.
    public var echtzeit: TimeInterval { ende.timeIntervalSince(beginn) }

    public var distanzKilometer: Double { distanzMeter / 1000 }

    /// Schnitt über die gemeldete Trainingszeit, in km/h.
    public var durchschnittsgeschwindigkeit: Double {
        guard dauer > 0 else { return 0 }
        return (distanzMeter / dauer) * 3.6
    }
}

/// Liest die aufgezeichneten Einheiten aus `Documents/sitzungen/`.
///
/// Die Rohdateien bleiben die Wahrheit: alles hier ist abgeleitet und lässt
/// sich jederzeit neu berechnen, auch wenn der Decoder später korrigiert wird.
public enum Sitzungsarchiv {

    /// Fasst eine Datei zusammen. `nil`, wenn sie leer oder unbrauchbar ist.
    public static func fasseZusammen(_ pfad: URL) -> Sitzungszusammenfassung? {
        guard let zeilen = try? SitzungsSpeicher.lies(pfad), let erste = zeilen.first,
              let letzte = zeilen.last else { return nil }

        return Sitzungszusammenfassung(
            pfad: pfad,
            beginn: erste.zeit,
            ende: letzte.zeit,
            dauer: letzte.dauer,
            distanzMeter: letzte.distanzMeter,
            energieKcal: letzte.energieKcal,
            maxGeschwindigkeit: zeilen.compactMap(\.geschwindigkeit).max() ?? 0,
            pakete: zeilen.count
        )
    }

    /// Alle Einheiten, neueste zuerst. Einheiten ohne zurückgelegte Strecke
    /// werden übersprungen — sonst füllt sich die Liste mit Fehlstarts.
    public static func alleZusammenfassungen(in ordner: URL? = nil,
                                             mindestDistanz: Double = 1) -> [Sitzungszusammenfassung] {
        let dateien = (try? SitzungsSpeicher.alleSitzungen(in: ordner)) ?? []
        return dateien
            .compactMap(fasseZusammen)
            .filter { $0.distanzMeter >= mindestDistanz }
            .sorted { $0.beginn > $1.beginn }
    }

    /// Löscht die Rohdatei einer Einheit.
    ///
    /// Damit ist sie endgültig weg — die JSONL-Datei ist die einzige Quelle.
    /// Ein bereits nach Apple Health geschriebenes Workout bleibt davon
    /// unberührt; das lebt in der Health-Datenbank und wird dort gelöscht.
    @discardableResult
    public static func loesche(_ pfad: URL) -> Bool {
        (try? FileManager.default.removeItem(at: pfad)) != nil
    }

    /// Der Geschwindigkeitsverlauf einer Einheit für die Grafik.
    ///
    /// - Parameter hoechstens: obere Grenze der Punktzahl. Eine Stunde erzeugt
    ///   rund 3600 Zeilen; für eine Grafik auf einem 4-Zoll-Display ist das
    ///   sinnlos viel, also wird gleichmäßig ausgedünnt.
    public static func verlauf(_ pfad: URL, hoechstens: Int = 400) -> [Verlaufspunkt] {
        guard let zeilen = try? SitzungsSpeicher.lies(pfad), let erste = zeilen.first else {
            return []
        }
        let punkte = zeilen.map { zeile in
            Verlaufspunkt(sekunde: zeile.zeit.timeIntervalSince(erste.zeit),
                          geschwindigkeit: zeile.geschwindigkeit ?? 0,
                          distanzMeter: zeile.distanzMeter)
        }
        guard punkte.count > hoechstens else { return punkte }

        let schritt = Double(punkte.count) / Double(hoechstens)
        return (0..<hoechstens).map { punkte[Int(Double($0) * schritt)] }
    }
}
