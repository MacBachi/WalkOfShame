import Foundation
import FTMSKit

/// Eine Zeile im Sitzungsprotokoll.
public struct SitzungsZeile: Codable, Equatable, Sendable {
    public let zeit: Date
    /// Rohbytes der Notification — die Wahrheit, aus der sich alles neu
    /// berechnen lässt, falls der Decoder später korrigiert wird.
    public let hex: String
    public let distanzMeter: Double
    public let energieKcal: Double
    public let dauer: TimeInterval
    public let geschwindigkeit: Double?
    public let herzfrequenz: UInt8?
}

/// Schreibt den Sitzungsverlauf **laufend** als append-only JSONL.
///
/// Bewusst nicht erst am Ende: ein App-Kill mitten im Workout darf maximal
/// Sekunden kosten, nicht die ganze Session. Jede Zeile wird sofort in die
/// Datei geschrieben; ein halb geschriebener Datensatz kostet genau eine Zeile,
/// die beim Einlesen übersprungen wird.
public final class SitzungsSpeicher {
    private let handle: FileHandle
    private let kodierer = JSONEncoder()
    public let pfad: URL

    /// - Parameter ordner: Default ist das Documents-Verzeichnis der App.
    public init(ordner: URL? = nil, name: String? = nil) throws {
        let ziel = try ordner ?? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("sitzungen", isDirectory: true)

        try FileManager.default.createDirectory(at: ziel, withIntermediateDirectories: true)

        let stempel = ISO8601DateFormatter()
        stempel.formatOptions = [.withFullDate, .withTime]
        let dateiname = name ?? "sitzung-" + stempel.string(from: Date())
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "") + ".jsonl"

        pfad = ziel.appendingPathComponent(dateiname)
        if !FileManager.default.fileExists(atPath: pfad.path) {
            FileManager.default.createFile(atPath: pfad.path, contents: nil)
        }
        handle = try FileHandle(forWritingTo: pfad)
        try handle.seekToEnd()
        kodierer.dateEncodingStrategy = .iso8601
    }

    public func schreibe(_ zeile: SitzungsZeile) {
        guard let daten = try? kodierer.encode(zeile) else { return }
        handle.write(daten)
        handle.write(Data("\n".utf8))
    }

    public func schliesse() {
        try? handle.close()
    }

    deinit {
        try? handle.close()
    }

    /// Liest eine Sitzungsdatei zurück. Kaputte Zeilen (abgeschnitten durch einen
    /// Kill mitten im Schreiben) werden übersprungen, nicht als Fehler gewertet.
    public static func lies(_ pfad: URL) throws -> [SitzungsZeile] {
        let dekodierer = JSONDecoder()
        dekodierer.dateDecodingStrategy = .iso8601
        let inhalt = try String(contentsOf: pfad, encoding: .utf8)
        return inhalt.split(separator: "\n").compactMap { zeile in
            try? dekodierer.decode(SitzungsZeile.self, from: Data(zeile.utf8))
        }
    }

    /// Alle gespeicherten Sitzungen, neueste zuerst.
    public static func alleSitzungen(in ordner: URL? = nil) throws -> [URL] {
        let ziel = try ordner ?? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("sitzungen", isDirectory: true)

        guard FileManager.default.fileExists(atPath: ziel.path) else { return [] }
        let dateien = try FileManager.default.contentsOfDirectory(
            at: ziel, includingPropertiesForKeys: [.contentModificationDateKey]
        ).filter { $0.pathExtension == "jsonl" }

        return dateien.sorted { links, rechts in
            let a = (try? links.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            let b = (try? rechts.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return a > b
        }
    }
}
