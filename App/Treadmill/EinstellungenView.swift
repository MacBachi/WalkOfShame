import SwiftUI
import UIKit
import FTMSKit
import FTMSTransport

/// Alles, was nicht während des Trainings gebraucht wird.
struct EinstellungenView: View {
    @ObservedObject var steuerung: SitzungsSteuerung
    @EnvironmentObject private var sprachen: Sprachverwaltung
    @AppStorage("debugAktiv") private var debugAktiv = false

    /// Der Maßsystem-Schalter. Er tut nichts — außer den Nutzer zu belehren.
    @State private var imperial = false
    @State private var zeigeBelehrung = false

    private var verbindung: LaufbandVerbindung { steuerung.verbindung }
    private var texte: Texte { sprachen.texte }

    var body: some View {
        Form {
            Section {
                Toggle(texte.nachHealthSchreiben, isOn: $steuerung.healthAktiv)
                    .disabled(steuerung.offen)
            } footer: {
                Text(steuerung.offen ? texte.healthFussnoteGesperrt : texte.healthFussnoteAktiv)
            }

            Section {
                Toggle(texte.automatischStarten, isOn: $steuerung.automatischerStart)
            } footer: {
                Text(texte.automatischStartenFussnote)
            }

            Section {
                Button {
                    verbindung.bevorzugtesGeraet = nil
                } label: {
                    HStack {
                        Text(texte.automatischesGeraet)
                        Spacer()
                        if verbindung.bevorzugtesGeraet == nil {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .foregroundStyle(.primary)

                ForEach(verbindung.gefundeneGeraete) { gefunden in
                    Button {
                        verbindung.bevorzugtesGeraet = gefunden.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(gefunden.name)
                                Text("\(gefunden.rssi) dBm")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if verbindung.bevorzugtesGeraet == gefunden.id {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }

                if verbindung.gefundeneGeraete.isEmpty {
                    Text(texte.keineGeraeteGefunden)
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text(texte.laufbandWaehlen)
            } footer: {
                Text(texte.geraeteFussnote)
            }

            Section {
                Picker(texte.spracheTitel, selection: $sprachen.wahl) {
                    Text(texte.spracheAutomatisch).tag(Sprachwahl.automatisch)
                    Text(texte.spracheDeutsch).tag(Sprachwahl.deutsch)
                    Text(texte.spracheEnglisch).tag(Sprachwahl.englisch)
                }
            } header: {
                Text(texte.spracheTitel)
            } footer: {
                Text(texte.spracheFussnote)
            }

            Section {
                Toggle(texte.imperialeEinheitenAktivieren, isOn: $imperial)
            } header: {
                Text(texte.masssystem)
            } footer: {
                Text(texte.masssystemFussnote)
            }

            Section {
                Toggle(texte.debugModus, isOn: $debugAktiv)
                if debugAktiv {
                    NavigationLink {
                        DebugPanel(verbindung: verbindung)
                    } label: {
                        Label(texte.rohdatenAnsehen, systemImage: "ladybug")
                    }
                }
            } footer: {
                Text(debugAktiv ? texte.debugFussnoteAn : texte.debugFussnoteAus)
            }

            Section(texte.geraet) {
                LabeledContent(texte.verbindung,
                               value: texte.verbindungstext(verbindung.status))
                if let bereich = verbindung.geschwindigkeitsbereich {
                    LabeledContent(texte.geschwindigkeit, value: String(
                        format: "%.1f–%.1f km/h", bereich.minimum, bereich.maximum))
                }
                if let status = verbindung.trainingStatus {
                    LabeledContent(texte.trainingStatus, value: status.bezeichnung)
                }
            }
        }
        .navigationTitle(texte.einstellungen)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { verbindung.sucheGeraete() }
        .onDisappear { verbindung.beendeGeraetesuche() }
        .onChange(of: debugAktiv) { neu in
            verbindung.protokollModus = neu ? .alles : .nurAuffaellige
        }
        .onChange(of: imperial) { neu in
            guard neu else { return }
            zeigeBelehrung = true
            // Der Schalter springt von selbst zurück — imperiale Einheiten
            // werden hier nicht verhandelt.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { imperial = false }
        }
        .overlay {
            if zeigeBelehrung {
                Sicherheitsabschaltung(texte: texte)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: zeigeBelehrung)
    }
}

/// Die Belehrung, die nach dem Versuch erscheint, auf imperiale Einheiten
/// umzuschalten. Ein Tipp darauf öffnet die Wikipedia-Liste humoristischer
/// Maßeinheiten und beendet die App.
private struct Sicherheitsabschaltung: View {
    let texte: Texte

    private static let nachschlagewerk = URL(
        string: "https://en.wikipedia.org/wiki/List_of_humorous_units_of_measurement")!

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "ruler")
                    .font(.system(size: 52))
                    .foregroundStyle(.orange)

                Text(texte.scherzTitel)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(texte.scherzText)
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(texte.scherzTippen)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(28)
        }
        .contentShape(Rectangle())
        .onTapGesture { beendeMitNachschlagewerk() }
    }

    private func beendeMitNachschlagewerk() {
        UIApplication.shared.open(Self.nachschlagewerk) { _ in
            // Kurz warten, damit der Browser wirklich vorne ist — sonst beendet
            // sich die App, bevor iOS den Wechsel vollzogen hat.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { exit(0) }
        }
    }
}
