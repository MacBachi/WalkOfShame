import Foundation

/// Flags-Feld der Treadmill Data Characteristic `0x2ACD` (uint16, little endian).
///
/// Reihenfolge der Felder in der Nutzlast entspricht exakt der Bit-Reihenfolge.
public struct TreadmillFlags: Equatable, Sendable {
    public let rohwert: UInt16

    public init(rohwert: UInt16) {
        self.rohwert = rohwert
    }

    private func bit(_ index: UInt16) -> Bool {
        (rohwert >> index) & 1 == 1
    }

    /// ⚠️ Bit 0 ist **invertiert** ("More Data"): Bit = 0 bedeutet *vorhanden*.
    public var momentanGeschwindigkeitVorhanden: Bool { !bit(0) }

    public var durchschnittGeschwindigkeitVorhanden: Bool { bit(1) }
    public var gesamtDistanzVorhanden: Bool { bit(2) }
    public var neigungUndRampenwinkelVorhanden: Bool { bit(3) }
    public var hoehengewinnVorhanden: Bool { bit(4) }
    public var momentanPaceVorhanden: Bool { bit(5) }
    public var durchschnittPaceVorhanden: Bool { bit(6) }
    public var energieVorhanden: Bool { bit(7) }
    public var herzfrequenzVorhanden: Bool { bit(8) }
    public var metabolischesAequivalentVorhanden: Bool { bit(9) }
    public var verstricheneZeitVorhanden: Bool { bit(10) }
    public var verbleibendeZeitVorhanden: Bool { bit(11) }
    public var kraftUndLeistungVorhanden: Bool { bit(12) }
}
