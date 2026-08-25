import XCTest
@testable import FTMSKit

final class SitzungsaggregatorTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    /// Baut ein Paket im Format des echten Geräts (Flags 0x0584).
    private func paket(kmh: Double, meter: UInt32, kcal: UInt16,
                       sekunden: UInt16, bpm: UInt8 = 0) throws -> LaufbandDaten {
        var bauer = NutzlastBauer()
        bauer.setzeFlag(2); bauer.setzeFlag(7); bauer.setzeFlag(8); bauer.setzeFlag(10)
        bauer.uint16(UInt16((kmh * 100).rounded()))
        bauer.uint24(meter)
        bauer.uint16(kcal)
        bauer.uint16(0)
        bauer.uint8(0)
        bauer.uint8(bpm)
        bauer.uint16(sekunden)
        return try TreadmillDataDecoder.dekodiere(bauer.daten)
    }

    func testErstesPaketLiefertKeinenZuwachs() throws {
        var aggregator = Sitzungsaggregator()

        let zuwachs = aggregator.verarbeite(
            try paket(kmh: 5.0, meter: 100, kcal: 3, sekunden: 60), zeitpunkt: start
        )

        XCTAssertNil(zuwachs, "ohne Vorgänger gibt es kein Intervall")
        XCTAssertEqual(aggregator.stand.distanzMeter, 100)
        XCTAssertEqual(aggregator.stand.pakete, 1)
    }

    func testNormalerFortschritt() throws {
        var aggregator = Sitzungsaggregator()
        aggregator.verarbeite(try paket(kmh: 5.0, meter: 100, kcal: 3, sekunden: 60),
                              zeitpunkt: start)

        let zuwachs = try XCTUnwrap(aggregator.verarbeite(
            try paket(kmh: 5.5, meter: 140, kcal: 5, sekunden: 90),
            zeitpunkt: start.addingTimeInterval(30)
        ))

        XCTAssertEqual(zuwachs.distanzMeter, 40)
        XCTAssertEqual(zuwachs.energieKcal, 2)
        XCTAssertEqual(zuwachs.von, start)
        XCTAssertEqual(zuwachs.bis, start.addingTimeInterval(30))
        XCTAssertEqual(aggregator.stand.distanzMeter, 140)
        XCTAssertEqual(aggregator.stand.maxGeschwindigkeit, 5.5, accuracy: 0.001)
    }

    /// Der eigentliche Grund für diese Klasse: das Band setzt seine Zähler
    /// zurück, wenn am Gerät eine neue Einheit gestartet wird.
    func testGeraeteResetVerliertKeineDistanz() throws {
        var aggregator = Sitzungsaggregator()
        aggregator.verarbeite(try paket(kmh: 5.0, meter: 500, kcal: 20, sekunden: 300),
                              zeitpunkt: start)
        aggregator.verarbeite(try paket(kmh: 5.0, meter: 800, kcal: 30, sekunden: 480),
                              zeitpunkt: start.addingTimeInterval(60))

        // Band startet neu: Zähler springen auf kleine Werte.
        let zuwachs = try XCTUnwrap(aggregator.verarbeite(
            try paket(kmh: 1.0, meter: 10, kcal: 1, sekunden: 5),
            zeitpunkt: start.addingTimeInterval(120)
        ))

        XCTAssertEqual(aggregator.stand.geraeteResets, 1)
        XCTAssertEqual(aggregator.stand.distanzMeter, 810, "800 vor dem Reset + 10 danach")
        XCTAssertEqual(aggregator.stand.energieKcal, 31)
        XCTAssertEqual(zuwachs.distanzMeter, 10, "nach dem Reset zählt nur der neue Wert")
        XCTAssertGreaterThanOrEqual(zuwachs.distanzMeter, 0, "nie negativ")
    }

    func testMehrereResetsHintereinander() throws {
        var aggregator = Sitzungsaggregator()
        for (index, meter) in [100, 200, 50, 120, 30].enumerated() {
            aggregator.verarbeite(
                try paket(kmh: 3.0, meter: UInt32(meter), kcal: 0, sekunden: UInt16(index * 10)),
                zeitpunkt: start.addingTimeInterval(Double(index) * 10)
            )
        }

        XCTAssertEqual(aggregator.stand.geraeteResets, 2)
        XCTAssertEqual(aggregator.stand.distanzMeter, 200 + 120 + 30)
    }

    /// Gleicher Wert zweimal (das Gerät sendet 1×/s, auch wenn nichts passiert)
    /// darf keinen Zuwachs erzeugen und nicht als Reset zählen.
    func testUnveraenderteWerteErzeugenKeinenZuwachs() throws {
        var aggregator = Sitzungsaggregator()
        aggregator.verarbeite(try paket(kmh: 0, meter: 20, kcal: 0, sekunden: 76),
                              zeitpunkt: start)

        let zuwachs = try XCTUnwrap(aggregator.verarbeite(
            try paket(kmh: 0, meter: 20, kcal: 0, sekunden: 77),
            zeitpunkt: start.addingTimeInterval(1)
        ))

        XCTAssertTrue(zuwachs.istLeer)
        XCTAssertEqual(aggregator.stand.geraeteResets, 0)
    }

    /// 0 bpm bedeutet »kein Brustgurt«, nicht Herzfrequenz 0 — darf nicht
    /// als Sample nach HealthKit wandern.
    func testNullHerzfrequenzWirdVerworfen() throws {
        var aggregator = Sitzungsaggregator()
        aggregator.verarbeite(try paket(kmh: 5, meter: 0, kcal: 0, sekunden: 0, bpm: 0),
                              zeitpunkt: start)

        let ohneGurt = try XCTUnwrap(aggregator.verarbeite(
            try paket(kmh: 5, meter: 10, kcal: 0, sekunden: 10, bpm: 0),
            zeitpunkt: start.addingTimeInterval(10)
        ))
        let mitGurt = try XCTUnwrap(aggregator.verarbeite(
            try paket(kmh: 5, meter: 20, kcal: 0, sekunden: 20, bpm: 142),
            zeitpunkt: start.addingTimeInterval(20)
        ))

        XCTAssertNil(ohneGurt.herzfrequenz)
        XCTAssertEqual(mitGurt.herzfrequenz, 142)
    }

    /// Pakete ohne Distanzfeld (andere Flags) dürfen den Stand nicht kaputt machen.
    func testPaketOhneDistanzfeld() throws {
        var aggregator = Sitzungsaggregator()
        aggregator.verarbeite(try paket(kmh: 5, meter: 300, kcal: 10, sekunden: 100),
                              zeitpunkt: start)

        var bauer = NutzlastBauer()
        bauer.uint16(550)                                    // nur Geschwindigkeit
        aggregator.verarbeite(try TreadmillDataDecoder.dekodiere(bauer.daten),
                              zeitpunkt: start.addingTimeInterval(1))

        XCTAssertEqual(aggregator.stand.distanzMeter, 300, "Distanz bleibt stehen")
        XCTAssertEqual(aggregator.stand.maxGeschwindigkeit, 5.5, accuracy: 0.001)
        XCTAssertEqual(aggregator.stand.geraeteResets, 0)
    }

    /// Realer Ablauf gegen die echten Dumps vom 18.08.2026.
    func testGegenEchteDumps() throws {
        var aggregator = Sitzungsaggregator()
        for (index, hex) in EchteDumpsTests.dumps.enumerated() {
            aggregator.verarbeite(try TreadmillDataDecoder.dekodiere(hex: hex),
                                  zeitpunkt: start.addingTimeInterval(Double(index)))
        }

        XCTAssertEqual(aggregator.stand.distanzMeter, 30)
        XCTAssertEqual(aggregator.stand.energieKcal, 1)
        XCTAssertEqual(aggregator.stand.dauer, 135)
        XCTAssertEqual(aggregator.stand.geraeteResets, 0)
        XCTAssertEqual(aggregator.stand.maxGeschwindigkeit, 1.0, accuracy: 0.001)
    }

    // MARK: - Ruheframes des echten Geräts

    /// Baut ein Paket im Format, das das Band im Ruhezustand sendet:
    /// alle kumulativen Zähler gleichzeitig 0.
    private func ruheframe() throws -> LaufbandDaten {
        try paket(kmh: 0, meter: 0, kcal: 0, sekunden: 0)
    }

    /// Der am 18.08.2026 gemessene Ablauf: das Band nullt bei stehendem Gurt
    /// alle Zähler und nimmt beim Weiterlaufen den alten Stand wieder auf.
    /// Ohne Sonderbehandlung zählt der Aggregator die Distanz doppelt.
    func testRuhepauseZaehltNichtDoppelt() throws {
        var aggregator = Sitzungsaggregator()
        aggregator.verarbeite(try paket(kmh: 3, meter: 500, kcal: 17, sekunden: 500),
                              zeitpunkt: start)
        aggregator.verarbeite(try paket(kmh: 0.9, meter: 510, kcal: 17, sekunden: 511),
                              zeitpunkt: start.addingTimeInterval(11))

        // Band steht: 60 Nullframes.
        for sekunde in 12...71 {
            aggregator.verarbeite(try ruheframe(),
                                  zeitpunkt: start.addingTimeInterval(Double(sekunde)))
        }
        XCTAssertEqual(aggregator.stand.distanzMeter, 510, "Ruhe darf nichts verändern")
        XCTAssertEqual(aggregator.stand.geraeteResets, 0, "Ruhe ist kein Reset")

        // Band läuft weiter und setzt beim alten Stand auf.
        let zuwachs = try XCTUnwrap(aggregator.verarbeite(
            try paket(kmh: 3, meter: 520, kcal: 17, sekunden: 521),
            zeitpunkt: start.addingTimeInterval(72)
        ))

        XCTAssertEqual(aggregator.stand.distanzMeter, 520, "nicht 510 + 520")
        XCTAssertEqual(zuwachs.distanzMeter, 10)
        XCTAssertEqual(aggregator.stand.geraeteResets, 0)
    }

    /// Gegenprobe: zählt das Gerät nach der Ruhe wirklich von vorn, ist es ein
    /// echter Reset und der bisherige Stand muss erhalten bleiben.
    func testEchterResetNachRuheWirdErkannt() throws {
        var aggregator = Sitzungsaggregator()
        aggregator.verarbeite(try paket(kmh: 3, meter: 510, kcal: 17, sekunden: 511),
                              zeitpunkt: start)
        for sekunde in 1...30 {
            aggregator.verarbeite(try ruheframe(),
                                  zeitpunkt: start.addingTimeInterval(Double(sekunde)))
        }

        // Neue Einheit am Gerät: Zähler beginnen klein.
        aggregator.verarbeite(try paket(kmh: 3, meter: 10, kcal: 0, sekunden: 5),
                              zeitpunkt: start.addingTimeInterval(31))

        XCTAssertEqual(aggregator.stand.distanzMeter, 520, "510 vor dem Reset + 10 danach")
        XCTAssertEqual(aggregator.stand.geraeteResets, 1)
    }

    /// Während der Ruhe darf kein Distanz-Zuwachs entstehen — sonst würde die
    /// Trainingsautomatik das Band für laufend halten.
    func testRuheframeErzeugtKeinenZuwachs() throws {
        var aggregator = Sitzungsaggregator()
        aggregator.verarbeite(try paket(kmh: 3, meter: 510, kcal: 17, sekunden: 511),
                              zeitpunkt: start)

        let zuwachs = try XCTUnwrap(aggregator.verarbeite(
            try ruheframe(), zeitpunkt: start.addingTimeInterval(1)
        ))

        XCTAssertTrue(zuwachs.istLeer)
    }

    /// Nullframes ganz am Anfang (Band an, noch nichts passiert) sind normal
    /// und dürfen nicht als Ruhe-Sonderfall gelten.
    func testNullframesVorDemStart() throws {
        var aggregator = Sitzungsaggregator()
        for sekunde in 0...10 {
            aggregator.verarbeite(try ruheframe(),
                                  zeitpunkt: start.addingTimeInterval(Double(sekunde)))
        }
        let zuwachs = try XCTUnwrap(aggregator.verarbeite(
            try paket(kmh: 1, meter: 10, kcal: 0, sekunden: 12),
            zeitpunkt: start.addingTimeInterval(11)
        ))

        XCTAssertEqual(aggregator.stand.distanzMeter, 10)
        XCTAssertEqual(zuwachs.distanzMeter, 10)
        XCTAssertEqual(aggregator.stand.geraeteResets, 0)
    }
}