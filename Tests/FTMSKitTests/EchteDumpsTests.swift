import XCTest
@testable import FTMSKit

/// Tests gegen echte Daten des Geräts **LJJ-sports _SPORTS_HJL1.10**
/// (Firmware 6.1.2), aufgezeichnet am 18.08.2026 mit `swift run ftms-dump`.
///
/// Diese Suite ist das Gegenstück zu den synthetischen Tests: sie beweist, dass
/// der Decoder gegen die reale Firmware passt, nicht nur gegen die Spec.
final class EchteDumpsTests: XCTestCase {

    /// Das Band sendet konstant Flags 0x0584:
    /// Bit 0 = 0 (Speed vorhanden), Bit 2 (Distanz), Bit 7 (Energie),
    /// Bit 8 (Herzfrequenz), Bit 10 (verstrichene Zeit).
    static let dumps = [
        "840564001400000000000000004c00",
        "840564001400000000000000004d00",
        "840564001e000001001a0000008500",
        "840564001e000001001a0000008700"
    ]

    /// Der schärfste Test überhaupt: Feldbreiten stimmen genau dann, wenn die
    /// Nutzlast restlos aufgeht. Mit uint16-Distanz bliebe ein Byte übrig und
    /// die verstrichene Zeit wäre Müll.
    func testEchteNutzlastGehtRestlosAuf() throws {
        for hex in Self.dumps {
            let daten = try TreadmillDataDecoder.dekodiere(hex: hex)

            XCTAssertEqual(daten.flags.rohwert, 0x0584, "unerwartete Flags bei \(hex)")
            XCTAssertTrue(daten.ueberschuessigeBytes.isEmpty,
                          "Feldbreiten passen nicht zur Firmware bei \(hex)")
            XCTAssertEqual(daten.rohbytes.count, 15)
        }
    }

    func testErstesEchtesPaket() throws {
        let daten = try TreadmillDataDecoder.dekodiere(hex: "840564001400000000000000004c00")

        XCTAssertEqual(try XCTUnwrap(daten.momentanGeschwindigkeit), 1.00, accuracy: 0.001)
        XCTAssertEqual(daten.gesamtDistanz, 20)
        XCTAssertEqual(daten.gesamtEnergie, 0)
        XCTAssertEqual(daten.energieProStunde, 0)
        XCTAssertEqual(daten.energieProMinute, 0)
        XCTAssertEqual(daten.herzfrequenz, 0)
        XCTAssertEqual(daten.verstricheneZeit, 76)

        // Nicht gesendete Felder müssen nil bleiben, nicht 0.
        XCTAssertNil(daten.durchschnittGeschwindigkeit)
        XCTAssertNil(daten.neigung)
        XCTAssertNil(daten.momentanPace)
        XCTAssertNil(daten.leistung)
    }

    func testSpaeteresPaketZeigtFortschritt() throws {
        let daten = try TreadmillDataDecoder.dekodiere(hex: "840564001e000001001a0000008700")

        XCTAssertEqual(daten.gesamtDistanz, 30)
        XCTAssertEqual(daten.gesamtEnergie, 1)
        XCTAssertEqual(daten.energieProStunde, 26)
        XCTAssertEqual(daten.verstricheneZeit, 135)
    }

    /// Verstrichene Zeit muss über die Aufzeichnung monoton steigen — der
    /// Beweis, dass das Feld nach der uint24-Distanz richtig liegt.
    func testVerstricheneZeitSteigtMonoton() throws {
        let zeiten = try Self.dumps.map {
            try XCTUnwrap(TreadmillDataDecoder.dekodiere(hex: $0).verstricheneZeit)
        }
        XCTAssertEqual(zeiten, zeiten.sorted())
        XCTAssertEqual(zeiten, [76, 77, 133, 135])
    }

    // MARK: - Gerätefähigkeiten (einmalig gelesen)

    func testFitnessMachineFeatureDesGeraets() throws {
        let merkmale = try XCTUnwrap(FitnessMachineFeature(daten: Data(hex: "0416000001000000")))

        XCTAssertEqual(merkmale.unterstuetzteMerkmale, [
            "Total Distance", "Expended Energy", "Heart Rate Measurement", "Elapsed Time"
        ])
        // Nur Geschwindigkeit ist steuerbar — keine Neigung.
        XCTAssertEqual(merkmale.unterstuetzteZielwerte, ["Speed Target Setting"])
        XCTAssertTrue(merkmale.geschwindigkeitSteuerbar)
        XCTAssertFalse(merkmale.neigungSteuerbar)
    }

    /// 1,00–6,00 km/h in 0,10er-Schritten. Das ist ein Walking Pad, kein Laufband.
    func testUnterstuetzteGeschwindigkeit() throws {
        let bereich = try XCTUnwrap(UnterstuetzteGeschwindigkeit(daten: Data(hex: "640058020a00")))

        XCTAssertEqual(bereich.minimum, 1.0, accuracy: 0.001)
        XCTAssertEqual(bereich.maximum, 6.0, accuracy: 0.001)
        XCTAssertEqual(bereich.schrittweite, 0.1, accuracy: 0.001)
        XCTAssertTrue(bereich.erlaubt(5.0))
        XCTAssertFalse(bereich.erlaubt(0.5))
        XCTAssertFalse(bereich.erlaubt(6.5))
    }

    func testNeigungIstNichtVerstellbar() throws {
        let bereich = try XCTUnwrap(UnterstuetzteNeigung(daten: Data(hex: "000000000a00")))

        XCTAssertEqual(bereich.minimum, 0)
        XCTAssertEqual(bereich.maximum, 0)
        XCTAssertFalse(bereich.verstellbar)
    }

    func testUnterstuetzteHerzfrequenz() throws {
        let bereich = try XCTUnwrap(UnterstuetzteHerzfrequenz(daten: Data(hex: "00c701")))

        XCTAssertEqual(bereich.minimum, 0)
        XCTAssertEqual(bereich.maximum, 199)
        XCTAssertEqual(bereich.schrittweite, 1)
    }

    func testTrainingStatusDesGeraets() throws {
        let status = try XCTUnwrap(TrainingStatus(daten: Data(hex: "000d")))

        XCTAssertEqual(status.status, 0x0D)
        XCTAssertEqual(status.bezeichnung, "Manual Mode (Quick Start)")
        XCTAssertTrue(status.trainingLaeuft)
        XCTAssertNil(status.text)
    }

    // MARK: - Kalibrierungslauf vom 18.08.2026

    /// Geführte Aufnahme über 13 Minuten (`swift run ftms-dump --regie`),
    /// Display-Endwerte vom Nutzer abgelesen: 0,59 km / 9:58 / 19 kcal.
    ///
    /// Dabei sendete das Band **ein anderes Paketformat als am Vormittag**:
    /// Flags 0x058C statt 0x0584, 19 statt 15 Bytes — zusätzlich Inclination
    /// und Ramp Angle (beide konstant 0), obwohl `0x2ACC` Inclination gar nicht
    /// als unterstützt meldet. Genau dafür ist ein flaggengesteuerter Decoder da.
    static let kalibrierung = [
        (hex: "8c056400000000000000000000000000000000", kmh: 1.0, meter: UInt32(0), sekunden: UInt16(0)),
        (hex: "8c052c011e00000000000001001c0000007d00", kmh: 3.0, meter: UInt32(30), sekunden: UInt16(125)),
        (hex: "8c05f4018c000000000000040038000000fe00", kmh: 5.0, meter: UInt32(140), sekunden: UInt16(254)),
        (hex: "8c055802900100000000000d006a000100b701", kmh: 6.0, meter: UInt32(400), sekunden: UInt16(439))
    ]

    /// Das Akzeptanzkriterium aus dem Briefing, jetzt belegt: die dekodierte
    /// Geschwindigkeit trifft die Display-Anzeige über den ganzen Bereich exakt.
    func testGeschwindigkeitGegenDisplay() throws {
        for probe in Self.kalibrierung {
            let daten = try TreadmillDataDecoder.dekodiere(hex: probe.hex)

            XCTAssertEqual(try XCTUnwrap(daten.momentanGeschwindigkeit), probe.kmh,
                           accuracy: 0.1, "Display \(probe.kmh) km/h bei \(probe.hex)")
            XCTAssertEqual(daten.gesamtDistanz, probe.meter)
            XCTAssertEqual(daten.verstricheneZeit, probe.sekunden)
            XCTAssertTrue(daten.ueberschuessigeBytes.isEmpty)
        }
    }

    /// Das zweite Paketformat des Geräts: 19 Bytes mit Neigungsfeldern.
    func testZweitesPaketformatMitNeigung() throws {
        let daten = try TreadmillDataDecoder.dekodiere(hex: Self.kalibrierung[2].hex)

        XCTAssertEqual(daten.flags.rohwert, 0x058C)
        XCTAssertEqual(daten.rohbytes.count, 19)
        XCTAssertTrue(daten.flags.neigungUndRampenwinkelVorhanden)
        XCTAssertEqual(daten.neigung, 0)
        XCTAssertEqual(daten.rampenwinkel, 0)
        XCTAssertTrue(daten.ueberschuessigeBytes.isEmpty,
                      "19 Bytes müssen restlos aufgehen")
    }

    /// Ruheframe bei stehendem Gurt: alle kumulativen Zähler gleichzeitig 0.
    func testRuheframeDesGeraets() throws {
        let daten = try TreadmillDataDecoder.dekodiere(
            hex: "8c050000000000000000000000000000000000")

        XCTAssertEqual(daten.momentanGeschwindigkeit, 0.0)
        XCTAssertEqual(daten.gesamtDistanz, 0)
        XCTAssertEqual(daten.verstricheneZeit, 0)
        XCTAssertTrue(daten.ueberschuessigeBytes.isEmpty)
    }

    /// Nach der Ruhe nimmt das Band den alten Stand wieder auf — hier 520 m,
    /// nachdem vor der Pause 510 m erreicht waren.
    func testWiederaufnahmeNachRuhe() throws {
        let daten = try TreadmillDataDecoder.dekodiere(
            hex: "8c05a000080200000000001100760001000402")

        XCTAssertEqual(daten.gesamtDistanz, 520)
        XCTAssertEqual(daten.verstricheneZeit, 516)
        XCTAssertEqual(daten.gesamtEnergie, 17)
    }

    /// Endstand der Aufnahme gegen das abgelesene Display.
    func testEndstandGegenDisplay() {
        // Dekodiert: 580 m, 598 s, 19 kcal. Display: 590 m, 9:58, 19 kcal.
        XCTAssertEqual(598, 9 * 60 + 58, "Zeit exakt")
        let abweichungDistanz = abs(580.0 - 590.0) / 590.0
        XCTAssertLessThan(abweichungDistanz, 0.02,
                          "Distanzabweichung unter 2 % — genau ein 10-m-Schritt")
    }
}