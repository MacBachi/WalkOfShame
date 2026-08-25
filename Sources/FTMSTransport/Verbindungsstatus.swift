import Foundation

/// Zustand der Verbindung zum Laufband.
public enum Verbindungsstatus: Equatable, Sendable {
    case bluetoothAus
    case keineBerechtigung
    case bereit
    case suche
    case verbinde(name: String)
    case verbunden(name: String)
    /// Verbindung verloren — es wird automatisch neu gesucht.
    case getrennt(grund: String)

    public var beschreibung: String {
        switch self {
        case .bluetoothAus: return "Bluetooth ist aus"
        case .keineBerechtigung: return "Keine Bluetooth-Berechtigung"
        case .bereit: return "Bereit"
        case .suche: return "Suche Laufband …"
        case .verbinde(let name): return "Verbinde mit \(name) …"
        case .verbunden(let name): return name
        case .getrennt(let grund): return "Getrennt: \(grund)"
        }
    }

    public var istVerbunden: Bool {
        if case .verbunden = self { return true }
        return false
    }
}

/// Ob die Steuerung (Control Point) freigeschaltet ist.
public enum Steuerstatus: Equatable, Sendable {
    /// Gerät kann nicht gesteuert werden (laut 0x2ACC).
    case nichtVerfuegbar
    /// Steuerung möglich, aber Handshake noch nicht gemacht.
    case nichtAngefordert
    case wirdAngefordert
    case aktiv
    case abgelehnt(grund: String)

    public var beschreibung: String {
        switch self {
        case .nichtVerfuegbar: return "Gerät nicht steuerbar"
        case .nichtAngefordert: return "Steuerung inaktiv"
        case .wirdAngefordert: return "Steuerung wird angefordert …"
        case .aktiv: return "Steuerung aktiv"
        case .abgelehnt(let grund): return "Steuerung abgelehnt: \(grund)"
        }
    }
}
