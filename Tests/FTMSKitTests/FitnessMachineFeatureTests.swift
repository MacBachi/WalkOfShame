import XCTest
@testable import FTMSKit

/// Bit-Namen laut FTMS v1.0, Tabellen 4.3 und 4.4.
final class FitnessMachineFeatureTests: XCTestCase {

    func testTypischesLaufband() throws {
        // Merkmale: Average Speed(0), Total Distance(2), Inclination(3),
        //           Expended Energy(9), Heart Rate(10), Elapsed Time(12) = 0x0000160D
        // Zielwerte: Speed(0), Inclination(1) = 0x00000003
        let daten = Data(hex: "0d16000003000000")
        let merkmale = try XCTUnwrap(FitnessMachineFeature(daten: daten))

        XCTAssertEqual(merkmale.merkmale, 0x0000_160D)
        XCTAssertEqual(merkmale.unterstuetzteMerkmale, [
            "Average Speed", "Total Distance", "Inclination",
            "Expended Energy", "Heart Rate Measurement", "Elapsed Time"
        ])
        XCTAssertEqual(merkmale.unterstuetzteZielwerte,
                       ["Speed Target Setting", "Inclination Target Setting"])
        XCTAssertTrue(merkmale.geschwindigkeitSteuerbar)
        XCTAssertTrue(merkmale.neigungSteuerbar)
    }

    func testGeraetOhneSteuerung() throws {
        let merkmale = try XCTUnwrap(FitnessMachineFeature(daten: Data(hex: "0100000000000000")))

        XCTAssertEqual(merkmale.unterstuetzteMerkmale, ["Average Speed"])
        XCTAssertTrue(merkmale.unterstuetzteZielwerte.isEmpty)
        XCTAssertFalse(merkmale.geschwindigkeitSteuerbar)
    }

    func testHoechstesDefiniertesBit() throws {
        // Bit 16 in beiden Feldern: User Data Retention / Targeted Cadence Configuration
        let merkmale = try XCTUnwrap(FitnessMachineFeature(daten: Data(hex: "0000010000000100")))

        XCTAssertEqual(merkmale.unterstuetzteMerkmale, ["User Data Retention"])
        XCTAssertEqual(merkmale.unterstuetzteZielwerte, ["Targeted Cadence Configuration"])
    }

    /// Reserved-Bits 17–31 haben keinen Namen und dürfen nicht crashen.
    func testReservierteBitsWerdenIgnoriert() throws {
        let merkmale = try XCTUnwrap(FitnessMachineFeature(daten: Data(hex: "0000008000000080")))

        XCTAssertTrue(merkmale.unterstuetzteMerkmale.isEmpty)
    }

    func testZuKurzeNutzlast() {
        XCTAssertNil(FitnessMachineFeature(daten: Data(hex: "0d160000")))
    }
}
