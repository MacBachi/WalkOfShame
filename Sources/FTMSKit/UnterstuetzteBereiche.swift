import Foundation

/// Supported Speed Range `0x2AD4` — 3× uint16: Minimum, Maximum, Minimum Increment,
/// jeweils in 0,01 km/h.
///
/// Liefert die harten Grenzen für Phase 6 (Steuerung): ein Zielwert außerhalb
/// dieses Bereichs darf gar nicht erst gesendet werden.
public struct UnterstuetzteGeschwindigkeit: Equatable, Sendable {
    public let minimum: Double
    public let maximum: Double
    public let schrittweite: Double

    public init?(daten: Data, skalierung: FTMSSkalierung = .spec) {
        guard daten.count >= 6 else { return nil }
        var leser = ByteLeser(daten)
        guard let min = try? leser.uint16("Minimum Speed"),
              let max = try? leser.uint16("Maximum Speed"),
              let inkrement = try? leser.uint16("Minimum Increment") else { return nil }
        minimum = Double(min) / skalierung.geschwindigkeit
        maximum = Double(max) / skalierung.geschwindigkeit
        schrittweite = Double(inkrement) / skalierung.geschwindigkeit
    }

    /// Liegt der Zielwert im erlaubten Bereich?
    public func erlaubt(_ kmH: Double) -> Bool {
        kmH >= minimum && kmH <= maximum
    }
}

/// Supported Inclination Range `0x2AD5` — sint16 Minimum, sint16 Maximum,
/// uint16 Minimum Increment, jeweils in 0,1 %.
public struct UnterstuetzteNeigung: Equatable, Sendable {
    public let minimum: Double
    public let maximum: Double
    public let schrittweite: Double

    public init?(daten: Data, skalierung: FTMSSkalierung = .spec) {
        guard daten.count >= 6 else { return nil }
        var leser = ByteLeser(daten)
        guard let min = try? leser.int16("Minimum Inclination"),
              let max = try? leser.int16("Maximum Inclination"),
              let inkrement = try? leser.uint16("Minimum Increment") else { return nil }
        minimum = Double(min) / skalierung.neigung
        maximum = Double(max) / skalierung.neigung
        schrittweite = Double(inkrement) / skalierung.neigung
    }

    /// Min == Max == 0 heißt: das Gerät hat gar keine verstellbare Neigung.
    public var verstellbar: Bool { minimum != maximum }
}

/// Supported Heart Rate Range `0x2AD7` — 3× uint8 in bpm.
public struct UnterstuetzteHerzfrequenz: Equatable, Sendable {
    public let minimum: UInt8
    public let maximum: UInt8
    public let schrittweite: UInt8

    public init?(daten: Data) {
        guard daten.count >= 3 else { return nil }
        var leser = ByteLeser(daten)
        guard let min = try? leser.uint8("Minimum Heart Rate"),
              let max = try? leser.uint8("Maximum Heart Rate"),
              let inkrement = try? leser.uint8("Minimum Increment") else { return nil }
        minimum = min
        maximum = max
        schrittweite = inkrement
    }
}
