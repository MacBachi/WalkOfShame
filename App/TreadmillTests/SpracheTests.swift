import XCTest
@testable import Treadmill

final class SpracheTests: XCTestCase {

    // MARK: - Auflösung der Systemsprache

    func testDeutschUndSeineRegionen() {
        for code in ["de", "de-DE", "de-AT", "de-CH", "de-LI"] {
            XCTAssertEqual(Sprachverwaltung.loese(.automatisch, systemsprachen: [code]),
                           .deutsch, "\(code) muss Deutsch ergeben")
        }
    }

    /// Deutsche Dialekte haben eigene ISO-Codes und zählen ebenfalls als Deutsch.
    func testDeutscheDialekte() {
        for code in ["gsw-CH", "bar", "nds-DE", "ksh", "swg", "wae", "pfl"] {
            XCTAssertEqual(Sprachverwaltung.loese(.automatisch, systemsprachen: [code]),
                           .deutsch, "\(code) ist ein deutscher Dialekt")
        }
    }

    func testAllesAndereWirdEnglisch() {
        for code in ["en-GB", "en-US", "fr-FR", "it-IT", "nl-NL", "da-DK", "ja-JP"] {
            XCTAssertEqual(Sprachverwaltung.loese(.automatisch, systemsprachen: [code]),
                           .englisch, "\(code) muss Englisch ergeben")
        }
    }

    /// Niederländisch beginnt mit »n«, Dänisch mit »d« — kein Präfixtreffer.
    func testKeineFalschenTrefferDurchPraefixe() {
        XCTAssertEqual(Sprachverwaltung.loese(.automatisch, systemsprachen: ["da-DK"]), .englisch)
        XCTAssertEqual(Sprachverwaltung.loese(.automatisch, systemsprachen: ["dz-BT"]), .englisch)
    }

    func testExpliziteWahlSchlaegtSystemsprache() {
        XCTAssertEqual(Sprachverwaltung.loese(.englisch, systemsprachen: ["de-AT"]), .englisch)
        XCTAssertEqual(Sprachverwaltung.loese(.deutsch, systemsprachen: ["en-GB"]), .deutsch)
    }

    func testNurDieErsteSystemspracheZaehlt() {
        XCTAssertEqual(Sprachverwaltung.loese(.automatisch,
                                              systemsprachen: ["fr-FR", "de-DE"]), .englisch)
    }

    func testOhneSystemspracheEnglisch() {
        XCTAssertEqual(Sprachverwaltung.loese(.automatisch, systemsprachen: []), .englisch)
    }

    // MARK: - Vollständigkeit des Katalogs

    /// Fängt vergessene Übersetzungen ab: kein Feld darf leer sein.
    func testKeineLeerenTexte() {
        for (name, katalog) in [("deutsch", Texte.deutsch), ("englisch", Texte.englisch)] {
            for kind in Mirror(reflecting: katalog).children {
                guard let wert = kind.value as? String else { continue }
                XCTAssertFalse(wert.trimmingCharacters(in: .whitespaces).isEmpty,
                               "\(name): »\(kind.label ?? "?")« ist leer")
            }
        }
    }

    /// Fängt kopierte, aber nicht übersetzte Felder ab. Ausgenommen sind Texte,
    /// die in beiden Sprachen gleich lauten dürfen (Einheiten, Fachbegriffe).
    func testKatalogeSindTatsaechlichUebersetzt() {
        let darfGleichSein: Set<String> = [
            // Eigenname der App — wird nicht übersetzt.
            "titel",
            "geschwindigkeitseinheit", "kilometer", "kilokalorien", "schlaegeProMinute",
            "pause", "status", "handshake", "debug", "flags", "spracheDeutsch",
            "spracheEnglisch", "inHealthGespeichert",
            // In beiden Sprachen tatsächlich dasselbe Wort bzw. dieselbe Abkürzung.
            "maximum", "minutenKurz", "erfolgeZaehler"
        ]
        let deutsch = Dictionary(uniqueKeysWithValues: Mirror(reflecting: Texte.deutsch)
            .children.compactMap { kind -> (String, String)? in
                guard let name = kind.label, let wert = kind.value as? String else { return nil }
                return (name, wert)
            })
        let englisch = Dictionary(uniqueKeysWithValues: Mirror(reflecting: Texte.englisch)
            .children.compactMap { kind -> (String, String)? in
                guard let name = kind.label, let wert = kind.value as? String else { return nil }
                return (name, wert)
            })

        XCTAssertEqual(deutsch.count, englisch.count, "beide Kataloge müssen gleich viele Felder haben")

        for (name, deutscherWert) in deutsch where !darfGleichSein.contains(name) {
            XCTAssertNotEqual(deutscherWert, englisch[name],
                              "»\(name)« ist in beiden Sprachen identisch — nicht übersetzt?")
        }
    }

    // MARK: - Zusammengesetzte Texte

    func testStillstandstext() {
        XCTAssertTrue(Texte.deutsch.stillstandstext(restSekunden: 12 * 60).contains("12"))
        XCTAssertEqual(Texte.deutsch.stillstandstext(restSekunden: 30),
                       Texte.deutsch.bandStehtGleich)
        XCTAssertTrue(Texte.englisch.stillstandstext(restSekunden: 12 * 60).contains("12 min"))
    }

    func testBeendigungstext() {
        XCTAssertEqual(Texte.deutsch.beendigungstext(.vomNutzer), "manuell beendet")
        XCTAssertTrue(Texte.englisch.beendigungstext(.stillstand(dauer: 30 * 60)).contains("30"))
    }

    func testVerbindungstextNutztGeraetenamen() {
        XCTAssertEqual(Texte.deutsch.verbindungstext(.verbunden(name: "LJJ-XXXXXX")), "LJJ-XXXXXX")
        XCTAssertTrue(Texte.englisch.verbindungstext(.suche).contains("treadmill"))
    }

    /// Britisches Englisch, nicht amerikanisches.
    func testBritischeSchreibweise() {
        XCTAssertTrue(Texte.englisch.masssystemFussnote.contains("metres"))
        XCTAssertFalse(Texte.englisch.masssystemFussnote.lowercased().contains("meters"))
        XCTAssertTrue(Texte.englisch.masssystemFussnote.contains("kilogrammes"))
        XCTAssertTrue(Texte.englisch.healthFussnoteGesperrt.contains("whilst"))
    }
}
