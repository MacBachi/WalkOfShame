import Foundation

/// Befehle für den Fitness Machine Control Point `0x2AD9`.
///
/// Op-Codes und Parameter laut FTMS v1.0, Tabellen 4.15 und 4.16.
/// ⚠️ Diese Befehle bewegen ein Gerät, auf dem ein Mensch steht. Jeder
/// Speed-Befehl gehört hinter eine explizite Bestätigung im UI, und ein
/// Not-Stop (``notStop``) muss jederzeit ohne Rückfrage erreichbar sein.
public enum Steuerbefehl: Equatable, Sendable {
    /// Muss als Erstes gesendet werden — ohne Kontrolle lehnt das Gerät alles ab.
    case kontrolleAnfordern
    /// Setzt die steuerbaren Einstellungen zurück.
    case zuruecksetzen
    /// Zielgeschwindigkeit in km/h.
    case zielGeschwindigkeit(kmH: Double)
    /// Zielneigung in Prozent.
    case zielNeigung(prozent: Double)
    /// Start bzw. Fortsetzen.
    case startOderFortsetzen
    /// Anhalten.
    case stopp
    /// Pausieren.
    case pause

    public var opCode: UInt8 {
        switch self {
        case .kontrolleAnfordern: return 0x00
        case .zuruecksetzen: return 0x01
        case .zielGeschwindigkeit: return 0x02
        case .zielNeigung: return 0x03
        case .startOderFortsetzen: return 0x07
        case .stopp, .pause: return 0x08
        }
    }

    /// Die Bytes, die auf `0x2AD9` geschrieben werden.
    public func nutzlast(skalierung: FTMSSkalierung = .spec) -> Data {
        var bytes: [UInt8] = [opCode]
        switch self {
        case .kontrolleAnfordern, .zuruecksetzen, .startOderFortsetzen:
            break
        case .zielGeschwindigkeit(let kmH):
            let roh = UInt16(max(0, (kmH * skalierung.geschwindigkeit).rounded()))
            bytes += [UInt8(roh & 0xFF), UInt8(roh >> 8)]
        case .zielNeigung(let prozent):
            let roh = Int16((prozent * skalierung.neigung).rounded())
            let ohneVorzeichen = UInt16(bitPattern: roh)
            bytes += [UInt8(ohneVorzeichen & 0xFF), UInt8(ohneVorzeichen >> 8)]
        case .stopp:
            bytes.append(0x01)          // Control Information: Stop
        case .pause:
            bytes.append(0x02)          // Control Information: Pause
        }
        return Data(bytes)
    }

    /// Der Not-Stop. Bewusst als eigener Name, damit im UI unmissverständlich ist,
    /// was der rote Knopf sendet.
    public static let notStop = Steuerbefehl.stopp
}

/// Antwort des Geräts auf `0x2AD9` (kommt per Indication).
public struct Steuerantwort: Equatable, Sendable {
    /// Antworten beginnen laut Spec immer mit 0x80.
    public static let antwortOpCode: UInt8 = 0x80

    public let angefragterOpCode: UInt8
    public let ergebnis: UInt8

    /// Result Codes laut Tabelle 4.24.
    public static let ergebnisTexte: [UInt8: String] = [
        0x01: "Success",
        0x02: "Op Code not supported",
        0x03: "Invalid Parameter",
        0x04: "Operation Failed",
        0x05: "Control Not Permitted"
    ]

    public init?(daten: Data) {
        guard daten.count >= 3, daten[daten.startIndex] == Self.antwortOpCode else { return nil }
        let bytes = [UInt8](daten)
        angefragterOpCode = bytes[1]
        ergebnis = bytes[2]
    }

    public var erfolgreich: Bool { ergebnis == 0x01 }

    public var text: String {
        Self.ergebnisTexte[ergebnis] ?? String(format: "Unbekannt (0x%02X)", ergebnis)
    }
}

/// Prüft Steuerbefehle gegen die vom Gerät gemeldeten Grenzen, **bevor**
/// irgendetwas geschrieben wird.
///
/// Das Gerät würde einen unzulässigen Wert zwar mit »Invalid Parameter«
/// ablehnen — aber sich darauf zu verlassen heißt, dem Gerät zu vertrauen,
/// während jemand darauf steht. Wir prüfen selbst.
public struct Steuerungsgrenzen: Sendable {
    public let geschwindigkeit: UnterstuetzteGeschwindigkeit?
    public let neigung: UnterstuetzteNeigung?
    public let merkmale: FitnessMachineFeature?

    public init(geschwindigkeit: UnterstuetzteGeschwindigkeit?,
                neigung: UnterstuetzteNeigung?,
                merkmale: FitnessMachineFeature?) {
        self.geschwindigkeit = geschwindigkeit
        self.neigung = neigung
        self.merkmale = merkmale
    }

    public enum Ablehnung: Error, Equatable, CustomStringConvertible {
        case nichtUnterstuetzt(String)
        case ausserhalbBereich(wert: Double, minimum: Double, maximum: Double)
        case grenzenUnbekannt(String)

        public var description: String {
            switch self {
            case .nichtUnterstuetzt(let was):
                return "\(was) wird von diesem Gerät nicht unterstützt."
            case .ausserhalbBereich(let wert, let minimum, let maximum):
                return String(format: "%.2f liegt außerhalb von %.2f–%.2f.", wert, minimum, maximum)
            case .grenzenUnbekannt(let was):
                return "Grenzen für \(was) sind noch nicht gelesen — kein Befehl ohne Grenzen."
            }
        }
    }

    /// Wirft, wenn der Befehl nicht gesendet werden darf.
    public func pruefe(_ befehl: Steuerbefehl) throws {
        switch befehl {
        case .zielGeschwindigkeit(let kmH):
            if let merkmale, !merkmale.geschwindigkeitSteuerbar {
                throw Ablehnung.nichtUnterstuetzt("Geschwindigkeitssteuerung")
            }
            guard let bereich = geschwindigkeit else {
                throw Ablehnung.grenzenUnbekannt("Geschwindigkeit")
            }
            guard bereich.erlaubt(kmH) else {
                throw Ablehnung.ausserhalbBereich(
                    wert: kmH, minimum: bereich.minimum, maximum: bereich.maximum
                )
            }

        case .zielNeigung(let prozent):
            if let merkmale, !merkmale.neigungSteuerbar {
                throw Ablehnung.nichtUnterstuetzt("Neigungssteuerung")
            }
            guard let bereich = neigung, bereich.verstellbar else {
                throw Ablehnung.nichtUnterstuetzt("Neigungssteuerung")
            }
            guard prozent >= bereich.minimum, prozent <= bereich.maximum else {
                throw Ablehnung.ausserhalbBereich(
                    wert: prozent, minimum: bereich.minimum, maximum: bereich.maximum
                )
            }

        // Anhalten, Pausieren und Zurücksetzen sind immer erlaubt — ein Not-Stop
        // darf nie an einer Bereichsprüfung scheitern.
        case .kontrolleAnfordern, .zuruecksetzen, .startOderFortsetzen, .stopp, .pause:
            break
        }
    }
}
