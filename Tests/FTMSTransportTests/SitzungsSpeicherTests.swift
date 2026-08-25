import XCTest
@testable import FTMSTransport

final class SitzungsSpeicherTests: XCTestCase {

    private var ordner: URL!

    override func setUpWithError() throws {
        ordner = FileManager.default.temporaryDirectory
            .appendingPathComponent("sitzungstest-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: ordner)
    }

    private func zeile(_ sekunde: Int, meter: Double) -> SitzungsZeile {
        SitzungsZeile(
            zeit: Date(timeIntervalSince1970: 1_000_000 + Double(sekunde)),
            hex: "840564001400000000000000004c00",
            distanzMeter: meter, energieKcal: 1, dauer: Double(sekunde),
            geschwindigkeit: 5.0, herzfrequenz: nil
        )
    }

    func testSchreibenUndLesen() throws {
        let speicher = try SitzungsSpeicher(ordner: ordner, name: "test.jsonl")
        speicher.schreibe(zeile(1, meter: 10))
        speicher.schreibe(zeile(2, meter: 20))
        speicher.schliesse()

        let gelesen = try SitzungsSpeicher.lies(speicher.pfad)

        XCTAssertEqual(gelesen.count, 2)
        XCTAssertEqual(gelesen[1].distanzMeter, 20)
        XCTAssertEqual(gelesen[0].hex, "840564001400000000000000004c00")
    }

    /// Der Punkt der ganzen Übung: nach einem Kill mitten im Schreiben muss
    /// alles bis zur letzten vollständigen Zeile erhalten sein.
    func testAbgeschnitteneDateiVerliertNurDieLetzteZeile() throws {
        let speicher = try SitzungsSpeicher(ordner: ordner, name: "kill.jsonl")
        for sekunde in 1...5 { speicher.schreibe(zeile(sekunde, meter: Double(sekunde * 10))) }
        speicher.schliesse()

        // Kill simulieren: Datei mitten in der letzten Zeile abschneiden.
        let roh = try Data(contentsOf: speicher.pfad)
        try roh.prefix(roh.count - 30).write(to: speicher.pfad)

        let gelesen = try SitzungsSpeicher.lies(speicher.pfad)

        XCTAssertEqual(gelesen.count, 4, "vier vollständige Zeilen überleben")
        XCTAssertEqual(gelesen.last?.distanzMeter, 40)
    }

    /// Nach einem Neustart muss an dieselbe Datei angehängt werden können.
    func testAnhaengenAnBestehendeDatei() throws {
        let erste = try SitzungsSpeicher(ordner: ordner, name: "fortsetzung.jsonl")
        erste.schreibe(zeile(1, meter: 10))
        erste.schliesse()

        let zweite = try SitzungsSpeicher(ordner: ordner, name: "fortsetzung.jsonl")
        zweite.schreibe(zeile(2, meter: 20))
        zweite.schliesse()

        XCTAssertEqual(try SitzungsSpeicher.lies(zweite.pfad).count, 2)
    }

    func testSitzungenWerdenNeuesteZuerstGelistet() throws {
        let alt = try SitzungsSpeicher(ordner: ordner, name: "alt.jsonl")
        alt.schreibe(zeile(1, meter: 10))
        alt.schliesse()
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1000)], ofItemAtPath: alt.pfad.path
        )

        let neu = try SitzungsSpeicher(ordner: ordner, name: "neu.jsonl")
        neu.schreibe(zeile(1, meter: 10))
        neu.schliesse()

        let sitzungen = try SitzungsSpeicher.alleSitzungen(in: ordner)

        XCTAssertEqual(sitzungen.first?.lastPathComponent, "neu.jsonl")
        XCTAssertEqual(sitzungen.count, 2)
    }

    func testRohLogRingpuffer() {
        var log = RohLog(maximum: 3)
        for byte in UInt8(1)...5 {
            log.haenge(Data([byte]), quelle: "2ACD")
        }

        XCTAssertEqual(log.eintraege.count, 3)
        XCTAssertEqual(log.eintraege.map(\.hex), ["03", "04", "05"])
        XCTAssertTrue(log.alsText.contains("2ACD"))
    }

    func testRohLogHaeltFehlerFest() {
        var log = RohLog()
        log.haenge(Data([0x00]), quelle: "2ACD", fehler: "Flags unvollständig")

        XCTAssertEqual(log.eintraege.first?.fehler, "Flags unvollständig")
        XCTAssertTrue(log.alsText.contains("FEHLER"))
    }

    // MARK: - Protokollmodus

    func testModusAllesNimmtJedesPaket() {
        var log = RohLog(modus: .alles)

        XCTAssertTrue(log.haenge(Data([0x01]), quelle: "2ACD"))
        XCTAssertTrue(log.haenge(Data([0x02]), quelle: "2ACD"))
        XCTAssertEqual(log.eintraege.count, 2)
    }

    /// Debug aus heißt: normale Pakete fallen weg, Auffälligkeiten nicht.
    func testModusNurAuffaellige() {
        var log = RohLog(modus: .nurAuffaellige)

        XCTAssertFalse(log.haenge(Data([0x01]), quelle: "2ACD"),
                       "unauffälliges Paket wird verworfen")
        XCTAssertTrue(log.haenge(Data([0x02]), quelle: "2ACD", auffaellig: true),
                      "Restbytes/Sentinels kommen immer rein")
        XCTAssertTrue(log.haenge(Data([0x03]), quelle: "2ACD", fehler: "kaputt"),
                      "ein Dekodierfehler ist immer auffällig")

        XCTAssertEqual(log.eintraege.map(\.hex), ["02", "03"])
        XCTAssertTrue(log.eintraege.allSatisfy(\.auffaellig))
    }

    /// Ein Fehler macht den Eintrag auffällig, auch ohne das Flag zu setzen.
    func testFehlerImpliziertAuffaellig() {
        var log = RohLog(modus: .nurAuffaellige)
        log.haenge(Data([0x00]), quelle: "2ACD", fehler: "Flags unvollständig")

        XCTAssertTrue(log.eintraege.first?.auffaellig == true)
        XCTAssertTrue(log.alsText.contains("⚠︎"))
    }

    func testModusUmschaltenGiltAbSofort() {
        var log = RohLog(modus: .nurAuffaellige)
        log.haenge(Data([0x01]), quelle: "2ACD")
        XCTAssertTrue(log.eintraege.isEmpty)

        log.modus = .alles
        log.haenge(Data([0x02]), quelle: "2ACD")

        XCTAssertEqual(log.eintraege.count, 1, "vorher Verworfenes kommt nicht zurück")
    }
}
