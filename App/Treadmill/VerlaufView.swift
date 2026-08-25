import SwiftUI
import FTMSKit
import FTMSTransport

/// Aufgezeichnete Einheiten und ihre Auswertung.
///
/// Darf scrollen — im Gegensatz zum Hauptbildschirm. Beim Blättern durch die
/// Historie steht niemand auf dem Band.
struct VerlaufView: View {
    @EnvironmentObject private var sprachen: Sprachverwaltung

    @State private var einheiten: [Sitzungszusammenfassung] = []
    @State private var zeigeStatistik = false
    @State private var laedt = true

    private var texte: Texte { sprachen.texte }

    var body: some View {
        Group {
            if zeigeStatistik {
                StatistikView(einheiten: einheiten)
            } else {
                liste
            }
        }
        .navigationTitle(zeigeStatistik ? texte.statistik : texte.verlauf)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Picker("", selection: $zeigeStatistik) {
                    Image(systemName: "list.bullet").tag(false)
                    Image(systemName: "chart.bar").tag(true)
                }
                .pickerStyle(.segmented)
            }
        }
        .task {
            let geladen = await Task.detached(priority: .userInitiated) {
                Sitzungsarchiv.alleZusammenfassungen()
            }.value
            einheiten = geladen
            laedt = false
        }
    }

    /// Entfernt die Rohdateien der gewischten Zeilen.
    private func loesche(_ positionen: IndexSet) {
        let betroffene = positionen.map { einheiten[$0] }
        for einheit in betroffene {
            Sitzungsarchiv.loesche(einheit.pfad)
        }
        einheiten.remove(atOffsets: positionen)
    }

    @ViewBuilder
    private var liste: some View {
        if laedt {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if einheiten.isEmpty {
            ContentUnavailableErsatz(text: texte.keineEinheiten)
        } else {
            List {
                Section {
                    ForEach(einheiten) { einheit in
                        NavigationLink {
                            SitzungsDetailView(einheit: einheit)
                        } label: {
                            Zeile(einheit: einheit, texte: texte)
                        }
                    }
                    .onDelete(perform: loesche)
                } footer: {
                    Text(texte.loeschHinweis)
                }
            }
        }
    }
}

/// `ContentUnavailableView` gibt es erst ab iOS 17 — das Ziel ist ein iPhone 8.
struct ContentUnavailableErsatz: View {
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct Zeile: View {
    let einheit: Sitzungszusammenfassung
    let texte: Texte

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(einheit.beginn, format: .dateTime.day().month().year().hour().minute())
                .font(.subheadline.weight(.medium))
            HStack(spacing: 12) {
                Beschriftung(wert: texte.zahl(einheit.distanzKilometer, 2) + " km")
                Beschriftung(wert: dauerText(einheit.dauer))
                Beschriftung(wert: "⌀ " + texte.zahl(einheit.durchschnittsgeschwindigkeit) + " km/h")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func dauerText(_ sekunden: TimeInterval) -> String {
        let ganze = Int(sekunden)
        return ganze >= 3600
            ? String(format: "%d:%02d:%02d", ganze / 3600, (ganze % 3600) / 60, ganze % 60)
            : String(format: "%d:%02d", ganze / 60, ganze % 60)
    }
}

private struct Beschriftung: View {
    let wert: String
    var body: some View { Text(wert).monospacedDigit() }
}
