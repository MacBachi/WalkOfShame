import Foundation

/// Ein Ereignis im Dump-Protokoll. Wird als JSONL geschrieben — eine Zeile pro
/// Ereignis, sofort geflusht, damit ein Abbruch nichts kostet.
struct DumpEreignis: Codable {
    let zeit: Date
    let art: String
    let text: String
    /// Rohbytes als Hex, falls es sich um Characteristic-Daten handelt.
    var hex: String?
    /// z. B. "2ACD#0" — Instanz-Kennung, falls die Characteristic mehrfach vorkommt.
    var quelle: String?
    /// Dekodierte Felder, falls dekodierbar.
    var dekodiert: [String: String]?
}

/// Schreibt Ereignisse gleichzeitig auf stdout (lesbar) und in eine JSONL-Datei.
final class DumpProtokoll {
    private let handle: FileHandle
    private let kodierer = JSONEncoder()
    let pfad: URL

    init() throws {
        let ordner = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("dumps")
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)

        let stempel = ISO8601DateFormatter()
        stempel.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let name = "ftms-" + stempel.string(from: Date())
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "") + ".jsonl"

        pfad = ordner.appendingPathComponent(name)
        FileManager.default.createFile(atPath: pfad.path, contents: nil)
        handle = try FileHandle(forWritingTo: pfad)
        kodierer.dateEncodingStrategy = .iso8601
    }

    func schreibe(_ ereignis: DumpEreignis) {
        var zeile = ereignis.art.uppercased().padding(toLength: 9, withPad: " ", startingAt: 0)
        zeile += ereignis.text
        if let quelle = ereignis.quelle { zeile += "  [\(quelle)]" }
        if let hex = ereignis.hex { zeile += "  hex=\(hex)" }
        print(zeile)
        if let dekodiert = ereignis.dekodiert, !dekodiert.isEmpty {
            let felder = dekodiert.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }.joined(separator: "  ")
            print("          └─ \(felder)")
        }

        if let daten = try? kodierer.encode(ereignis) {
            handle.write(daten)
            handle.write(Data("\n".utf8))
        }
    }

    func melde(_ art: String, _ text: String) {
        schreibe(DumpEreignis(zeit: Date(), art: art, text: text))
    }

    func schliesse() {
        try? handle.close()
    }
}
