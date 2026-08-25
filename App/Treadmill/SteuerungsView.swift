import SwiftUI
import FTMSKit
import FTMSTransport

/// Steuerung des Bands über Control Point `0x2AD9`.
///
/// ⚠️ Das Band beschleunigt unter dem Nutzer. Regeln dieser View:
/// 1. Der Not-Stop ist immer sichtbar und braucht **keine** Bestätigung.
/// 2. Jede Geschwindigkeitsänderung braucht eine explizite Bestätigung.
/// 3. Der Zielwert wird vor dem Senden gegen `0x2AD4` geprüft — ein unzulässiger
///    Wert verlässt die App gar nicht erst.
struct SteuerungsView: View {
    @ObservedObject var verbindung: LaufbandVerbindung
    @EnvironmentObject private var sprachen: Sprachverwaltung

    @State private var ziel: Double = 1.0
    @State private var zeigeBestaetigung = false
    @State private var fehler: String?

    private var bereich: UnterstuetzteGeschwindigkeit? { verbindung.geschwindigkeitsbereich }
    private var texte: Texte { sprachen.texte }

    var body: some View {
        Form {
            Section {
                LabeledContent(texte.status, value: verbindung.steuerstatus.beschreibung)
                if case .aktiv = verbindung.steuerstatus {
                    EmptyView()
                } else {
                    Button(texte.steuerungAnfordern) { verbindung.fordereSteuerungAn() }
                        .disabled(!verbindung.status.istVerbunden
                                  || verbindung.steuerstatus == .nichtVerfuegbar)
                }
            } header: {
                Text(texte.handshake)
            } footer: {
                Text(texte.handshakeFussnote)
            }

            if let bereich {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: "%@: %.1f km/h", texte.geschwindigkeit, ziel))
                            .font(.title3.weight(.semibold)).monospacedDigit()
                        Slider(value: $ziel,
                               in: bereich.minimum...bereich.maximum,
                               step: bereich.schrittweite)
                        Text(String(format: "%@ %.1f–%.1f km/h (%.1f)", texte.geraetErlaubt,
                                    bereich.minimum, bereich.maximum, bereich.schrittweite))
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Button(texte.geschwindigkeitSenden) { zeigeBestaetigung = true }
                        .disabled(verbindung.steuerstatus != .aktiv)
                } header: {
                    Text(texte.geschwindigkeit)
                }
            } else {
                Section {
                    Text(texte.grenzenFehlen)
                        .foregroundStyle(.secondary)
                }
            }

            if let fehler {
                Section { Text(fehler).foregroundStyle(.red) }
            }

            Section {
                Button(role: .destructive) {
                    // Bewusst ohne Bestätigung: ein Not-Stop, der nachfragt,
                    // ist kein Not-Stop.
                    verbindung.notStop()
                } label: {
                    Label(texte.notStop, systemImage: "stop.circle.fill")
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } footer: {
                Text(texte.notStopFussnote)
            }
        }
        .navigationTitle(texte.steuerung)
        .confirmationDialog(String(format: texte.bestaetigungFrage,
                                   String(format: "%.1f", ziel)),
                            isPresented: $zeigeBestaetigung, titleVisibility: .visible) {
            Button(String(format: "%.1f km/h", ziel)) { sende() }
            Button(texte.abbrechen, role: .cancel) {}
        } message: {
            Text(texte.bestaetigungHinweis + " " + texte.sicherenStand)
        }
        .onAppear {
            if let bereich { ziel = max(ziel, bereich.minimum) }
        }
    }

    private func sende() {
        fehler = nil
        do {
            try verbindung.sende(.zielGeschwindigkeit(kmH: ziel))
        } catch {
            fehler = "\(error)"
        }
    }
}
