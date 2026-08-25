import XCTest
@testable import FTMSTransport

final class SitzungsarchivTests: XCTestCase {

    private var ordner: URL!

    override func setUpWithError() throws {
        ordner = FileManager.default.temporaryDirectory
            .appendingPathComponent("archivtest-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: ordner)
    }

    /// Schreibt eine Einheit mit gleichmäßiger Geschwindigkeit.
    @discardableResult
    private func schreibe(_ name: String, sekunden: Int, kmh: Double) throws -> URL {
        let speicher = try SitzungsSpeicher(ordner: ordner, name: name)
        var strecke = 0.0
        for t in stride(from: 0, to: sekunden, by: 1) {
            strecke += kmh / 3.6
            speicher.schreibe(SitzungsZeile(
                zeit: Date(timeIntervalSince1970: 1_000_000 + Double(t)),
                hex: "8c05", distanzMeter: strecke, energieKcal: Double(t) / 60,
                dauer: Double(t), geschwindigkeit: kmh, herzfrequenz: nil))
        }
        speicher.schliesse()
        return speicher.pfad
    }

    func testZusammenfassung() throws {
        let pfad = try schreibe("a.jsonl", sekunden: 600, kmh: 6)

        let zusammenfassung = try XCTUnwrap(Sitzungsarchiv.fasseZusammen(pfad))

        XCTAssertEqual(zusammenfassung.distanzMeter, 1000, accuracy: 2)
        XCTAssertEqual(zusammenfassung.dauer, 599)
        XCTAssertEqual(zusammenfassung.maxGeschwindigkeit, 6)
        XCTAssertEqual(zusammenfassung.pakete, 600)
        XCTAssertEqual(zusammenfassung.durchschnittsgeschwindigkeit, 6, accuracy: 0.1)
    }

    func testLeereDateiErgibtKeineZusammenfassung() throws {
        let speicher = try SitzungsSpeicher(ordner: ordner, name: "leer.jsonl")
        speicher.schliesse()

        XCTAssertNil(Sitzungsarchiv.fasseZusammen(speicher.pfad))
    }

    /// Fehlstarts ohne Strecke sollen die Liste nicht zumüllen.
    func testEinheitenOhneStreckeWerdenAusgeblendet() throws {
        try schreibe("echt.jsonl", sekunden: 300, kmh: 5)
        let speicher = try SitzungsSpeicher(ordner: ordner, name: "fehlstart.jsonl")
        speicher.schreibe(SitzungsZeile(zeit: Date(timeIntervalSince1970: 1_000_000),
                                        hex: "8c05", distanzMeter: 0, energieKcal: 0,
                                        dauer: 0, geschwindigkeit: 0, herzfrequenz: nil))
        speicher.schliesse()

        let alle = Sitzungsarchiv.alleZusammenfassungen(in: ordner)

        XCTAssertEqual(alle.count, 1)
        XCTAssertTrue(alle[0].pfad.lastPathComponent == "echt.jsonl")
    }

    /// Die Grafik bekommt höchstens so viele Punkte wie angefragt.
    func testVerlaufWirdAusgeduennt() throws {
        let pfad = try schreibe("lang.jsonl", sekunden: 3600, kmh: 5)

        let punkte = Sitzungsarchiv.verlauf(pfad, hoechstens: 100)

        XCTAssertEqual(punkte.count, 100)
        XCTAssertEqual(punkte.first?.sekunde, 0)
        XCTAssertTrue(punkte.map(\.sekunde) == punkte.map(\.sekunde).sorted(),
                      "Punkte müssen zeitlich geordnet bleiben")
    }

    func testKurzerVerlaufWirdNichtAusgeduennt() throws {
        let pfad = try schreibe("kurz.jsonl", sekunden: 30, kmh: 4)

        XCTAssertEqual(Sitzungsarchiv.verlauf(pfad, hoechstens: 400).count, 30)
    }

    // MARK: - Löschen

    func testLoeschenEntferntDieDatei() throws {
        let pfad = try schreibe("weg.jsonl", sekunden: 60, kmh: 5)
        XCTAssertEqual(Sitzungsarchiv.alleZusammenfassungen(in: ordner).count, 1)

        XCTAssertTrue(Sitzungsarchiv.loesche(pfad))

        XCTAssertFalse(FileManager.default.fileExists(atPath: pfad.path))
        XCTAssertTrue(Sitzungsarchiv.alleZusammenfassungen(in: ordner).isEmpty)
    }

    func testLoeschenTrifftNurDieGewaehlteEinheit() throws {
        let eins = try schreibe("eins.jsonl", sekunden: 60, kmh: 5)
        try schreibe("zwei.jsonl", sekunden: 60, kmh: 5)

        Sitzungsarchiv.loesche(eins)

        let uebrig = Sitzungsarchiv.alleZusammenfassungen(in: ordner)
        XCTAssertEqual(uebrig.count, 1)
        XCTAssertEqual(uebrig[0].pfad.lastPathComponent, "zwei.jsonl")
    }

    func testLoeschenEinerFehlendenDateiSchlaegtFehlOhneAbsturz() {
        XCTAssertFalse(Sitzungsarchiv.loesche(ordner.appendingPathComponent("gibtsnicht.jsonl")))
    }
}
