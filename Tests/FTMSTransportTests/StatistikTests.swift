import XCTest
@testable import FTMSTransport

final class StatistikTests: XCTestCase {

    /// 18.08.2026, 12:00 Uhr — fester Bezugspunkt, damit die Zeiträume nicht
    /// von der Uhr des Testrechners abhängen.
    private let jetzt = Date(timeIntervalSince1970: 1_787_054_400)
    private var kalender: Calendar = {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Vienna")!
        return k
    }()

    private func einheit(vorTagen: Double, meter: Double, dauer: TimeInterval = 600,
                         maxKmh: Double = 5) -> Sitzungszusammenfassung {
        let beginn = jetzt.addingTimeInterval(-vorTagen * 86_400)
        return Sitzungszusammenfassung(
            pfad: URL(fileURLWithPath: "/tmp/\(vorTagen)-\(meter).jsonl"),
            beginn: beginn, ende: beginn.addingTimeInterval(dauer), dauer: dauer,
            distanzMeter: meter, energieKcal: meter / 50,
            maxGeschwindigkeit: maxKmh, pakete: Int(dauer)
        )
    }

    private lazy var einheiten = [
        einheit(vorTagen: 0.1, meter: 1000),      // heute
        einheit(vorTagen: 0.4, meter: 500),       // heute
        einheit(vorTagen: 3, meter: 2000),        // diese Woche
        einheit(vorTagen: 20, meter: 3000),       // letzte 4 Wochen
        einheit(vorTagen: 200, meter: 4000),      // letztes Jahr
        einheit(vorTagen: 500, meter: 5000)       // älter
    ]

    func testHeute() {
        let werte = Statistik.werte(einheiten, zeitraum: .heute, jetzt: jetzt, kalender: kalender)

        XCTAssertEqual(werte.einheiten, 2)
        XCTAssertEqual(werte.distanzMeter, 1500)
    }

    func testSiebenTage() {
        let werte = Statistik.werte(einheiten, zeitraum: .siebenTage,
                                    jetzt: jetzt, kalender: kalender)

        XCTAssertEqual(werte.einheiten, 3)
        XCTAssertEqual(werte.distanzMeter, 3500)
    }

    func testVierWochen() {
        let werte = Statistik.werte(einheiten, zeitraum: .vierWochen,
                                    jetzt: jetzt, kalender: kalender)

        XCTAssertEqual(werte.einheiten, 4)
        XCTAssertEqual(werte.distanzMeter, 6500)
    }

    func testJahr() {
        let werte = Statistik.werte(einheiten, zeitraum: .jahr, jetzt: jetzt, kalender: kalender)

        XCTAssertEqual(werte.einheiten, 5)
        XCTAssertEqual(werte.distanzMeter, 10_500)
    }

    func testGesamt() {
        let werte = Statistik.werte(einheiten, zeitraum: .gesamt, jetzt: jetzt, kalender: kalender)

        XCTAssertEqual(werte.einheiten, 6)
        XCTAssertEqual(werte.distanzMeter, 15_500)
        XCTAssertEqual(werte.laengsteEinheitMeter, 5000)
    }

    /// »Heute« ist der Kalendertag. Gestern 23:30 darf heute früh nicht mehr
    /// mitzählen, obwohl es keine 24 Stunden her ist.
    func testHeuteIstKalendertagKein24StundenFenster() {
        let frueh = kalender.date(bySettingHour: 6, minute: 0, second: 0, of: jetzt)!
        let gesternAbend = frueh.addingTimeInterval(-7 * 3600)   // gestern 23:00

        let werte = Statistik.werte([einheit(vorTagen: 0, meter: 900)]
            .map { _ in Sitzungszusammenfassung(
                pfad: URL(fileURLWithPath: "/tmp/g.jsonl"), beginn: gesternAbend,
                ende: gesternAbend, dauer: 600, distanzMeter: 900,
                energieKcal: 10, maxGeschwindigkeit: 4, pakete: 10) },
            zeitraum: .heute, jetzt: frueh, kalender: kalender)

        XCTAssertEqual(werte.einheiten, 0)
    }

    func testLeereListe() {
        let werte = Statistik.werte([], zeitraum: .gesamt, jetzt: jetzt, kalender: kalender)

        XCTAssertEqual(werte.einheiten, 0)
        XCTAssertEqual(werte.durchschnittsgeschwindigkeit, 0, "keine Division durch null")
    }

    func testDurchschnittUeberAlleEinheiten() {
        // 3600 m in 3600 s = 3,6 km/h
        let werte = Statistik.werte([einheit(vorTagen: 0.1, meter: 3600, dauer: 3600)],
                                    zeitraum: .gesamt, jetzt: jetzt, kalender: kalender)

        XCTAssertEqual(werte.durchschnittsgeschwindigkeit, 3.6, accuracy: 0.001)
    }
}
