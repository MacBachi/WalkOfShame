import Foundation
import FTMSKit

/// Wertet eine Regie-Aufnahme aus: pro Phase die dekodierte Geschwindigkeit
/// gegen die angesagte Display-Geschwindigkeit.
///
/// `swift run ftms-dump --auswerten dumps/ftms-….jsonl`
enum Auswertung {

    struct Zeile: Decodable {
        let art: String
        let zeit: Date
        let hex: String?
        let dekodiert: [String: String]?
    }

    static func fuehreAus(pfad: String) {
        let dekodierer = JSONDecoder()
        dekodierer.dateDecodingStrategy = .iso8601

        guard let inhalt = try? String(contentsOfFile: pfad, encoding: .utf8) else {
            print("Datei nicht lesbar: \(pfad)")
            return
        }

        let zeilen = inhalt.split(separator: "\n").compactMap {
            try? dekodierer.decode(Zeile.self, from: Data($0.utf8))
        }

        // Pakete nach Phase gruppieren.
        var proPhase: [String: (erwartet: Double?, werte: [Double], distanz: [UInt32])] = [:]
        var reihenfolge: [String] = []

        for zeile in zeilen where zeile.art == "2acd" {
            guard let hex = zeile.hex,
                  let daten = try? TreadmillDataDecoder.dekodiere(hex: hex) else { continue }
            let phase = zeile.dekodiert?["phase"] ?? "-"
            let erwartet = zeile.dekodiert?["erwartet"].flatMap(Double.init)

            if proPhase[phase] == nil {
                proPhase[phase] = (erwartet, [], [])
                reihenfolge.append(phase)
            }
            if let kmh = daten.momentanGeschwindigkeit {
                proPhase[phase]?.werte.append(kmh)
            }
            if let meter = daten.gesamtDistanz {
                proPhase[phase]?.distanz.append(meter)
            }
        }

        print("Phase          Pakete  gemessen ⌀   Display   Abweichung   Distanz")
        print(String(repeating: "─", count: 70))

        for phase in reihenfolge {
            guard let eintrag = proPhase[phase] else { continue }
            let schnitt = eintrag.werte.isEmpty
                ? 0 : eintrag.werte.reduce(0, +) / Double(eintrag.werte.count)
            let distanzText = eintrag.distanz.isEmpty
                ? "—"
                : "\(eintrag.distanz.first ?? 0)→\(eintrag.distanz.last ?? 0) m"

            var zeile = phase.padding(toLength: 15, withPad: " ", startingAt: 0)
            zeile += String(format: "%5d", eintrag.werte.count) + "   "
            zeile += String(format: "%7.2f", schnitt) + " km/h  "

            if let erwartet = eintrag.erwartet {
                let abweichung = schnitt - erwartet
                zeile += String(format: "%5.1f", erwartet) + "     "
                zeile += String(format: "%+6.2f", abweichung)
                zeile += abs(abweichung) <= 0.1 ? " ✓" : " ✗"
            } else {
                zeile += "    —          —  "
            }
            zeile += "   " + distanzText
            print(zeile)
        }

        // Der entscheidende Punkt für die Autostart-Logik.
        if let leerlauf = proPhase["leerlauf"], !leerlauf.werte.isEmpty {
            let min = leerlauf.werte.min() ?? 0
            let max = leerlauf.werte.max() ?? 0
            print("")
            print(String(format: "Im Stillstand meldet das Band %.2f–%.2f km/h.", min, max))
            print(max == 0
                ? "→ 0,00 im Stillstand: Autostart darf zusätzlich auf Geschwindigkeit hören."
                : "→ nicht 0: Autostart muss bei der Distanzregel bleiben.")
        }

        if let stillstand = proPhase["stillstand"], let neustart = proPhase["neustart"],
           let vorher = stillstand.distanz.last, let nachher = neustart.distanz.first {
            print("")
            print("Distanz vor dem Neustart: \(vorher) m, danach: \(nachher) m")
            print(nachher < vorher
                ? "→ Das Band setzt seine Zähler zurück. Der Sitzungsaggregator fängt das ab."
                : "→ Das Band zählt über den Neustart hinweg weiter.")
        }
    }
}
