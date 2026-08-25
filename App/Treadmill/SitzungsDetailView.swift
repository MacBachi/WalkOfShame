import SwiftUI
import Charts
import FTMSKit
import FTMSTransport

/// Eine einzelne Einheit mit Verlaufsgrafik.
struct SitzungsDetailView: View {
    let einheit: Sitzungszusammenfassung
    @EnvironmentObject private var sprachen: Sprachverwaltung

    @State private var punkte: [Verlaufspunkt] = []

    private var texte: Texte { sprachen.texte }

    /// Grün langsam, rot schnell. Weil die Geschwindigkeit auf der y-Achse
    /// liegt, bildet ein senkrechter Verlauf genau das ab — ohne dass jedes
    /// Segment einzeln eingefärbt werden müsste.
    private var farbskala: Gradient {
        Gradient(colors: [.green, Color(red: 0.7, green: 0.85, blue: 0.2),
                          .yellow, .orange, .red])
    }

    /// Feste Obergrenze aus dem Gerätebereich (max. 6 km/h), damit dieselbe
    /// Geschwindigkeit in jeder Einheit dieselbe Farbe hat.
    private var obergrenze: Double {
        max(6, (punkte.map(\.geschwindigkeit).max() ?? 6).rounded(.up))
    }

    var body: some View {
        List {
            Section(texte.verlaufsgrafik) {
                if punkte.isEmpty {
                    Text("—").foregroundStyle(.secondary)
                } else {
                    grafik.frame(height: 200).padding(.vertical, 8)
                }
            }

            Section {
                Wert(titel: texte.distanz,
                     wert: texte.zahl(einheit.distanzKilometer, 2) + " km")
                Wert(titel: texte.dauerLabel, wert: dauerText)
                Wert(titel: texte.schnitt,
                     wert: texte.zahl(einheit.durchschnittsgeschwindigkeit) + " km/h")
                Wert(titel: texte.maximum,
                     wert: texte.zahl(einheit.maxGeschwindigkeit) + " km/h")
                Wert(titel: texte.kalorien,
                     wert: "\(Int(einheit.energieKcal)) \(texte.kilokalorien)")
            }
        }
        // .formatted() direkt aufgerufen kennt die Umgebung nicht — das
        // Gebietsschema muss explizit mit, sonst steht dort »at« statt »um«.
        .navigationTitle(einheit.beginn.formatted(
            .dateTime.day().month().hour().minute().locale(texte.gebietsschema)))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let pfad = einheit.pfad
            punkte = await Task.detached(priority: .userInitiated) {
                Sitzungsarchiv.verlauf(pfad)
            }.value
        }
    }

    private var grafik: some View {
        Chart(punkte) { punkt in
            AreaMark(
                x: .value(texte.zeit, punkt.sekunde / 60),
                y: .value(texte.geschwindigkeit, punkt.geschwindigkeit)
            )
            .foregroundStyle(LinearGradient(gradient: farbskala,
                                            startPoint: .bottom, endPoint: .top)
                .opacity(0.28))
            .interpolationMethod(.monotone)

            LineMark(
                x: .value(texte.zeit, punkt.sekunde / 60),
                y: .value(texte.geschwindigkeit, punkt.geschwindigkeit)
            )
            .foregroundStyle(LinearGradient(gradient: farbskala,
                                            startPoint: .bottom, endPoint: .top))
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            .interpolationMethod(.monotone)
        }
        .chartYScale(domain: 0...obergrenze)
        .chartXAxisLabel(texte.minutenKurz)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }

    private var dauerText: String {
        let ganze = Int(einheit.dauer)
        return String(format: "%02d:%02d:%02d",
                      ganze / 3600, (ganze % 3600) / 60, ganze % 60)
    }
}

struct Wert: View {
    let titel: String
    let wert: String

    var body: some View {
        HStack {
            Text(titel)
            Spacer()
            Text(wert).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}
