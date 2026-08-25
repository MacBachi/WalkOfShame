import Foundation

/// Umrechnungs-Teiler von Rohwert → Anzeigeeinheit.
///
/// Default = Bluetooth-SIG-Spec. Falls das Gerät abweicht (China-Firmware hält
/// sich oft nur teilweise an den Standard), hier gerätespezifisch überschreiben,
/// statt im Decoder zu fummeln.
public struct FTMSSkalierung: Equatable, Sendable {
    /// Rohwert / 100 → km/h
    public var geschwindigkeit: Double
    /// Rohwert / 10 → Prozent bzw. Grad
    public var neigung: Double
    /// Rohwert / 10 → Meter
    public var hoehengewinn: Double
    /// Rohwert / 10 → km/min
    public var pace: Double
    /// Rohwert / 10 → METs
    public var metabolischesAequivalent: Double

    public init(
        geschwindigkeit: Double = 100,
        neigung: Double = 10,
        hoehengewinn: Double = 10,
        pace: Double = 10,
        metabolischesAequivalent: Double = 10
    ) {
        self.geschwindigkeit = geschwindigkeit
        self.neigung = neigung
        self.hoehengewinn = hoehengewinn
        self.pace = pace
        self.metabolischesAequivalent = metabolischesAequivalent
    }

    /// Auflösungen laut Bluetooth SIG FTMS v1.0.
    public static let spec = FTMSSkalierung()
}
