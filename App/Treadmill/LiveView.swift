import SwiftUI
import FTMSKit
import FTMSTransport

/// Hauptbildschirm während des Trainings.
///
/// **Darf nie scrollen** — in keiner Orientierung. Deshalb: feste Aufteilung,
/// keine `ScrollView`, alle Texte mit `minimumScaleFactor`, und ein eigenes
/// Layout für Querformat (`verticalSizeClass == .compact`). Einstellungen und
/// Rohdaten liegen bewusst hinter der Toolbar, nicht auf dieser Seite.
struct LiveView: View {
    @ObservedObject var steuerung: SitzungsSteuerung
    @EnvironmentObject private var sprachen: Sprachverwaltung
    @AppStorage("debugAktiv") private var debugAktiv = false
    @Environment(\.verticalSizeClass) private var hoehenklasse

    private var texte: Texte { sprachen.texte }

    private var verbindung: LaufbandVerbindung { steuerung.verbindung }
    private var quer: Bool { hoehenklasse == .compact }

    var body: some View {
        NavigationStack {
            Group {
                if quer { querformat } else { hochformat }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(texte.titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink { SteuerungsView(verbindung: verbindung) } label: {
                        Label(texte.steuerung, systemImage: "slider.horizontal.3")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { VerlaufView() } label: {
                        Label(texte.verlauf, systemImage: "chart.xyaxis.line")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { EinstellungenView(steuerung: steuerung) } label: {
                        Label(texte.einstellungen, systemImage: "gearshape")
                    }
                }
            }
            .onAppear {
                verbindung.protokollModus = debugAktiv ? .alles : .nurAuffaellige
            }
        }
    }

    // MARK: - Aufteilungen

    private var hochformat: some View {
        VStack(spacing: 10) {
            kopfzeile
            Spacer(minLength: 0)
            GrosserWert(wert: geschwindigkeitstext, einheit: texte.geschwindigkeitseinheit, schriftgroesse: 76)
            Spacer(minLength: 0)
            kacheln(spalten: 2)
            Sitzungsknoepfe(steuerung: steuerung, texte: texte)
            hinweiszeile
        }
    }

    private var querformat: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                kopfzeile
                Spacer(minLength: 0)
                GrosserWert(wert: geschwindigkeitstext, einheit: texte.geschwindigkeitseinheit, schriftgroesse: 60)
                Spacer(minLength: 0)
                hinweiszeile
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                kacheln(spalten: 2)
                Sitzungsknoepfe(steuerung: steuerung, texte: texte)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Bausteine

    private var kopfzeile: some View {
        VStack(spacing: 4) {
            Verbindungszeile(text: texte.verbindungstext(verbindung.status), status: verbindung.status)
            Trainingszeile(steuerung: steuerung, texte: texte)
        }
    }

    private var geschwindigkeitstext: String {
        verbindung.stand.letzteGeschwindigkeit.map { texte.zahl($0) } ?? "–"
    }

    private func kacheln(spalten: Int) -> some View {
        let werte = [
            (texte.distanz, texte.zahl(verbindung.stand.distanzKilometer, 2), texte.kilometer),
            (texte.zeit, steuerung.dauerText, ""),
            (texte.kalorien, String(Int(verbindung.stand.energieKcal)), texte.kilokalorien),
            (texte.puls, pulstext, texte.schlaegeProMinute)
        ]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                        count: spalten), spacing: 8) {
            ForEach(werte, id: \.0) { titel, wert, einheit in
                Kachel(titel: titel, wert: wert, einheit: einheit)
            }
        }
    }

    private var pulstext: String {
        guard let bpm = verbindung.letzteDaten?.herzfrequenz, bpm > 0 else { return "–" }
        return String(bpm)
    }

    /// Immer nur **eine** Meldung, damit die Höhe planbar bleibt.
    @ViewBuilder
    private var hinweiszeile: some View {
        if let fehler = verbindung.letzterFehler {
            Hinweis(text: fehler, farbe: .red)
        } else if let meldung = steuerung.meldung {
            Hinweis(text: meldung, farbe: .orange)
        } else if let gespeichert = steuerung.zuletztGespeichert {
            Hinweis(text: gespeichert, farbe: .green)
        }
    }
}

// MARK: - Einzelteile

private struct Verbindungszeile: View {
    let text: String
    let status: Verbindungsstatus

    private var farbe: Color {
        switch status {
        case .verbunden: return .green
        case .suche, .verbinde: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(farbe).frame(width: 8, height: 8)
            Text(text)
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(.quaternary, in: Capsule())
    }
}

private struct Trainingszeile: View {
    @ObservedObject var steuerung: SitzungsSteuerung
    let texte: Texte

    private var text: String {
        switch steuerung.zustand {
        case .wartet:
            return steuerung.automatischerStart ? texte.wartetAufBandstart : texte.bereit
        case .laeuft: return texte.trainingLaeuft
        case .pausiert: return texte.pausiert
        }
    }

    private var symbol: String {
        switch steuerung.zustand {
        case .wartet: return "hourglass"
        case .laeuft: return "figure.walk"
        case .pausiert: return "pause.circle"
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Label(text, systemImage: symbol)
                .font(.footnote.weight(.medium))
                .lineLimit(1).minimumScaleFactor(0.7)
            if let rest = steuerung.restzeitText {
                Text(rest)
                    .font(.caption2).foregroundStyle(.orange)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
        }
    }
}

private struct GrosserWert: View {
    let wert: String
    let einheit: String
    let schriftgroesse: CGFloat

    var body: some View {
        VStack(spacing: -4) {
            Text(wert)
                .font(.system(size: schriftgroesse, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            Text(einheit).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

private struct Kachel: View {
    let titel: String
    let wert: String
    let einheit: String

    var body: some View {
        VStack(spacing: 1) {
            Text(titel).font(.caption2).foregroundStyle(.secondary)
            Text(wert)
                .font(.title3.weight(.semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(einheit.isEmpty ? " " : einheit)
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct Hinweis: View {
    let text: String
    let farbe: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(farbe)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Sitzungsknoepfe: View {
    @ObservedObject var steuerung: SitzungsSteuerung
    let texte: Texte
    @State private var zeigeVerwerfen = false

    var body: some View {
        HStack(spacing: 8) {
            switch steuerung.zustand {
            case .wartet:
                Button(texte.jetztStarten) { steuerung.starteManuell() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!steuerung.verbindung.status.istVerbunden)

            case .laeuft:
                Button(texte.pause) { steuerung.pausiere() }
                    .buttonStyle(.bordered)
                Button(texte.beenden) { steuerung.beendeManuell() }
                    .buttonStyle(.borderedProminent)
                verwerfenKnopf

            case .pausiert:
                Button(texte.weiter) { steuerung.setzeFort() }
                    .buttonStyle(.borderedProminent)
                Button(texte.beenden) { steuerung.beendeManuell() }
                    .buttonStyle(.bordered)
                verwerfenKnopf
            }
        }
        .font(.subheadline)
        .confirmationDialog(texte.einheitVerwerfenFrage, isPresented: $zeigeVerwerfen) {
            Button(texte.verwerfen, role: .destructive) { steuerung.verwirf() }
            Button(texte.abbrechen, role: .cancel) {}
        } message: {
            Text(texte.einheitVerwerfenHinweis)
        }
    }

    private var verwerfenKnopf: some View {
        Button(role: .destructive) { zeigeVerwerfen = true } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.bordered)
    }
}
