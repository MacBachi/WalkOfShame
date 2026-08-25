import XCTest
@testable import FTMSKit

final class TreadmillDataDecoderTests: XCTestCase {

    // MARK: - Bug-Falle 1: invertiertes Bit 0 ("More Data")

    /// Flags = 0x0000 → Momentangeschwindigkeit ist **vorhanden**.
    func testBit0NichtGesetztBedeutetGeschwindigkeitVorhanden() throws {
        var bauer = NutzlastBauer()
        bauer.uint16(500)                                    // 5,00 km/h

        let daten = try TreadmillDataDecoder.dekodiere(bauer.daten)

        XCTAssertEqual(daten.momentanGeschwindigkeit, 5.0)
        XCTAssertEqual(daten.rohbytes.hexString, "0000f401")
    }

    /// Flags = 0x0001 → Momentangeschwindigkeit **fehlt**, Nutzlast ist nur 2 Bytes.
    func testBit0GesetztBedeutetGeschwindigkeitFehlt() throws {
        var bauer = NutzlastBauer()
        bauer.setzeFlag(0)

        let daten = try TreadmillDataDecoder.dekodiere(bauer.daten)

        XCTAssertNil(daten.momentanGeschwindigkeit)
        XCTAssertTrue(daten.ueberschuessigeBytes.isEmpty)
    }

    /// Die eigentliche Falle: Bit 0 gesetzt + Bit 1 gesetzt.
    /// Ein Parser, der Bit 0 nicht invertiert, liest hier die Durchschnitts-
    /// geschwindigkeit gar nicht — oder verschiebt alles um 2 Bytes.
    func testBit0GesetztUndDurchschnittGeschwindigkeitVorhanden() throws {
        var bauer = NutzlastBauer()
        bauer.setzeFlag(0)
        bauer.setzeFlag(1)
        bauer.uint16(432)                                    // 4,32 km/h Ø

        let daten = try TreadmillDataDecoder.dekodiere(bauer.daten)

        XCTAssertNil(daten.momentanGeschwindigkeit)
        XCTAssertEqual(try XCTUnwrap(daten.durchschnittGeschwindigkeit), 4.32, accuracy: 0.0001)
    }

    // MARK: - Bug-Falle 2: Total Distance ist uint24

    /// Distanz > 65535 m — mit uint16 nicht darstellbar.
    func testGesamtDistanzIstUint24() throws {
        var bauer = NutzlastBauer()
        bauer.setzeFlag(2)
        bauer.uint16(500)                                    // Momentangeschwindigkeit
        bauer.uint24(100_000)                                // 100 km

        let daten = try TreadmillDataDecoder.dekodiere(bauer.daten)

        XCTAssertEqual(daten.gesamtDistanz, 100_000)
    }

    /// Der Folgefehler: nach der Distanz muss die verstrichene Zeit korrekt liegen.
    /// Wer uint16 liest, bekommt hier 0x0102 statt 600 s — und merkt es erst hier.
    func testFeldNachUint24DistanzLiegtRichtig() throws {
        var bauer = NutzlastBauer()
        bauer.setzeFlag(2)                                   // Total Distance
        bauer.setzeFlag(10)                                  // Elapsed Time
        bauer.uint16(500)
        bauer.uint24(66_051)                                 // 0x010203
        bauer.uint16(600)                                    // 10 min

        let daten = try TreadmillDataDecoder.dekodiere(bauer.daten)

        XCTAssertEqual(daten.gesamtDistanz, 66_051)
        XCTAssertEqual(daten.verstricheneZeit, 600)
        XCTAssertTrue(daten.ueberschuessigeBytes.isEmpty,
                      "Übrige Bytes = Feldbreite falsch")
    }

    // MARK: - Akzeptanzkriterium

    /// Display 5,0 km/h ⇒ Decoder 5,0 ± 0,1.
    func testAkzeptanzkriteriumFuenfKmH() throws {
        var bauer = NutzlastBauer()
        bauer.uint16(500)

        let daten = try TreadmillDataDecoder.dekodiere(bauer.daten)

        XCTAssertEqual(try XCTUnwrap(daten.momentanGeschwindigkeit), 5.0, accuracy: 0.1)
    }

    // MARK: - Vollständiges Paket

    func testAlleFelderVorhanden() throws {
        var bauer = NutzlastBauer()
        for bit in UInt16(1)...12 { bauer.setzeFlag(bit) }   // Bit 0 bleibt 0 = Speed vorhanden

        bauer.uint16(1234)                                   // 12,34 km/h
        bauer.uint16(1100)                                   // 11,00 km/h Ø
        bauer.uint24(12_345)                                 // 12345 m
        bauer.int16(-25)                                     // -2,5 %
        bauer.int16(15)                                      // 1,5°
        bauer.uint16(123)                                    // +12,3 m
        bauer.uint16(45)                                     // -4,5 m
        bauer.uint8(60)                                      // 6,0 km/min
        bauer.uint8(55)                                      // 5,5 km/min Ø
        bauer.uint16(321)                                    // 321 kcal
        bauer.uint16(600)                                    // 600 kcal/h
        bauer.uint8(10)                                      // 10 kcal/min
        bauer.uint8(142)                                     // 142 bpm
        bauer.uint8(95)                                      // 9,5 METs
        bauer.uint16(1800)                                   // 1800 s
        bauer.uint16(600)                                    // 600 s
        bauer.int16(-40)                                     // -40 N
        bauer.int16(250)                                     // 250 W

        let daten = try TreadmillDataDecoder.dekodiere(bauer.daten)

        XCTAssertEqual(daten.flags.rohwert, 0x1FFE)
        XCTAssertEqual(try XCTUnwrap(daten.momentanGeschwindigkeit), 12.34, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(daten.durchschnittGeschwindigkeit), 11.0, accuracy: 0.0001)
        XCTAssertEqual(daten.gesamtDistanz, 12_345)
        XCTAssertEqual(try XCTUnwrap(daten.neigung), -2.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(daten.rampenwinkel), 1.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(daten.hoehengewinnPositiv), 12.3, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(daten.hoehengewinnNegativ), 4.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(daten.momentanPace), 6.0, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(daten.durchschnittPace), 5.5, accuracy: 0.0001)
        XCTAssertEqual(daten.gesamtEnergie, 321)
        XCTAssertEqual(daten.energieProStunde, 600)
        XCTAssertEqual(daten.energieProMinute, 10)
        XCTAssertEqual(daten.herzfrequenz, 142)
        XCTAssertEqual(try XCTUnwrap(daten.metabolischesAequivalent), 9.5, accuracy: 0.0001)
        XCTAssertEqual(daten.verstricheneZeit, 1800)
        XCTAssertEqual(daten.verbleibendeZeit, 600)
        XCTAssertEqual(daten.kraftAufBand, -40)
        XCTAssertEqual(daten.leistung, 250)
        XCTAssertTrue(daten.ueberschuessigeBytes.isEmpty)
    }

    // MARK: - Vorzeichenbehaftete Felder

    func testNegativeNeigungUndLeistung() throws {
        var bauer = NutzlastBauer()
        bauer.setzeFlag(0)                                   // keine Geschwindigkeit
        bauer.setzeFlag(3)
        bauer.setzeFlag(12)
        bauer.int16(-105)                                    // -10,5 %
        bauer.int16(-32)                                     // -3,2°
        bauer.int16(-500)
        bauer.int16(-1)

        let daten = try TreadmillDataDecoder.dekodiere(bauer.daten)

        XCTAssertEqual(try XCTUnwrap(daten.neigung), -10.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(daten.rampenwinkel), -3.2, accuracy: 0.0001)
        XCTAssertEqual(daten.kraftAufBand, -500)
        XCTAssertEqual(daten.leistung, -1)
    }

    // MARK: - Fehlerfälle

    func testLeereNutzlastWirftFlagsUnvollstaendig() {
        XCTAssertThrowsError(try TreadmillDataDecoder.dekodiere(Data())) { fehler in
            XCTAssertEqual(fehler as? FTMSDekodierFehler, .flagsUnvollstaendig(laenge: 0))
        }
    }

    func testEinzelnesByteWirftFlagsUnvollstaendig() {
        XCTAssertThrowsError(try TreadmillDataDecoder.dekodiere(Data([0x00]))) { fehler in
            XCTAssertEqual(fehler as? FTMSDekodierFehler, .flagsUnvollstaendig(laenge: 1))
        }
    }

    /// Flags kündigen die Distanz an, es kommen aber nur 2 der 3 Bytes.
    func testAbgeschnitteneDistanzWirft() {
        var bauer = NutzlastBauer()
        bauer.setzeFlag(0)
        bauer.setzeFlag(2)
        bauer.roh([0x10, 0x27])                              // nur 2 Bytes statt 3

        XCTAssertThrowsError(try TreadmillDataDecoder.dekodiere(bauer.daten)) { fehler in
            XCTAssertEqual(
                fehler as? FTMSDekodierFehler,
                .unerwartetesEnde(feld: "Total Distance", benoetigt: 3, verfuegbar: 2)
            )
        }
    }

    /// Nur Flags, alle Felder abgewählt → gültiges, leeres Paket.
    func testNurFlagsIstGueltig() throws {
        let daten = try TreadmillDataDecoder.dekodiere(Data([0x01, 0x00]))

        XCTAssertNil(daten.momentanGeschwindigkeit)
        XCTAssertNil(daten.gesamtDistanz)
        XCTAssertTrue(daten.ueberschuessigeBytes.isEmpty)
    }

    /// Firmware hängt Bytes an, die die Flags nicht ankündigen → nicht verwerfen, melden.
    func testUeberschuessigeBytesWerdenGemeldet() throws {
        var bauer = NutzlastBauer()
        bauer.uint16(500)
        bauer.roh([0xAA, 0xBB])

        let daten = try TreadmillDataDecoder.dekodiere(bauer.daten)

        XCTAssertEqual(daten.momentanGeschwindigkeit, 5.0)
        XCTAssertEqual(daten.ueberschuessigeBytes, [0xAA, 0xBB])
    }

    // MARK: - Gerätespezifische Skalierung

    /// Falls das Band Geschwindigkeit in 0,1 km/h statt 0,01 km/h liefert.
    func testAbweichendeSkalierung() throws {
        var bauer = NutzlastBauer()
        bauer.uint16(50)

        let daten = try TreadmillDataDecoder.dekodiere(
            bauer.daten,
            skalierung: FTMSSkalierung(geschwindigkeit: 10)
        )

        XCTAssertEqual(try XCTUnwrap(daten.momentanGeschwindigkeit), 5.0, accuracy: 0.0001)
    }

    // MARK: - Hex-Hilfen (für echte Dumps)

    func testHexDekodierung() throws {
        // Flags 0x0000, Speed 0x01F4 = 500 → 5,00 km/h
        let daten = try TreadmillDataDecoder.dekodiere(hex: "00 00 f4 01")

        XCTAssertEqual(daten.momentanGeschwindigkeit, 5.0)
        XCTAssertEqual(daten.rohbytes.hexString, "0000f401")
    }

    func testHexMitTrennzeichenUndPraefix() {
        XCTAssertEqual(Data(hex: "0x00:0f-A1").hexString, "000fa1")
    }
}
