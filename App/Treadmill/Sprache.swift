import Foundation
import Combine

/// Die zwei Sprachen der App. Englisch ist durchgehend **britisch**.
enum Sprache: String, Sendable {
    case deutsch
    case englisch
}

/// Was in den Einstellungen gewählt werden kann.
enum Sprachwahl: String, CaseIterable, Identifiable, Sendable {
    /// Richtet sich nach der Systemsprache.
    case automatisch
    case deutsch
    case englisch

    var id: String { rawValue }
}

/// Löst die Sprachwahl gegen die Systemeinstellung auf und hält sie fest.
///
/// Bewusst kein `.strings`-Bundle: die Sprache soll zur Laufzeit umschaltbar
/// sein, ohne die App neu zu starten. Ein `Bundle`-Austausch dafür wäre ein
/// Hack, ein typisierter Katalog ist prüfbar — fehlt eine Übersetzung, merkt es
/// der Compiler und nicht der Nutzer.
final class Sprachverwaltung: ObservableObject {

    @Published var wahl: Sprachwahl {
        didSet { UserDefaults.standard.set(wahl.rawValue, forKey: Self.schluessel) }
    }

    static let schluessel = "sprachwahl"

    init(wahl: Sprachwahl? = nil) {
        if let wahl {
            self.wahl = wahl
        } else {
            let gespeichert = UserDefaults.standard.string(forKey: Self.schluessel)
            self.wahl = gespeichert.flatMap(Sprachwahl.init(rawValue:)) ?? .automatisch
        }
    }

    var sprache: Sprache {
        Self.loese(wahl, systemsprachen: Locale.preferredLanguages)
    }

    var texte: Texte {
        sprache == .deutsch ? .deutsch : .englisch
    }

    /// ISO-639-Codes für deutsche Sprachvarianten. »de« deckt de-AT, de-CH und
    /// de-DE ab; die übrigen sind eigenständige Codes für deutsche Dialekte:
    /// Schweizerdeutsch, Bairisch, Niederdeutsch, Kölsch, Schwäbisch,
    /// Walserdeutsch, Pfälzisch, Schlesisch, Obersächsisch.
    static let deutscheCodes = ["de", "gsw", "bar", "nds", "ksh", "swg", "wae",
                                "pfl", "sli", "sxu"]

    /// Deutsch nur, wenn die Systemsprache Deutsch oder ein deutscher Dialekt
    /// ist — sonst Englisch.
    static func loese(_ wahl: Sprachwahl, systemsprachen: [String]) -> Sprache {
        switch wahl {
        case .deutsch: return .deutsch
        case .englisch: return .englisch
        case .automatisch:
            guard let bevorzugt = systemsprachen.first else { return .englisch }
            let basis = bevorzugt.split(separator: "-").first.map(String.init) ?? bevorzugt
            return deutscheCodes.contains(basis.lowercased()) ? .deutsch : .englisch
        }
    }
}
