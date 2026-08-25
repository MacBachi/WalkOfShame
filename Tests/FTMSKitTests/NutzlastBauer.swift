import Foundation

/// Baut synthetische `0x2ACD`-Nutzlasten — Little Endian, Feldreihenfolge = Bitreihenfolge.
///
/// Bewusst *unabhängig* vom Decoder implementiert (eigener Byte-Aufbau), damit
/// ein Bug im Decoder nicht durch denselben Bug im Testhelfer maskiert wird.
struct NutzlastBauer {
    private var flags: UInt16 = 0
    private var nutzdaten: [UInt8] = []

    /// Bit 0 ist invertiert: gesetzt = Momentangeschwindigkeit **fehlt**.
    mutating func setzeFlag(_ bit: UInt16) {
        flags |= (1 << bit)
    }

    mutating func uint8(_ wert: UInt8) {
        nutzdaten.append(wert)
    }

    mutating func uint16(_ wert: UInt16) {
        nutzdaten.append(UInt8(wert & 0xFF))
        nutzdaten.append(UInt8((wert >> 8) & 0xFF))
    }

    mutating func uint24(_ wert: UInt32) {
        nutzdaten.append(UInt8(wert & 0xFF))
        nutzdaten.append(UInt8((wert >> 8) & 0xFF))
        nutzdaten.append(UInt8((wert >> 16) & 0xFF))
    }

    mutating func int16(_ wert: Int16) {
        uint16(UInt16(bitPattern: wert))
    }

    mutating func roh(_ bytes: [UInt8]) {
        nutzdaten.append(contentsOf: bytes)
    }

    var daten: Data {
        Data([UInt8(flags & 0xFF), UInt8((flags >> 8) & 0xFF)] + nutzdaten)
    }
}
