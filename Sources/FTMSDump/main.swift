import Foundation
import CoreBluetooth
import FTMSKit

// CLI-Argumente
// --dauer <s>   Aufzeichnungsdauer nach Verbindungsaufbau (Default 90)
// --name <text> nur Geräte verbinden, deren Name diesen Text enthält
// --alle        von Anfang an ohne Service-Filter scannen (Bänder, die 1826
//               nicht im Advertising führen)
func argument(_ schluessel: String) -> String? {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: schluessel), index + 1 < args.count else { return nil }
    return args[index + 1]
}
let dauer = Double(argument("--dauer") ?? "") ?? 90
let namensFilter = argument("--name")
let sofortAlle = CommandLine.arguments.contains("--alle")
// --regie: gesprochener Kalibrierungsablauf, Dauer ergibt sich aus dem Ablauf.
let regie = CommandLine.arguments.contains("--regie")

// Ungepuffert, damit das Log auch bei Abbruch/Umleitung vollständig ist.
setvbuf(stdout, nil, _IONBF, 0)

// --auswerten <datei>: fertige Aufnahme analysieren, ohne Bluetooth.
if let datei = argument("--auswerten") {
    Auswertung.fuehreAus(pfad: datei)
    exit(0)
}

let protokoll = try DumpProtokoll()
let dumper = FTMSDumper(
    protokoll: protokoll,
    aufzeichnungsdauer: regie ? Kalibrierung.gesamtdauer : dauer,
    namensFilter: namensFilter,
    sofortAlleScannen: sofortAlle,
    mitRegie: regie
)
dumper.start()

// CoreBluetooth braucht eine laufende RunLoop.
RunLoop.main.run()
