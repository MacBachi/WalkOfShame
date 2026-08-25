import SwiftUI

@main
struct TreadmillApp: App {
    @StateObject private var sprachen = Sprachverwaltung()
    /// Wird einmalig beim Start erzeugt — die BLE-Verbindung muss die State
    /// Restoration von iOS überleben und darf nicht an einer View hängen.
    @StateObject private var steuerung: SitzungsSteuerung

    init() {
        let sprachen = Sprachverwaltung()
        _sprachen = StateObject(wrappedValue: sprachen)
        _steuerung = StateObject(wrappedValue: SitzungsSteuerung(sprachen: sprachen))
    }

    var body: some Scene {
        WindowGroup {
            LiveView(steuerung: steuerung)
                .environmentObject(sprachen)
                // Zieht Datums- und Zahlformate auf die gewählte Sprache.
                .environment(\.locale, sprachen.texte.gebietsschema)
        }
    }
}
