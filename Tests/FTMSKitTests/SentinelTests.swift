import XCTest
@testable import FTMSKit

/// FTMS v1.0 definiert für mehrere Felder einen »Data Not Available«-Sentinel.
/// Ohne Behandlung liefert der Decoder 3276,7 % Steigung als echten Messwert.
final class SentinelTests: XCTestCase {

    func testNeigungSentinelWirdNichtAlsMesswertGeliefert() throws {
        var bauer = NutzlastBauer()
        bauer.setzeFlag(0)
        bauer.setzeFlag(3)
        bauer.int16(0x7FFF)                                  // Inclination n/a
        bauer.int16(15)                                      // Ramp Angle 1,5° gültig

        let daten = try TreadmillDataDecoder.dekodiere(bauer.daten)

        XCTAssertNil(daten.neigung)
        XCTAssertEqual(try XCTUnwrap(daten.rampenwinkel), 1.5, accuracy: 0.0001)
        XCTAssertEqual(daten.nichtVerfuegbareFelder, ["Inclination"])
        XCTAssertTrue(daten.ueberschuessigeBytes.isEmpty, "Bytes müssen trotzdem konsumiert werden")
    }

    func testEnergieSentinel() throws {
        var bauer = NutzlastBauer()
        bauer.setzeFlag(0)
        bauer.setzeFlag(7)
        bauer.uint16(0xFFFF)                                 // Total Energy n/a
        bauer.uint16(0xFFFF)                                 // Energy per Hour n/a
        bauer.uint8(0xFF)                                    // Energy per Minute n/a

        let daten = try TreadmillDataDecoder.dekodiere(bauer.daten)

        XCTAssertNil(daten.gesamtEnergie)
        XCTAssertNil(daten.energieProStunde)
        XCTAssertNil(daten.energieProMinute)
        XCTAssertEqual(daten.nichtVerfuegbareFelder,
                       ["Total Energy", "Energy per Hour", "Energy per Minute"])
    }

    func testKraftUndLeistungSentinel() throws {
        var bauer = NutzlastBauer()
        bauer.setzeFlag(0)
        bauer.setzeFlag(12)
        bauer.int16(0x7FFF)
        bauer.int16(250)

        let daten = try TreadmillDataDecoder.dekodiere(bauer.daten)

        XCTAssertNil(daten.kraftAufBand)
        XCTAssertEqual(daten.leistung, 250)
        XCTAssertEqual(daten.nichtVerfuegbareFelder, ["Force on Belt"])
    }

    /// Gegenprobe: 32766 ist ein gültiger Wert, kein Sentinel.
    func testKnappUnterSentinelBleibtMesswert() throws {
        var bauer = NutzlastBauer()
        bauer.setzeFlag(0)
        bauer.setzeFlag(12)
        bauer.int16(32766)
        bauer.int16(0)

        let daten = try TreadmillDataDecoder.dekodiere(bauer.daten)

        XCTAssertEqual(daten.kraftAufBand, 32766)
        XCTAssertTrue(daten.nichtVerfuegbareFelder.isEmpty)
    }
}
