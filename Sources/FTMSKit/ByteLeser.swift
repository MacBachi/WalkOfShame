import Foundation

/// Fehler beim Dekodieren einer FTMS-Nutzlast.
public enum FTMSDekodierFehler: Error, Equatable, CustomStringConvertible {
    /// Weniger als 2 Bytes — nicht einmal das Flags-Feld ist vollständig.
    case flagsUnvollstaendig(laenge: Int)
    /// Die Nutzlast endet mitten in einem Feld, das laut Flags vorhanden sein müsste.
    case unerwartetesEnde(feld: String, benoetigt: Int, verfuegbar: Int)

    public var description: String {
        switch self {
        case .flagsUnvollstaendig(let laenge):
            return "Flags unvollständig: nur \(laenge) Byte(s) empfangen, mindestens 2 nötig."
        case .unerwartetesEnde(let feld, let benoetigt, let verfuegbar):
            return "Nutzlast endet zu früh bei Feld »\(feld)«: \(benoetigt) Byte(s) nötig, \(verfuegbar) verfügbar."
        }
    }
}

/// Liest Little-Endian-Werte sequenziell aus einem Byte-Puffer.
///
/// Bewusst ohne `withUnsafeBytes`/`load(as:)`: BLE-Nutzlasten sind nicht
/// alignment-garantiert, und uint24 gibt es als Swift-Typ ohnehin nicht.
struct ByteLeser {
    private let bytes: [UInt8]
    private(set) var offset: Int = 0

    init(_ daten: Data) {
        self.bytes = [UInt8](daten)
    }

    /// Noch nicht gelesene Bytes.
    var verbleibend: Int { bytes.count - offset }

    /// Alles, was nach dem letzten dekodierten Feld übrig bleibt.
    var rest: [UInt8] { Array(bytes[offset...]) }

    private mutating func nimm(_ anzahl: Int, feld: String) throws -> ArraySlice<UInt8> {
        guard verbleibend >= anzahl else {
            throw FTMSDekodierFehler.unerwartetesEnde(
                feld: feld, benoetigt: anzahl, verfuegbar: verbleibend
            )
        }
        let stueck = bytes[offset ..< offset + anzahl]
        offset += anzahl
        return stueck
    }

    mutating func uint8(_ feld: String) throws -> UInt8 {
        try nimm(1, feld: feld).first!
    }

    mutating func uint16(_ feld: String) throws -> UInt16 {
        let b = Array(try nimm(2, feld: feld))
        return UInt16(b[0]) | (UInt16(b[1]) << 8)
    }

    /// ⚠️ uint24 — 3 Bytes, little endian. Klassische Bug-Falle bei Total Distance.
    mutating func uint24(_ feld: String) throws -> UInt32 {
        let b = Array(try nimm(3, feld: feld))
        return UInt32(b[0]) | (UInt32(b[1]) << 8) | (UInt32(b[2]) << 16)
    }

    mutating func uint32(_ feld: String) throws -> UInt32 {
        let b = Array(try nimm(4, feld: feld))
        return UInt32(b[0]) | (UInt32(b[1]) << 8) | (UInt32(b[2]) << 16) | (UInt32(b[3]) << 24)
    }

    mutating func int16(_ feld: String) throws -> Int16 {
        Int16(bitPattern: try uint16(feld))
    }
}
