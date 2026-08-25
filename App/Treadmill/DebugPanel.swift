import SwiftUI
import FTMSKit
import FTMSTransport

/// Raw-Hex-Panel. Ohne die Rohbytes ist ein Parser-Bug nicht auffindbar —
/// deshalb ist dieses Panel kein Wegwerf-Feature, sondern bleibt in der App.
struct DebugPanel: View {
    @ObservedObject var verbindung: LaufbandVerbindung
    @EnvironmentObject private var sprachen: Sprachverwaltung

    private var texte: Texte { sprachen.texte }

    var body: some View {
        List {
            Section(texte.geraet) {
                if let merkmale = verbindung.merkmale {
                    LabeledContent(texte.meldet,
                                   value: merkmale.unterstuetzteMerkmale.joined(separator: ", "))
                    LabeledContent(texte.steuerbar,
                                   value: merkmale.unterstuetzteZielwerte.isEmpty
                                        ? "—" : merkmale.unterstuetzteZielwerte.joined(separator: ", "))
                }
                if let bereich = verbindung.geschwindigkeitsbereich {
                    LabeledContent(texte.geschwindigkeit, value: String(
                        format: "%.2f–%.2f km/h (%.2f)",
                        bereich.minimum, bereich.maximum, bereich.schrittweite))
                }
                if let status = verbindung.trainingStatus {
                    LabeledContent(texte.trainingStatus, value: status.bezeichnung)
                }
            }

            if let daten = verbindung.letzteDaten {
                Section(texte.letztesPaket) {
                    LabeledContent(texte.flags,
                                   value: String(format: "0x%04X", daten.flags.rohwert))
                    LabeledContent(texte.rohbytes, value: daten.rohbytes.hexString)
                        .font(.system(.caption, design: .monospaced))
                    if !daten.ueberschuessigeBytes.isEmpty {
                        LabeledContent(texte.uebrigeBytes,
                                       value: Data(daten.ueberschuessigeBytes).hexString)
                            .foregroundStyle(.orange)
                    }
                    if !daten.nichtVerfuegbareFelder.isEmpty {
                        LabeledContent(texte.nichtVerfuegbar,
                                       value: daten.nichtVerfuegbareFelder.joined(separator: ", "))
                    }
                }
            }

            Section("\(texte.rohprotokoll) (\(verbindung.rohLog.eintraege.count))") {
                ForEach(verbindung.rohLog.eintraege.reversed()) { eintrag in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(eintrag.quelle).font(.caption.weight(.semibold))
                            Spacer()
                            Text(eintrag.zeit, style: .time)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(eintrag.hex)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        if let fehler = eintrag.fehler {
                            Text(fehler).font(.caption2).foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle(texte.debug)
        .toolbar {
            ShareLink(item: verbindung.rohLog.alsText) {
                Label(texte.logTeilen, systemImage: "square.and.arrow.up")
            }
        }
    }
}
