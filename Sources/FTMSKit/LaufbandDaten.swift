import Foundation

/// Ein dekodiertes `0x2ACD`-Notification-Paket.
///
/// Alle Felder sind optional: FTMS überträgt pro Paket nur, was die Flags ankündigen.
/// Einheiten sind bereits in SI/Alltag umgerechnet (nicht mehr in Spec-Rohauflösung).
public struct LaufbandDaten: Equatable, Sendable {
    public let flags: TreadmillFlags

    /// km/h
    public var momentanGeschwindigkeit: Double?
    /// km/h
    public var durchschnittGeschwindigkeit: Double?
    /// Meter (uint24 in der Nutzlast)
    public var gesamtDistanz: UInt32?
    /// Prozent
    public var neigung: Double?
    /// Grad
    public var rampenwinkel: Double?
    /// Meter
    public var hoehengewinnPositiv: Double?
    /// Meter
    public var hoehengewinnNegativ: Double?
    /// km/min
    public var momentanPace: Double?
    /// km/min
    public var durchschnittPace: Double?
    /// kcal
    public var gesamtEnergie: UInt16?
    /// kcal/h
    public var energieProStunde: UInt16?
    /// kcal/min
    public var energieProMinute: UInt8?
    /// bpm
    public var herzfrequenz: UInt8?
    /// dimensionslos (METs)
    public var metabolischesAequivalent: Double?
    /// Sekunden
    public var verstricheneZeit: UInt16?
    /// Sekunden
    public var verbleibendeZeit: UInt16?
    /// Newton
    public var kraftAufBand: Int16?
    /// Watt
    public var leistung: Int16?

    /// Rohbytes der Notification — für das Debug-Hex-Panel und Bug-Forensik.
    public var rohbytes: Data
    /// Bytes, die nach dem letzten laut Flags erwarteten Feld übrig blieben.
    /// Nicht leer = Firmware weicht von der Spec ab. Unbedingt loggen.
    public var ueberschuessigeBytes: [UInt8]
    /// Felder, die laut Flags vorhanden waren, aber den Spec-Sentinel
    /// »Data Not Available« trugen (z. B. 0x7FFF bei Inclination).
    /// Das zugehörige Property ist dann `nil` — die Bytes wurden trotzdem gelesen.
    public var nichtVerfuegbareFelder: [String]

    init(flags: TreadmillFlags, rohbytes: Data) {
        self.flags = flags
        self.rohbytes = rohbytes
        self.ueberschuessigeBytes = []
        self.nichtVerfuegbareFelder = []
    }
}
