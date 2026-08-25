import SwiftUI
import FTMSKit
import FTMSTransport

/// Zahlen über Zeiträume — und beim Gesamtwert die Erfolge.
struct StatistikView: View {
    let einheiten: [Sitzungszusammenfassung]
    @EnvironmentObject private var sprachen: Sprachverwaltung

    @State private var zeitraum: Zeitraum = .siebenTage

    private var texte: Texte { sprachen.texte }
    private var sprache: Sprache { sprachen.sprache }

    private var werte: Statistikwerte {
        Statistik.werte(einheiten, zeitraum: zeitraum)
    }

    /// Erfolge hängen immer an der Gesamtstrecke, nicht am gewählten Zeitraum —
    /// sonst könnte man sie durch Umschalten wieder verlieren.
    private var gesamtMeter: Double {
        Statistik.werte(einheiten, zeitraum: .gesamt).distanzMeter
    }

    var body: some View {
        List {
            Section {
                Picker("", selection: $zeitraum) {
                    ForEach(Zeitraum.allCases) { fall in
                        Text(texte.zeitraumName(fall)).tag(fall)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }

            Section {
                Wert(titel: texte.distanz,
                     wert: texte.zahl(werte.distanzKilometer, 2) + " km")
                Wert(titel: texte.einheitenLabel, wert: "\(werte.einheiten)")
                Wert(titel: texte.dauerLabel, wert: dauerText(werte.dauer))
                Wert(titel: texte.kalorien,
                     wert: "\(Int(werte.energieKcal)) \(texte.kilokalorien)")
                Wert(titel: texte.schnitt,
                     wert: texte.zahl(werte.durchschnittsgeschwindigkeit) + " km/h")
                Wert(titel: texte.maximum,
                     wert: texte.zahl(werte.maxGeschwindigkeit) + " km/h")
                Wert(titel: texte.laengsteEinheit,
                     wert: texte.zahl(werte.laengsteEinheitMeter / 1000, 2) + " km")
            }

            erfolgsabschnitt
        }
    }

    @ViewBuilder
    private var erfolgsabschnitt: some View {
        let erreicht = Erfolge.erreicht(meter: gesamtMeter)
        let naechster = Erfolge.naechster(meter: gesamtMeter)

        Section {
            if let naechster {
                VStack(alignment: .leading, spacing: 6) {
                    Text(texte.naechsterErfolg)
                        .font(.caption).foregroundStyle(.secondary)
                    Text(naechster.titel(sprache)).font(.headline)
                    ProgressView(value: Erfolge.fortschritt(meter: gesamtMeter) ?? 0)
                    Text(String(format: texte.nochOffen,
                                texte.zahl((naechster.meter - gesamtMeter) / 1000)))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                Text(texte.alleErfolgeErreicht).font(.headline)
            }
        } header: {
            HStack {
                Text(texte.erfolge)
                Spacer()
                Text(String(format: texte.erfolgeZaehler, erreicht.count, Erfolge.alle.count))
            }
        }

        Section {
            // Neueste zuerst: der zuletzt geknackte Erfolg steht oben.
            ForEach(erreicht.reversed()) { erfolg in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(erfolg.titel(sprache)).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(texte.zahl(erfolg.kilometer, 0) + " km")
                            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                    Text(erfolg.text(sprache))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func dauerText(_ sekunden: TimeInterval) -> String {
        let ganze = Int(sekunden)
        return String(format: "%d:%02d:%02d", ganze / 3600, (ganze % 3600) / 60, ganze % 60)
    }
}
