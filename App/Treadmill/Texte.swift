import Foundation
import FTMSKit
import FTMSTransport

/// Alle sichtbaren Texte der App in beiden Sprachen.
///
/// Englisch ist durchgehend **britisch** (»metres«, »recognise«, »whilst«).
struct Texte: Equatable {

    // Hauptbildschirm
    let titel: String
    let steuerung: String
    let einstellungen: String
    let geschwindigkeitseinheit: String
    let distanz: String
    let zeit: String
    let kalorien: String
    let puls: String
    let kilometer: String
    let kilokalorien: String
    let schlaegeProMinute: String

    // Trainingszustand
    let wartetAufBandstart: String
    let bereit: String
    let trainingLaeuft: String
    let pausiert: String

    // Knöpfe
    let jetztStarten: String
    let pause: String
    let beenden: String
    let weiter: String
    let verwerfen: String
    let abbrechen: String
    let einheitVerwerfenFrage: String
    let einheitVerwerfenHinweis: String

    // Verbindung
    let bluetoothAus: String
    let keineBerechtigung: String
    let suche: String
    let verbindeMit: String
    let getrennt: String

    // Einstellungen
    let nachHealthSchreiben: String
    let healthFussnoteAktiv: String
    let healthFussnoteGesperrt: String
    let automatischStarten: String
    let automatischStartenFussnote: String
    let debugModus: String
    let rohdatenAnsehen: String
    let debugFussnoteAn: String
    let debugFussnoteAus: String
    let geraet: String
    let verbindung: String
    let geschwindigkeit: String
    let trainingStatus: String
    let laufbandWaehlen: String
    let automatischesGeraet: String
    let geraeteFussnote: String
    let keineGeraeteGefunden: String
    let spracheTitel: String
    let spracheAutomatisch: String
    let spracheDeutsch: String
    let spracheEnglisch: String
    let spracheFussnote: String

    // Maßsystem-Schalter
    let masssystem: String
    let imperialeEinheitenAktivieren: String
    let masssystemFussnote: String
    let scherzTitel: String
    let scherzText: String
    let scherzTippen: String

    // Steuerung
    let handshake: String
    let status: String
    let steuerungAnfordern: String
    let handshakeFussnote: String
    let grenzenFehlen: String
    let geraetErlaubt: String
    let geschwindigkeitSenden: String
    let notStop: String
    let notStopFussnote: String
    let bestaetigungFrage: String
    let bestaetigungHinweis: String
    let sicherenStand: String

    // Verlauf und Statistik
    let verlauf: String
    let statistik: String
    let keineEinheiten: String
    let einheitenLabel: String
    let dauerLabel: String
    let schnitt: String
    let maximum: String
    let laengsteEinheit: String
    let zeitraumHeute: String
    let zeitraumSieben: String
    let zeitraumVierWochen: String
    let zeitraumJahr: String
    let zeitraumGesamt: String
    let erfolge: String
    let naechsterErfolg: String
    let nochOffen: String
    let alleErfolgeErreicht: String
    let erfolgeZaehler: String
    let verlaufsgrafik: String
    let minutenKurz: String
    let loeschen: String
    let loeschHinweis: String

    // Debug
    let debug: String
    let meldet: String
    let steuerbar: String
    let letztesPaket: String
    let flags: String
    let rohbytes: String
    let uebrigeBytes: String
    let nichtVerfuegbar: String
    let rohprotokoll: String
    let logTeilen: String

    // Meldungen
    let inHealthGespeichert: String
    let nichtNachHealth: String
    let verworfen: String
    let manuellBeendet: String
    let automatischBeendet: String
    let bandSteht: String
    let bandStehtGleich: String
    let startFehlgeschlagen: String
    let healthFehlgeschlagen: String
    let nichtVerbundenBefehl: String
    let paketNichtDekodierbar: String
    let geraetLehnteAb: String

    // MARK: - Deutsch

    static let deutsch = Texte(
        titel: "Walk of Shame",
        steuerung: "Steuerung",
        einstellungen: "Einstellungen",
        geschwindigkeitseinheit: "km/h",
        distanz: "Distanz",
        zeit: "Zeit",
        kalorien: "Kalorien",
        puls: "Puls",
        kilometer: "km",
        kilokalorien: "kcal",
        schlaegeProMinute: "bpm",
        wartetAufBandstart: "Wartet auf Bandstart",
        bereit: "Bereit",
        trainingLaeuft: "Training läuft",
        pausiert: "Pausiert",
        jetztStarten: "Jetzt starten",
        pause: "Pause",
        beenden: "Beenden",
        weiter: "Weiter",
        verwerfen: "Verwerfen",
        abbrechen: "Abbrechen",
        einheitVerwerfenFrage: "Einheit verwerfen?",
        einheitVerwerfenHinweis: "Die Einheit wird nicht nach Apple Health geschrieben. "
            + "Das Rohprotokoll bleibt auf dem Gerät erhalten.",
        bluetoothAus: "Bluetooth ist aus",
        keineBerechtigung: "Keine Bluetooth-Berechtigung",
        suche: "Suche Laufband …",
        verbindeMit: "Verbinde mit",
        getrennt: "Getrennt",
        nachHealthSchreiben: "Nach Apple Health schreiben",
        healthFussnoteAktiv: "Schreibt Distanz, Kalorien und Herzfrequenz als Workout. "
            + "Die App liest keine Gesundheitsdaten.",
        healthFussnoteGesperrt: "Während einer laufenden Einheit nicht änderbar.",
        automatischStarten: "Automatisch starten",
        automatischStartenFussnote: "Startet die Einheit, sobald sich das Band bewegt. "
            + "Ist das aus, wird von Hand gestartet.",
        debugModus: "Debug-Modus",
        rohdatenAnsehen: "Rohdaten ansehen",
        debugFussnoteAn: "Jede Notification wird als Hex mitgeschrieben.",
        debugFussnoteAus: "Nur auffällige Pakete werden protokolliert: Dekodierfehler, "
            + "unerwartete Bytes, Control-Point-Verkehr.",
        geraet: "Gerät",
        verbindung: "Verbindung",
        geschwindigkeit: "Geschwindigkeit",
        trainingStatus: "Training Status",
        laufbandWaehlen: "Laufband",
        automatischesGeraet: "Erstes gefundenes",
        geraeteFussnote: "Ist ein Gerät festgelegt, verbindet sich die App nur damit. "
            + "Die Liste aktualisiert sich, solange diese Seite offen ist.",
        keineGeraeteGefunden: "Suche läuft — noch kein Laufband in Reichweite.",
        spracheTitel: "Sprache",
        spracheAutomatisch: "Automatisch",
        spracheDeutsch: "Deutsch",
        spracheEnglisch: "English",
        spracheFussnote: "»Automatisch« wählt Deutsch, wenn die Systemsprache Deutsch "
            + "oder ein deutscher Dialekt ist — sonst britisches Englisch.",
        masssystem: "Maßsystem",
        imperialeEinheitenAktivieren: "Imperiale Einheiten aktivieren",
        masssystemFussnote: "Aktuelle Einstellung: Meter, Kilometer, Kilogramm. "
            + "Du kannst versuchen, auf imperiale Einheiten umzuschalten, um in "
            + "Körperteilen und ähnlich lustigen Konstrukten zu messen.",
        scherzTitel: "Sicherheitsabschaltung",
        scherzText: "Du hast soeben versucht, auf imperiale Einheiten umzuschalten.\n\n"
            + "Diese App kann eine Person, die in Fuß, Zoll und Steinen rechnet, beim "
            + "besten Willen nicht länger als seriös betrachten. Sie beendet sich daher "
            + "vorsorglich, bis du wieder zu Sinnen gekommen bist.\n\n"
            + "Zur Nachbereitung wird eine Liste humoristischer Maßeinheiten geöffnet. "
            + "Dort lässt sich in Ruhe nachlesen, wohin das führt.",
        scherzTippen: "Tippen zum Beenden",
        handshake: "Handshake",
        status: "Status",
        steuerungAnfordern: "Steuerung anfordern",
        handshakeFussnote: "Laut FTMS zuerst »Request Control« (0x00), danach »Reset« "
            + "(0x01). Ohne diesen Handshake lehnt das Gerät jeden Befehl ab.",
        grenzenFehlen: "Grenzen noch nicht gelesen — ohne sie wird kein Befehl gesendet.",
        geraetErlaubt: "Gerät erlaubt",
        geschwindigkeitSenden: "Geschwindigkeit senden",
        notStop: "NOT-STOP",
        notStopFussnote: "Sendet sofort »Stop« (0x08 0x01) — ohne Rückfrage und ohne "
            + "Bereichsprüfung.",
        bestaetigungFrage: "Band auf %@ km/h stellen?",
        bestaetigungHinweis: "Das Band ändert daraufhin sofort seine Geschwindigkeit.",
        sicherenStand: "Sicheren Stand einnehmen.",
        verlauf: "Verlauf",
        statistik: "Statistik",
        keineEinheiten: "Noch keine Einheit aufgezeichnet. Stell dich aufs Band.",
        einheitenLabel: "Einheiten",
        dauerLabel: "Dauer",
        schnitt: "Schnitt",
        maximum: "Maximum",
        laengsteEinheit: "Längste Einheit",
        zeitraumHeute: "Heute",
        zeitraumSieben: "7 Tage",
        zeitraumVierWochen: "4 Wochen",
        zeitraumJahr: "365 Tage",
        zeitraumGesamt: "Gesamt",
        erfolge: "Erfolge",
        naechsterErfolg: "Nächster Erfolg",
        nochOffen: "noch %@ km",
        alleErfolgeErreicht: "Alle Erfolge erreicht. Ernsthaft: alle.",
        erfolgeZaehler: "%d von %d",
        verlaufsgrafik: "Geschwindigkeit über die Zeit",
        minutenKurz: "min",
        loeschen: "Löschen",
        loeschHinweis: "Nach links wischen zum Löschen. Eine gelöschte Einheit ist endgültig "
            + "weg — in Apple Health bleibt sie aber stehen und muss dort separat gelöscht werden.",
        debug: "Debug",
        meldet: "Meldet",
        steuerbar: "Steuerbar",
        letztesPaket: "Letztes Paket",
        flags: "Flags",
        rohbytes: "Rohbytes",
        uebrigeBytes: "Übrige Bytes",
        nichtVerfuegbar: "Nicht verfügbar",
        rohprotokoll: "Rohprotokoll",
        logTeilen: "Log teilen",
        inHealthGespeichert: "In Health: %@ km, %@ (%@)",
        nichtNachHealth: "Einheit %@ — nicht nach Health geschrieben.",
        verworfen: "Einheit verworfen — nichts nach Health geschrieben.",
        manuellBeendet: "manuell beendet",
        automatischBeendet: "automatisch beendet nach %d min Stillstand",
        bandSteht: "Band steht — endet automatisch in %d min",
        bandStehtGleich: "Band steht — endet gleich automatisch",
        startFehlgeschlagen: "Start fehlgeschlagen: %@",
        healthFehlgeschlagen: "Health-Schreiben fehlgeschlagen: %@",
        nichtVerbundenBefehl: "Nicht verbunden — Befehl nicht gesendet.",
        paketNichtDekodierbar: "Paket nicht dekodierbar: %@",
        geraetLehnteAb: "Gerät lehnte Befehl ab: %@"
    )

    // MARK: - Englisch (britisch)

    static let englisch = Texte(
        titel: "Walk of Shame",
        steuerung: "Control",
        einstellungen: "Settings",
        geschwindigkeitseinheit: "km/h",
        distanz: "Distance",
        zeit: "Time",
        kalorien: "Calories",
        puls: "Pulse",
        kilometer: "km",
        kilokalorien: "kcal",
        schlaegeProMinute: "bpm",
        wartetAufBandstart: "Waiting for the belt",
        bereit: "Ready",
        trainingLaeuft: "Workout running",
        pausiert: "Paused",
        jetztStarten: "Start now",
        pause: "Pause",
        beenden: "Finish",
        weiter: "Resume",
        verwerfen: "Discard",
        abbrechen: "Cancel",
        einheitVerwerfenFrage: "Discard this workout?",
        einheitVerwerfenHinweis: "The workout will not be written to Apple Health. "
            + "The raw log stays on the device.",
        bluetoothAus: "Bluetooth is off",
        keineBerechtigung: "No Bluetooth permission",
        suche: "Looking for the treadmill …",
        verbindeMit: "Connecting to",
        getrennt: "Disconnected",
        nachHealthSchreiben: "Write to Apple Health",
        healthFussnoteAktiv: "Writes distance, calories and heart rate as a workout. "
            + "The app never reads health data.",
        healthFussnoteGesperrt: "Cannot be changed whilst a workout is running.",
        automatischStarten: "Start automatically",
        automatischStartenFussnote: "Starts the workout as soon as the belt moves. "
            + "With this off, you start it by hand.",
        debugModus: "Debug mode",
        rohdatenAnsehen: "Inspect raw data",
        debugFussnoteAn: "Every notification is logged as hex.",
        debugFussnoteAus: "Only unusual packets are logged: decoding errors, "
            + "unexpected bytes, control point traffic.",
        geraet: "Device",
        verbindung: "Connection",
        geschwindigkeit: "Speed",
        trainingStatus: "Training status",
        laufbandWaehlen: "Treadmill",
        automatischesGeraet: "First one found",
        geraeteFussnote: "With a device pinned, the app connects to that one only. "
            + "The list keeps refreshing whilst this page is open.",
        keineGeraeteGefunden: "Scanning — no treadmill in range yet.",
        spracheTitel: "Language",
        spracheAutomatisch: "Automatic",
        spracheDeutsch: "Deutsch",
        spracheEnglisch: "English",
        spracheFussnote: "“Automatic” picks German when the system language is German "
            + "or a German dialect — otherwise British English.",
        masssystem: "Units",
        imperialeEinheitenAktivieren: "Enable imperial units",
        masssystemFussnote: "Current setting: metres, kilometres, kilogrammes. "
            + "You are welcome to try switching to imperial units, in order to "
            + "measure in body parts and similarly amusing constructs.",
        scherzTitel: "Safety shutdown",
        scherzText: "You have just attempted to switch to imperial units.\n\n"
            + "This app cannot, in all conscience, continue to regard a person who "
            + "reckons in feet, inches and stones as a serious individual. It is "
            + "therefore shutting itself down as a precaution until you have come to "
            + "your senses.\n\n"
            + "For your further education, a list of humorous units of measurement "
            + "will now be opened. It shows rather plainly where this road leads.",
        scherzTippen: "Tap to quit",
        handshake: "Handshake",
        status: "Status",
        steuerungAnfordern: "Request control",
        handshakeFussnote: "FTMS requires “Request Control” (0x00) first, then “Reset” "
            + "(0x01). Without this handshake the device rejects every command.",
        grenzenFehlen: "Limits not read yet — no command is sent without them.",
        geraetErlaubt: "Device allows",
        geschwindigkeitSenden: "Send speed",
        notStop: "EMERGENCY STOP",
        notStopFussnote: "Sends “Stop” (0x08 0x01) immediately — no confirmation, "
            + "no range check.",
        bestaetigungFrage: "Set the belt to %@ km/h?",
        bestaetigungHinweis: "The belt will change speed straight away.",
        sicherenStand: "Make sure you are standing safely.",
        verlauf: "History",
        statistik: "Statistics",
        keineEinheiten: "No workout recorded yet. Go and stand on the belt.",
        einheitenLabel: "Workouts",
        dauerLabel: "Duration",
        schnitt: "Average",
        maximum: "Maximum",
        laengsteEinheit: "Longest workout",
        zeitraumHeute: "Today",
        zeitraumSieben: "7 days",
        zeitraumVierWochen: "4 weeks",
        zeitraumJahr: "365 days",
        zeitraumGesamt: "All time",
        erfolge: "Achievements",
        naechsterErfolg: "Next achievement",
        nochOffen: "%@ km to go",
        alleErfolgeErreicht: "Every achievement unlocked. Genuinely, all of them.",
        erfolgeZaehler: "%d of %d",
        verlaufsgrafik: "Speed over time",
        minutenKurz: "min",
        loeschen: "Delete",
        loeschHinweis: "Swipe left to delete. A deleted workout is gone for good — but it "
            + "stays in Apple Health and has to be removed there separately.",
        debug: "Debug",
        meldet: "Reports",
        steuerbar: "Controllable",
        letztesPaket: "Last packet",
        flags: "Flags",
        rohbytes: "Raw bytes",
        uebrigeBytes: "Leftover bytes",
        nichtVerfuegbar: "Not available",
        rohprotokoll: "Raw log",
        logTeilen: "Share log",
        inHealthGespeichert: "In Health: %@ km, %@ (%@)",
        nichtNachHealth: "Workout %@ — not written to Health.",
        verworfen: "Workout discarded — nothing written to Health.",
        manuellBeendet: "finished by hand",
        automatischBeendet: "finished automatically after %d min of standstill",
        bandSteht: "Belt idle — finishes automatically in %d min",
        bandStehtGleich: "Belt idle — finishing automatically",
        startFehlgeschlagen: "Could not start: %@",
        healthFehlgeschlagen: "Writing to Health failed: %@",
        nichtVerbundenBefehl: "Not connected — command not sent.",
        paketNichtDekodierbar: "Packet could not be decoded: %@",
        geraetLehnteAb: "Device rejected the command: %@"
    )

    // MARK: - Zahlen und Datum

    /// Bestimmt Dezimaltrennzeichen und Datumsformat. Ohne das zeigt die
    /// deutsche Oberfläche »10.50 km« und »18. Aug at 09:30«.
    var gebietsschema: Locale {
        self == Texte.deutsch ? Locale(identifier: "de_AT") : Locale(identifier: "en_GB")
    }

    /// Zahl mit dem Trennzeichen der jeweiligen Sprache.
    func zahl(_ wert: Double, _ stellen: Int = 1) -> String {
        String(format: "%.\(stellen)f", locale: gebietsschema, wert)
    }

    // MARK: - Zusammengesetzte Texte

    func verbindungstext(_ status: Verbindungsstatus) -> String {
        switch status {
        case .bluetoothAus: return bluetoothAus
        case .keineBerechtigung: return keineBerechtigung
        case .bereit: return bereit
        case .suche: return suche
        case .verbinde(let name): return "\(verbindeMit) \(name) …"
        case .verbunden(let name): return name
        case .getrennt(let grund): return "\(getrennt): \(grund)"
        }
    }

    func beendigungstext(_ grund: Beendigungsgrund) -> String {
        switch grund {
        case .vomNutzer:
            return manuellBeendet
        case .stillstand(let dauer):
            return String(format: automatischBeendet, Int(dauer / 60))
        }
    }

    func zeitraumName(_ zeitraum: Zeitraum) -> String {
        switch zeitraum {
        case .heute: return zeitraumHeute
        case .siebenTage: return zeitraumSieben
        case .vierWochen: return zeitraumVierWochen
        case .jahr: return zeitraumJahr
        case .gesamt: return zeitraumGesamt
        }
    }

    func stillstandstext(restSekunden: TimeInterval) -> String {
        let minuten = Int(restSekunden / 60)
        return minuten > 0 ? String(format: bandSteht, minuten) : bandStehtGleich
    }
}
