import XCTest
@testable import FTMSKit

final class TrainingsautomatikTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func zuwachs(meter: Double, bei sekunde: Double) -> Zuwachs {
        Zuwachs(von: start.addingTimeInterval(sekunde - 1),
                bis: start.addingTimeInterval(sekunde),
                distanzMeter: meter, energieKcal: 0, herzfrequenz: nil)
    }

    // MARK: - Automatischer Start

    func testBandbewegungStartetTraining() {
        var automatik = Trainingsautomatik()

        let ereignis = automatik.verarbeite(zuwachs(meter: 10, bei: 1),
                                            zeitpunkt: start.addingTimeInterval(1))

        XCTAssertEqual(ereignis, .starte)
        XCTAssertEqual(automatik.zustand, .laeuft)
    }

    /// Der eigentliche Grund für Distanz statt Geschwindigkeit: das Band meldet
    /// im Stillstand konstant 1,00 km/h. Ohne Distanzzuwachs darf nichts starten.
    func testStillstehendesBandStartetNicht() {
        var automatik = Trainingsautomatik()

        for sekunde in 1...60 {
            let ereignis = automatik.verarbeite(zuwachs(meter: 0, bei: Double(sekunde)),
                                                zeitpunkt: start.addingTimeInterval(Double(sekunde)))
            XCTAssertNil(ereignis, "kein Start ohne Bewegung (Sekunde \(sekunde))")
        }
        XCTAssertEqual(automatik.zustand, .wartet)
    }

    func testZweiterStartWirdNichtGemeldet() {
        var automatik = Trainingsautomatik()
        _ = automatik.verarbeite(zuwachs(meter: 10, bei: 1), zeitpunkt: start.addingTimeInterval(1))

        let nochmal = automatik.verarbeite(zuwachs(meter: 10, bei: 2),
                                           zeitpunkt: start.addingTimeInterval(2))

        XCTAssertNil(nochmal, "laufende Einheit startet nicht erneut")
    }

    func testAutomatischerStartAbschaltbar() {
        var automatik = Trainingsautomatik(automatischerStart: false)

        let ereignis = automatik.verarbeite(zuwachs(meter: 10, bei: 1),
                                            zeitpunkt: start.addingTimeInterval(1))

        XCTAssertNil(ereignis)
        XCTAssertEqual(automatik.zustand, .wartet)
    }

    // MARK: - Automatisches Ende nach Stillstand

    func testStillstandBeendetNachGrenze() {
        var automatik = Trainingsautomatik(stillstandsGrenze: 30 * 60)
        _ = automatik.verarbeite(zuwachs(meter: 10, bei: 1), zeitpunkt: start.addingTimeInterval(1))

        // 29 Minuten Stillstand: noch nichts.
        let vorher = automatik.verarbeite(zuwachs(meter: 0, bei: 0),
                                          zeitpunkt: start.addingTimeInterval(1 + 29 * 60))
        XCTAssertNil(vorher)
        XCTAssertEqual(automatik.zustand, .laeuft)

        // 30 Minuten: Ende.
        let ereignis = automatik.verarbeite(zuwachs(meter: 0, bei: 0),
                                            zeitpunkt: start.addingTimeInterval(1 + 30 * 60))

        XCTAssertEqual(ereignis, .beende(grund: .stillstand(dauer: 30 * 60)))
        XCTAssertEqual(automatik.zustand, .wartet)
    }

    /// Jede Bewegung stellt die Stillstandsuhr zurück.
    func testBewegungSetztStillstandsuhrZurueck() {
        var automatik = Trainingsautomatik(stillstandsGrenze: 30 * 60)
        _ = automatik.verarbeite(zuwachs(meter: 10, bei: 1), zeitpunkt: start.addingTimeInterval(1))

        // 20 min Pause, dann ein Schritt, dann nochmal 20 min.
        _ = automatik.verarbeite(zuwachs(meter: 0, bei: 0),
                                 zeitpunkt: start.addingTimeInterval(20 * 60))
        _ = automatik.verarbeite(zuwachs(meter: 10, bei: 0),
                                 zeitpunkt: start.addingTimeInterval(21 * 60))
        let ereignis = automatik.verarbeite(zuwachs(meter: 0, bei: 0),
                                            zeitpunkt: start.addingTimeInterval(41 * 60))

        XCTAssertNil(ereignis, "nach der Bewegung sind erst 20 min vergangen")
        XCTAssertEqual(automatik.zustand, .laeuft)
    }

    func testKeinEndeOhneLaufendeEinheit() {
        var automatik = Trainingsautomatik(stillstandsGrenze: 60)

        let ereignis = automatik.verarbeite(zuwachs(meter: 0, bei: 0),
                                            zeitpunkt: start.addingTimeInterval(10 * 60))

        XCTAssertNil(ereignis)
    }

    /// Auch während einer Pause läuft die 30-Minuten-Uhr weiter — wer pausiert
    /// und weggeht, soll keine offene Einheit hinterlassen.
    func testPauseVerhindertAutomatischesEndeNicht() {
        var automatik = Trainingsautomatik(stillstandsGrenze: 30 * 60)
        _ = automatik.verarbeite(zuwachs(meter: 10, bei: 1), zeitpunkt: start.addingTimeInterval(1))
        automatik.pausiere()

        let ereignis = automatik.verarbeite(zuwachs(meter: 0, bei: 0),
                                            zeitpunkt: start.addingTimeInterval(1 + 30 * 60))

        XCTAssertEqual(ereignis, .beende(grund: .stillstand(dauer: 30 * 60)))
    }

    // MARK: - Manuelle Pause

    func testPausierenUndFortsetzen() {
        var automatik = Trainingsautomatik()
        _ = automatik.verarbeite(zuwachs(meter: 10, bei: 1), zeitpunkt: start.addingTimeInterval(1))

        automatik.pausiere()
        XCTAssertEqual(automatik.zustand, .pausiert)

        automatik.setzeFort(zeitpunkt: start.addingTimeInterval(100))
        XCTAssertEqual(automatik.zustand, .laeuft)
    }

    /// Bewegung während der Pause darf die Einheit nicht heimlich fortsetzen.
    func testBewegungWaehrendPauseSetztNichtFort() {
        var automatik = Trainingsautomatik()
        _ = automatik.verarbeite(zuwachs(meter: 10, bei: 1), zeitpunkt: start.addingTimeInterval(1))
        automatik.pausiere()

        let ereignis = automatik.verarbeite(zuwachs(meter: 10, bei: 2),
                                            zeitpunkt: start.addingTimeInterval(2))

        XCTAssertNil(ereignis)
        XCTAssertEqual(automatik.zustand, .pausiert)
    }

    /// Nach einer langen Pause darf das Fortsetzen nicht sofort ins
    /// Stillstands-Ende laufen.
    func testFortsetzenStelltStillstandsuhrZurueck() {
        var automatik = Trainingsautomatik(stillstandsGrenze: 30 * 60)
        _ = automatik.verarbeite(zuwachs(meter: 10, bei: 1), zeitpunkt: start.addingTimeInterval(1))
        automatik.pausiere()

        automatik.setzeFort(zeitpunkt: start.addingTimeInterval(25 * 60))
        let ereignis = automatik.verarbeite(zuwachs(meter: 0, bei: 0),
                                            zeitpunkt: start.addingTimeInterval(35 * 60))

        XCTAssertNil(ereignis, "nach dem Fortsetzen sind erst 10 min vergangen")
    }

    // MARK: - Manuelles Starten und Beenden

    func testManuellerStartOhneBandbewegung() {
        var automatik = Trainingsautomatik(automatischerStart: false)

        let ereignis = automatik.starteManuell(zeitpunkt: start)

        XCTAssertEqual(ereignis, .starte)
        XCTAssertEqual(automatik.zustand, .laeuft)
    }

    func testManuellesBeenden() {
        var automatik = Trainingsautomatik()
        _ = automatik.verarbeite(zuwachs(meter: 10, bei: 1), zeitpunkt: start.addingTimeInterval(1))

        let ereignis = automatik.beendeManuell()

        XCTAssertEqual(ereignis, .beende(grund: .vomNutzer))
        XCTAssertEqual(automatik.zustand, .wartet)
        XCTAssertNil(automatik.letzteBewegung)
    }

    func testBeendenOhneEinheitTutNichts() {
        var automatik = Trainingsautomatik()

        XCTAssertNil(automatik.beendeManuell())
    }

    /// Nach einem Ende muss die nächste Bandbewegung wieder starten können.
    func testNachEndeStartetNaechsteBewegungWieder() {
        var automatik = Trainingsautomatik()
        _ = automatik.verarbeite(zuwachs(meter: 10, bei: 1), zeitpunkt: start.addingTimeInterval(1))
        _ = automatik.beendeManuell()

        let ereignis = automatik.verarbeite(zuwachs(meter: 10, bei: 2),
                                            zeitpunkt: start.addingTimeInterval(2))

        XCTAssertEqual(ereignis, .starte)
    }

    // MARK: - Anzeige

    func testVerbleibendeZeitBisEnde() {
        var automatik = Trainingsautomatik(stillstandsGrenze: 30 * 60)
        _ = automatik.verarbeite(zuwachs(meter: 10, bei: 0), zeitpunkt: start)

        XCTAssertEqual(automatik.verbleibendBisEnde(jetzt: start.addingTimeInterval(10 * 60)),
                       20 * 60)
        XCTAssertEqual(automatik.verbleibendBisEnde(jetzt: start.addingTimeInterval(40 * 60)), 0)
    }

    func testKeineRestzeitOhneEinheit() {
        let automatik = Trainingsautomatik()

        XCTAssertNil(automatik.verbleibendBisEnde(jetzt: start))
    }

    // MARK: - Geschwindigkeit als Bewegungssignal

    /// Am echten Gerät gemessen: Stillstand = exakt 0,00 km/h. Damit kann der
    /// Autostart sofort auslösen, statt auf den nächsten 10-m-Schritt zu warten.
    func testGeschwindigkeitStartetSofort() {
        var automatik = Trainingsautomatik()

        let ereignis = automatik.verarbeite(zuwachs(meter: 0, bei: 1),
                                            geschwindigkeit: 1.0,
                                            zeitpunkt: start.addingTimeInterval(1))

        XCTAssertEqual(ereignis, .starte, "kein Warten auf den Distanzschritt")
    }

    func testNullGeschwindigkeitStartetNicht() {
        var automatik = Trainingsautomatik()

        let ereignis = automatik.verarbeite(zuwachs(meter: 0, bei: 1),
                                            geschwindigkeit: 0.0,
                                            zeitpunkt: start.addingTimeInterval(1))

        XCTAssertNil(ereignis)
        XCTAssertEqual(automatik.zustand, .wartet)
    }

    /// Auslaufen des Gurts (0,9 → 0,4 → 0,0) hält die Stillstandsuhr an, bis
    /// wirklich null erreicht ist.
    func testAuslaufenGiltNochAlsBewegung() {
        var automatik = Trainingsautomatik(stillstandsGrenze: 60)
        _ = automatik.verarbeite(zuwachs(meter: 10, bei: 1), geschwindigkeit: 3.0,
                                 zeitpunkt: start.addingTimeInterval(1))

        for (versatz, kmh) in [(2.0, 0.9), (3.0, 0.4)] {
            _ = automatik.verarbeite(zuwachs(meter: 0, bei: versatz), geschwindigkeit: kmh,
                                     zeitpunkt: start.addingTimeInterval(versatz))
        }
        // Ab hier steht das Band: die Uhr läuft ab Sekunde 3.
        let zuFrueh = automatik.verarbeite(zuwachs(meter: 0, bei: 0), geschwindigkeit: 0,
                                           zeitpunkt: start.addingTimeInterval(62))
        XCTAssertNil(zuFrueh)

        let ereignis = automatik.verarbeite(zuwachs(meter: 0, bei: 0), geschwindigkeit: 0,
                                            zeitpunkt: start.addingTimeInterval(63))
        XCTAssertEqual(ereignis, .beende(grund: .stillstand(dauer: 60)))
    }

    /// Ohne Geschwindigkeitsfeld muss die Distanzregel weiter greifen.
    func testOhneGeschwindigkeitGreiftDistanzregel() {
        var automatik = Trainingsautomatik()

        let ereignis = automatik.verarbeite(zuwachs(meter: 10, bei: 1),
                                            geschwindigkeit: nil,
                                            zeitpunkt: start.addingTimeInterval(1))

        XCTAssertEqual(ereignis, .starte)
    }

    // MARK: - Anzeige »Band steht«

    /// Der gemeldete Fehler: bei laufendem Band stand »Band steht — endet
    /// automatisch in XX min« im Display. Ursache war, dass zwischen zwei
    /// Paketen rund eine Sekunde vergeht und die Restzeit damit immer knapp
    /// unter der Grenze lag.
    func testLaufendesBandStehtNicht() {
        var automatik = Trainingsautomatik(stillstandsGrenze: 30 * 60)
        _ = automatik.verarbeite(zuwachs(meter: 10, bei: 1), geschwindigkeit: 5.0,
                                 zeitpunkt: start.addingTimeInterval(1))

        XCTAssertTrue(automatik.bandLaeuft)
        XCTAssertFalse(automatik.stehtStill(jetzt: start.addingTimeInterval(2)),
                       "eine Sekunde nach dem Paket läuft das Band noch")
        XCTAssertFalse(automatik.stehtStill(jetzt: start.addingTimeInterval(30)))
    }

    /// Erst nach der Karenz gilt das Band als stehend.
    func testStillstandErstNachKarenz() {
        var automatik = Trainingsautomatik(stillstandsGrenze: 30 * 60)
        _ = automatik.verarbeite(zuwachs(meter: 10, bei: 1), geschwindigkeit: 5.0,
                                 zeitpunkt: start.addingTimeInterval(1))
        _ = automatik.verarbeite(zuwachs(meter: 0, bei: 2), geschwindigkeit: 0,
                                 zeitpunkt: start.addingTimeInterval(2))

        XCTAssertFalse(automatik.bandLaeuft)
        XCTAssertFalse(automatik.stehtStill(jetzt: start.addingTimeInterval(20)),
                       "20 s Stillstand ist noch innerhalb der Karenz")
        XCTAssertTrue(automatik.stehtStill(jetzt: start.addingTimeInterval(60)))
    }

    /// Ohne laufende Einheit gibt es keine Stillstandsanzeige.
    func testKeineStillstandsanzeigeOhneEinheit() {
        let automatik = Trainingsautomatik()

        XCTAssertFalse(automatik.stehtStill(jetzt: start.addingTimeInterval(10_000)))
    }

    /// Nach dem Wiederanlaufen verschwindet die Anzeige sofort.
    func testWiederanlaufBeendetStillstandsanzeige() {
        var automatik = Trainingsautomatik()
        _ = automatik.verarbeite(zuwachs(meter: 10, bei: 1), geschwindigkeit: 5.0,
                                 zeitpunkt: start.addingTimeInterval(1))
        _ = automatik.verarbeite(zuwachs(meter: 0, bei: 2), geschwindigkeit: 0,
                                 zeitpunkt: start.addingTimeInterval(2))
        XCTAssertTrue(automatik.stehtStill(jetzt: start.addingTimeInterval(120)))

        _ = automatik.verarbeite(zuwachs(meter: 0, bei: 121), geschwindigkeit: 3.0,
                                 zeitpunkt: start.addingTimeInterval(121))

        XCTAssertFalse(automatik.stehtStill(jetzt: start.addingTimeInterval(122)))
    }
}