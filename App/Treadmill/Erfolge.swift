import Foundation

/// Eine Wegmarke, die sich an der insgesamt zurückgelegten Strecke freischaltet.
struct Erfolg: Identifiable, Equatable {
    var id: Double { meter }
    let meter: Double
    let titelDeutsch: String
    let textDeutsch: String
    let titelEnglisch: String
    let textEnglisch: String

    func titel(_ sprache: Sprache) -> String {
        sprache == .deutsch ? titelDeutsch : titelEnglisch
    }
    func text(_ sprache: Sprache) -> String {
        sprache == .deutsch ? textDeutsch : textEnglisch
    }
    var kilometer: Double { meter / 1000 }
}

enum Erfolge {

    /// Aufsteigend sortiert. Am Anfang eng gesetzt, damit früh und regelmäßig
    /// etwas aufgeht; nach hinten weiter, sonst wären es tausende Einträge.
    static let alle: [Erfolg] = [
        E(1_000, "Der erste Kilometer", "Auch der Jakobsweg beginnt mit einem Schritt. Deiner war auf der Stelle.",
                 "The First Kilometre", "Even the Camino begins with a single step. Yours went nowhere."),
        E(2_000, "Lebenswerk einer Ameise", "So weit läuft eine Ameise in ihrem ganzen Leben. Du: heute Vormittag.",
                 "An Ant’s Life’s Work", "That is how far an ant walks in its entire life. You: before lunch."),
        E(2_700, "Golden Gate Bridge", "Einmal drüber. Ohne Aussicht, ohne Wind, ohne alles.",
                 "Golden Gate Bridge", "Across it once. No view, no wind, no nothing."),
        E(3_800, "Großglockner", "So hoch ist Österreichs höchster Berg. Du bist die Strecke gegangen — halt seitlich.",
                 "Grossglockner", "The height of Austria’s tallest mountain. You did the distance — just sideways."),
        E(5_000, "Volkslauf", "Die klassische Fünf-Kilometer-Distanz. Ohne Startnummer, ohne Bananen am Ziel.",
                 "The Five K", "The classic distance. No race number, no bananas at the finish."),
        E(6_500, "Einmal quer durch IKEA", "Inklusive Rückweg durch die Abkürzung, die keine war.",
                 "One Lap of IKEA", "Including the shortcut on the way back that turned out not to be one."),
        E(8_848, "Mount Everest", "Die Höhe des Everest — nur eben flach. Kein Sauerstoff nötig.",
                 "Mount Everest", "The height of Everest, laid flat. No supplemental oxygen required."),
        E(10_000, "Der Zehner", "Fünf Ziffern auf dem Zähler. Der Rest sind Details.",
                 "The Ten K", "Five digits on the counter. The rest is detail."),
        E(11_034, "Marianengraben", "So tief ist die tiefste Stelle des Ozeans. Du warst trocken dabei.",
                 "Mariana Trench", "The depth of the deepest point in the ocean. You stayed dry."),
        E(14_000, "Straße von Gibraltar", "Von Europa nach Afrika. Zumindest die Kilometer stimmen.",
                 "Strait of Gibraltar", "Europe to Africa. The kilometres are right, at least."),
        E(16_093, "Zehn Meilen", "In den einzig richtigen Einheiten: 16,093 km. Gern geschehen.",
                 "Ten Miles", "In the only sensible units: 16.093 km. You are welcome."),
        E(18_000, "Ein Arbeitstag Verkäuferin", "So weit läuft eine Verkäuferin in zwei Schichten. Respekt.",
                 "A Shop Assistant’s Day", "About two shifts on the shop floor. Respect."),
        E(21_098, "Halbmarathon", "Die halbe Distanz, die ganze Ehre. Und ein Dach über dem Kopf.",
                 "Half Marathon", "Half the distance, all the glory. And a roof over your head."),
        E(25_000, "Wiener Ringstraße, fünfmal", "Fünf Runden um die Innenstadt. Ohne einmal stehen zu bleiben.",
                 "Five Laps of the Ring", "Five times around Vienna’s inner city. Without stopping once."),
        E(28_000, "Ein Mistkäferleben", "So weit schiebt ein Mistkäfer seine Kugel — in Summe, lebenslang.",
                 "A Dung Beetle’s Career", "That is how far a dung beetle pushes its ball. In total. Ever."),
        E(33_000, "Ärmelkanal", "Dover nach Calais. Deutlich weniger nass, deutlich weniger Fähre.",
                 "The English Channel", "Dover to Calais. Considerably drier, considerably less ferry."),
        E(37_000, "Ein Blauwal-Darm", "Nein, stimmt nicht. Der ist nur 200 Meter lang. Du bist trotzdem weit gekommen.",
                 "A Blue Whale’s Intestine", "No, that is wrong — it is only 200 metres. You have still come far."),
        E(42_195, "Marathon", "Die volle Distanz. Pheidippides ist danach gestorben. Du hast pausiert.",
                 "Marathon", "The full distance. Pheidippides died afterwards. You took a break."),
        E(50_450, "Eurotunnel", "Die Länge des Kanaltunnels. Auch dort sieht man nichts.",
                 "The Channel Tunnel", "Its full length. There is nothing to see in there either."),
        E(57_000, "Gotthard-Basistunnel", "Der längste Eisenbahntunnel der Welt. Du warst langsamer.",
                 "Gotthard Base Tunnel", "The world’s longest rail tunnel. You were slower."),
        E(65_000, "Ein Jahr Bürohund", "So weit trottet ein durchschnittlicher Bürohund pro Jahr neben Schreibtischen her.",
                 "A Year as an Office Dog", "The annual mileage of an average dog trotting between desks."),
        E(82_000, "Panamakanal", "Vom Atlantik zum Pazifik. Ohne Schleusengebühr.",
                 "The Panama Canal", "Atlantic to Pacific. No transit fee."),
        E(100_000, "Kármán-Linie", "Ab 100 km beginnt der Weltraum. Du bist im All — nur eben quer.",
                 "The Kármán Line", "Space begins at 100 km. You are in orbit. Sideways."),
        E(120_000, "Ein Wanderpokal", "So weit ist ein durchschnittlicher Wanderpokal in seinem Leben gewandert.",
                 "A Travelling Trophy", "The lifetime mileage of an average trophy passed around a club."),
        E(150_000, "Loch Ness, hin und zurück", "Fünfzehnmal. Nessie wurde nicht gesichtet.",
                 "Loch Ness, Both Ways", "Fifteen times over. No sighting to report."),
        E(180_000, "Ein Postbotenjahr", "Die Jahresleistung eines Zustellers zu Fuß. Ohne Pakete.",
                 "A Postie’s Year", "A walking postal round, annualised. Without the parcels."),
        E(220_000, "Nord-Süd durch Großbritannien", "Land’s End nach John o’ Groats, plus Umweg zum Kiosk.",
                 "End to End", "Land’s End to John o’ Groats, plus a detour to the shop."),
        E(280_000, "Die Alpen der Länge nach", "Von Nizza bis Wien. Rein rechnerisch.",
                 "The Alps Lengthwise", "Nice to Vienna. On paper."),
        E(350_000, "Ein Kaugummi-Meter-Rekord", "So lang wäre die Kaugummikette, die du dafür verdient hättest.",
                 "A Chewing Gum Chain", "The length of the chain you have arguably earned."),
        E(400_000, "ISS-Umlaufbahn", "So hoch fliegt die Raumstation. Du kämst hin — ohne Rakete, nur ohne Höhe.",
                 "ISS Orbit", "The station’s altitude. You would reach it. Minus the altitude."),
        E(500_000, "Eine halbe Million Meter", "Klingt nach mehr als 500 km. Deswegen steht es so da.",
                 "Half a Million Metres", "Sounds better than 500 km. That is why it is written this way."),
        E(600_000, "Nord-Süd durch Afrika, ein Zehntel", "Kairo bis Kapstadt sind 6.000 km. Ein Zehntel liegt hinter dir.",
                 "A Tenth of Africa", "Cairo to Cape Town is 6,000 km. You have done a tenth."),
        E(700_000, "Die Donau", "Von der Quelle bis fast zur Mündung. Ohne einmal nass zu werden.",
                 "The Danube", "Source to almost the mouth. Without getting wet once."),
        E(800_000, "Jakobsweg", "Der Camino Francés. Ohne Blasen, ohne Herberge, ohne spirituelle Erkenntnis.",
                 "The Camino", "The Camino Francés. No blisters, no hostels, no spiritual awakening."),
        E(900_000, "Ein Elefantenleben", "So weit wandert ein afrikanischer Elefant in seinem Leben.",
                 "An Elephant’s Life", "The lifetime range of an African elephant."),
        E(1_000_000, "Eine Million Meter", "Sieben Ziffern. Das Laufband hat es nicht kommen sehen.",
                 "One Million Metres", "Seven digits. The treadmill did not see this coming."),
        E(1_200_000, "Italien der Länge nach", "Vom Brenner bis zur Stiefelspitze. Zweimal.",
                 "Italy Lengthwise", "Brenner Pass to the toe of the boot. Twice."),
        E(1_400_000, "Zugvogel-Jahr", "Ein Küstenseeschwalbenjahr wären 70.000 km. Du hast zwanzig davon.",
                 "A Migratory Year", "An Arctic tern flies 70,000 km a year. You have done twenty of those."),
        E(1_600_000, "Wüste Gobi, einmal quer", "1.600 km Sand. Bei dir: Gummiband.",
                 "Across the Gobi", "1,600 km of sand. In your case, rubber belt."),
        E(2_000_000, "Zwei Millionen Meter", "An diesem Punkt ist die Einheit auch schon egal.",
                 "Two Million Metres", "At this point the unit hardly matters."),
        E(2_500_000, "Route 66, sechsmal", "Chicago nach Santa Monica. Und wieder zurück. Und nochmal.",
                 "Route 66, Six Times", "Chicago to Santa Monica. And back. And again."),
        E(2_850_000, "Die Donau, viermal", "Quelle bis Mündung, viermal hintereinander.",
                 "The Danube, Four Times", "Source to delta, four times over."),
        E(3_500_000, "Die Chinesische Mauer", "Einmal die ganze Mauer entlang. Inklusive der Abschnitte, die niemand besucht.",
                 "The Great Wall", "The entire wall. Including the bits nobody visits."),
        E(4_500_000, "Ein Wanderschäfer-Leben", "Die Lebensleistung eines Wanderschäfers. Ohne Schafe.",
                 "A Shepherd’s Lifetime", "The life’s work of a transhumance shepherd. Minus the sheep."),
        E(6_400_000, "Erdradius", "Von der Oberfläche bis zum Mittelpunkt. Theoretisch.",
                 "Earth’s Radius", "Surface to core. Theoretically."),
        E(6_650_000, "Der Nil", "Der längste Fluss der Welt. Du hast ihn abgelaufen, in Zimmerlautstärke.",
                 "The Nile", "The longest river on Earth. Walked at room volume."),
        E(8_000_000, "Acht Millionen Meter", "Die Zahl wird langsam unhöflich.",
                 "Eight Million Metres", "The number is starting to get rude."),
        E(10_000_000, "Zehn Millionen Meter", "Ursprünglich war der Meter so definiert: ein Zehnmillionstel von Pol zu Äquator. Du hast die Strecke.",
                 "Ten Million Metres", "The metre was once defined as a ten-millionth of that distance. You have walked it."),
        E(12_742_000, "Erddurchmesser", "Einmal durch den Planeten. Der kürzeste Weg nach Neuseeland.",
                 "Earth’s Diameter", "Straight through the planet. The short way to New Zealand."),
        E(16_000_000, "Wüste Gobi, zehnmal", "Zehnmal quer. Der Sand kennt dich mittlerweile.",
                 "The Gobi, Ten Times", "Ten crossings. The sand knows you by now."),
        E(20_037_000, "Halber Erdumfang", "Die Hälfte ist geschafft. Die zweite Hälfte ist genauso lang.",
                 "Half the Equator", "Halfway round. The second half is exactly as long."),
        E(30_000_000, "Dreißig Millionen Meter", "Es gibt keinen Vergleich mehr, der das noch relativiert.",
                 "Thirty Million Metres", "There is no comparison left that makes this sound reasonable."),
        E(40_075_000, "Einmal um die Erde", "Der volle Äquator. Auf einem Gerät, das sich nicht von der Stelle bewegt hat.",
                 "Around the World", "The full equator. On a device that never moved an inch.")
    ]

    private static func E(_ meter: Double, _ titelDe: String, _ textDe: String,
                          _ titelEn: String, _ textEn: String) -> Erfolg {
        Erfolg(meter: meter, titelDeutsch: titelDe, textDeutsch: textDe,
               titelEnglisch: titelEn, textEnglisch: textEn)
    }

    static func erreicht(meter: Double) -> [Erfolg] {
        alle.filter { $0.meter <= meter }
    }

    static func naechster(meter: Double) -> Erfolg? {
        alle.first { $0.meter > meter }
    }

    /// Fortschritt zum nächsten Erfolg, 0…1. `nil`, wenn alles erreicht ist.
    static func fortschritt(meter: Double) -> Double? {
        guard let naechster = naechster(meter: meter) else { return nil }
        let vorheriger = erreicht(meter: meter).last?.meter ?? 0
        let spanne = naechster.meter - vorheriger
        guard spanne > 0 else { return nil }
        return min(1, max(0, (meter - vorheriger) / spanne))
    }
}
