import XCTest
@testable import Treadmill

final class ErfolgeTests: XCTestCase {

    func testAufsteigendSortiertUndEindeutig() {
        let meter = Erfolge.alle.map(\.meter)

        XCTAssertEqual(meter, meter.sorted(), "Erfolge müssen aufsteigend liegen")
        XCTAssertEqual(Set(meter).count, meter.count, "keine doppelten Distanzen")
    }

    /// Der Wunsch war »alle paar Kilometer einer«. Bis 50 km darf keine Lücke
    /// größer als 10 km sein, sonst fühlt sich der Anfang leer an.
    func testDichteAmAnfang() {
        let fruehe = Erfolge.alle.filter { $0.meter <= 50_000 }
        XCTAssertGreaterThanOrEqual(fruehe.count, 15)

        var vorher = 0.0
        for erfolg in fruehe {
            XCTAssertLessThanOrEqual(erfolg.meter - vorher, 10_000,
                                     "Lücke vor »\(erfolg.titelDeutsch)« zu groß")
            vorher = erfolg.meter
        }
    }

    /// Der erste Erfolg muss nach einer einzigen Einheit erreichbar sein.
    func testErsterErfolgIstSofortErreichbar() {
        XCTAssertLessThanOrEqual(Erfolge.alle.first?.meter ?? .infinity, 1_000)
    }

    func testErreichteErfolge() {
        let erreicht = Erfolge.erreicht(meter: 42_195)

        XCTAssertEqual(erreicht.last?.titelDeutsch, "Marathon")
        XCTAssertTrue(erreicht.allSatisfy { $0.meter <= 42_195 })
    }

    func testNaechsterErfolg() {
        let naechster = Erfolge.naechster(meter: 42_195)

        XCTAssertNotNil(naechster)
        XCTAssertGreaterThan(naechster!.meter, 42_195)
    }

    func testOhneStreckeIstNichtsErreicht() {
        XCTAssertTrue(Erfolge.erreicht(meter: 0).isEmpty)
        XCTAssertEqual(Erfolge.naechster(meter: 0)?.meter, Erfolge.alle.first?.meter)
    }

    func testNachDemLetztenErfolgGibtEsKeinenNaechsten() {
        let ueberAlles = (Erfolge.alle.last?.meter ?? 0) + 1

        XCTAssertNil(Erfolge.naechster(meter: ueberAlles))
        XCTAssertNil(Erfolge.fortschritt(meter: ueberAlles))
        XCTAssertEqual(Erfolge.erreicht(meter: ueberAlles).count, Erfolge.alle.count)
    }

    func testFortschrittZwischenZweiErfolgen() {
        let a = Erfolge.alle[0].meter
        let b = Erfolge.alle[1].meter
        let mitte = a + (b - a) / 2

        XCTAssertEqual(Erfolge.fortschritt(meter: mitte) ?? 0, 0.5, accuracy: 0.01)
        XCTAssertEqual(Erfolge.fortschritt(meter: a) ?? -1, 0, accuracy: 0.01)
    }

    // MARK: - Texte

    func testAlleZweisprachigUndNichtLeer() {
        for erfolg in Erfolge.alle {
            XCTAssertFalse(erfolg.titelDeutsch.isEmpty)
            XCTAssertFalse(erfolg.textDeutsch.isEmpty)
            XCTAssertFalse(erfolg.titelEnglisch.isEmpty)
            XCTAssertFalse(erfolg.textEnglisch.isEmpty)
            XCTAssertNotEqual(erfolg.textDeutsch, erfolg.textEnglisch,
                              "»\(erfolg.titelDeutsch)« ist nicht übersetzt")
        }
    }

    func testSprachauswahlLiefertDenPassendenText() {
        let erfolg = Erfolge.alle[0]

        XCTAssertEqual(erfolg.titel(.deutsch), erfolg.titelDeutsch)
        XCTAssertEqual(erfolg.text(.englisch), erfolg.textEnglisch)
    }
}
