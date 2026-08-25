import XCTest
@testable import FTMSKit

final class ControlPointTests: XCTestCase {

    // MARK: - Kodierung (FTMS v1.0, Tabellen 4.15/4.16)

    func testHandshakeBefehle() {
        XCTAssertEqual(Steuerbefehl.kontrolleAnfordern.nutzlast().hexString, "00")
        XCTAssertEqual(Steuerbefehl.zuruecksetzen.nutzlast().hexString, "01")
        XCTAssertEqual(Steuerbefehl.startOderFortsetzen.nutzlast().hexString, "07")
    }

    /// Stop und Pause teilen sich Op Code 0x08 und unterscheiden sich nur im
    /// Parameter — eine Verwechslung hieße »Pause statt Not-Stop«.
    func testStoppUndPauseUnterscheidenSichNurImParameter() {
        XCTAssertEqual(Steuerbefehl.stopp.nutzlast().hexString, "0801")
        XCTAssertEqual(Steuerbefehl.pause.nutzlast().hexString, "0802")
        XCTAssertEqual(Steuerbefehl.notStop, .stopp)
    }

    func testZielGeschwindigkeit() {
        // 5,0 km/h → 500 = 0x01F4, little endian
        XCTAssertEqual(Steuerbefehl.zielGeschwindigkeit(kmH: 5.0).nutzlast().hexString, "02f401")
        XCTAssertEqual(Steuerbefehl.zielGeschwindigkeit(kmH: 1.0).nutzlast().hexString, "026400")
        XCTAssertEqual(Steuerbefehl.zielGeschwindigkeit(kmH: 6.0).nutzlast().hexString, "025802")
    }

    func testNegativeZielNeigung() {
        // -2,5 % → -25 = 0xFFE7
        XCTAssertEqual(Steuerbefehl.zielNeigung(prozent: -2.5).nutzlast().hexString, "03e7ff")
        XCTAssertEqual(Steuerbefehl.zielNeigung(prozent: 1.5).nutzlast().hexString, "030f00")
    }

    // MARK: - Antworten

    func testErfolgreicheAntwort() throws {
        let antwort = try XCTUnwrap(Steuerantwort(daten: Data(hex: "800001")))

        XCTAssertEqual(antwort.angefragterOpCode, 0x00)
        XCTAssertTrue(antwort.erfolgreich)
        XCTAssertEqual(antwort.text, "Success")
    }

    func testKontrolleVerweigert() throws {
        let antwort = try XCTUnwrap(Steuerantwort(daten: Data(hex: "800205")))

        XCTAssertFalse(antwort.erfolgreich)
        XCTAssertEqual(antwort.text, "Control Not Permitted")
    }

    func testFremdeNutzlastIstKeineAntwort() {
        XCTAssertNil(Steuerantwort(daten: Data(hex: "000001")), "muss mit 0x80 beginnen")
        XCTAssertNil(Steuerantwort(daten: Data(hex: "8000")), "zu kurz")
    }

    // MARK: - Sicherheitsgrenzen (Werte des echten Geräts)

    private var grenzenDesGeraets: Steuerungsgrenzen {
        Steuerungsgrenzen(
            geschwindigkeit: UnterstuetzteGeschwindigkeit(daten: Data(hex: "640058020a00")),
            neigung: UnterstuetzteNeigung(daten: Data(hex: "000000000a00")),
            merkmale: FitnessMachineFeature(daten: Data(hex: "0416000001000000"))
        )
    }

    func testGueltigeGeschwindigkeitWirdDurchgelassen() throws {
        try grenzenDesGeraets.pruefe(.zielGeschwindigkeit(kmH: 5.0))
    }

    func testZuSchnellWirdAbgelehnt() {
        XCTAssertThrowsError(try grenzenDesGeraets.pruefe(.zielGeschwindigkeit(kmH: 12.0))) { fehler in
            XCTAssertEqual(fehler as? Steuerungsgrenzen.Ablehnung,
                           .ausserhalbBereich(wert: 12.0, minimum: 1.0, maximum: 6.0))
        }
    }

    func testZuLangsamWirdAbgelehnt() {
        XCTAssertThrowsError(try grenzenDesGeraets.pruefe(.zielGeschwindigkeit(kmH: 0.5)))
    }

    /// Das Gerät hat keine Neigung — der Befehl darf gar nicht erst rausgehen.
    func testNeigungWirdAbgelehnt() {
        XCTAssertThrowsError(try grenzenDesGeraets.pruefe(.zielNeigung(prozent: 2.0))) { fehler in
            XCTAssertEqual(fehler as? Steuerungsgrenzen.Ablehnung,
                           .nichtUnterstuetzt("Neigungssteuerung"))
        }
    }

    /// Ohne gelesene Grenzen wird kein Speed-Befehl gesendet — lieber gar nichts
    /// als ein ungeprüfter Wert an ein Gerät, auf dem jemand steht.
    func testOhneGrenzenKeinSpeedBefehl() {
        let ohneGrenzen = Steuerungsgrenzen(geschwindigkeit: nil, neigung: nil, merkmale: nil)

        XCTAssertThrowsError(try ohneGrenzen.pruefe(.zielGeschwindigkeit(kmH: 3.0))) { fehler in
            XCTAssertEqual(fehler as? Steuerungsgrenzen.Ablehnung,
                           .grenzenUnbekannt("Geschwindigkeit"))
        }
    }

    /// Der Not-Stop darf unter keinen Umständen an einer Prüfung scheitern.
    func testNotStoppIstImmerErlaubt() throws {
        let ohneGrenzen = Steuerungsgrenzen(geschwindigkeit: nil, neigung: nil, merkmale: nil)

        try ohneGrenzen.pruefe(.notStop)
        try ohneGrenzen.pruefe(.pause)
        try ohneGrenzen.pruefe(.zuruecksetzen)
        try grenzenDesGeraets.pruefe(.notStop)
    }
}
