import Foundation

/// Eine Ansage während der Kalibrierungsaufnahme.
struct Regieanweisung {
    /// Sekunden nach Aufnahmebeginn.
    let beiSekunde: TimeInterval
    /// Kurzname der Phase, landet im Protokoll.
    let phase: String
    /// Was gesprochen und geloggt wird.
    let ansage: String
    /// Erwartete Display-Geschwindigkeit in km/h, falls die Phase eine setzt.
    let erwarteteGeschwindigkeit: Double?

    init(_ beiSekunde: TimeInterval, _ phase: String, _ ansage: String,
         erwartet: Double? = nil) {
        self.beiSekunde = beiSekunde
        self.phase = phase
        self.ansage = ansage
        self.erwarteteGeschwindigkeit = erwartet
    }
}

/// Der Kalibrierungsablauf.
///
/// Deckt in einem Durchgang alle offenen Fragen ab:
/// - Was meldet das Band im **Stillstand**? (entscheidet, ob der Autostart
///   zusätzlich auf Geschwindigkeit hören darf)
/// - Stimmt der Faktor 0,01 km/h über den ganzen Bereich? (1 → 3 → 5 → 6 km/h)
/// - Stimmt die Distanz in Metern? (Abgleich mit dem Display am Ende)
/// - **Setzt das Band seine Zähler zurück**, wenn man neu startet?
enum Kalibrierung {
    static let ablauf: [Regieanweisung] = [
        Regieanweisung(0, "leerlauf",
            "Aufnahme läuft. Das Band bitte eingeschaltet lassen, aber noch nicht starten. "
            + "Bitte auch nicht drauf steigen."),
        Regieanweisung(60, "start-1",
            "Bitte jetzt auf das Band steigen und mit 1,0 Kilometern pro Stunde starten.",
            erwartet: 1.0),
        Regieanweisung(180, "tempo-3",
            "Bitte auf 3,0 Kilometer pro Stunde erhöhen.", erwartet: 3.0),
        Regieanweisung(300, "tempo-5",
            "Bitte auf 5,0 Kilometer pro Stunde erhöhen. Das ist die wichtigste Phase, "
            + "bitte 3 Minuten so lassen.", erwartet: 5.0),
        Regieanweisung(480, "tempo-6",
            "Bitte auf 6,0 Kilometer pro Stunde erhöhen.", erwartet: 6.0),
        Regieanweisung(540, "stillstand",
            "Bitte das Band stoppen, aber stehen bleiben und es eingeschaltet lassen."),
        Regieanweisung(660, "neustart",
            "Bitte das Band neu starten, mit 3,0 Kilometern pro Stunde.", erwartet: 3.0),
        Regieanweisung(750, "ende-stopp",
            "Bitte das Band stoppen. Gleich ist die Aufnahme fertig."),
        Regieanweisung(810, "fertig",
            "Aufnahme beendet. Bitte lies jetzt Distanz, Zeit und Kalorien vom Display ab "
            + "und sag sie Claude.")
    ]

    static var gesamtdauer: TimeInterval {
        (ablauf.last?.beiSekunde ?? 0) + 15
    }
}

/// Spricht Ansagen über die macOS-Sprachausgabe.
///
/// Der Mac steht ohnehin in Funkreichweite des Bands — damit braucht es beim
/// Kalibrieren weder Blick auf den Bildschirm noch eine zweite Person.
enum Ansager {
    static func sprich(_ text: String) {
        let prozess = Process()
        prozess.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        prozess.arguments = ["-v", "Anna", text]
        try? prozess.run()
    }
}
