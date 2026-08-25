import XCTest

/// Prüft die harte Anforderung: der Hauptbildschirm darf **nie** scrollen —
/// weder hoch noch quer. Läuft auf einem iPhone SE (375 × 667 pt), also der
/// gleichen Fläche wie das Ziel-iPhone-8.
final class LayoutTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func testHauptbildschirmScrolltNichtImHochformat() {
        let app = starte(.portrait)
        pruefeOhneScrollen(app, lage: "Hochformat")
    }

    func testHauptbildschirmScrolltNichtImQuerformat() {
        let app = starte(.landscapeLeft)
        pruefeOhneScrollen(app, lage: "Querformat")
    }

    /// Die Einstellungen dürfen scrollen — sie sind bewusst vom Hauptbildschirm
    /// getrennt, damit der es nicht muss.
    func testEinstellungenSindErreichbar() {
        let app = starte(.portrait)

        app.navigationBars.buttons["Einstellungen"].tap()

        XCTAssertTrue(app.switches["Nach Apple Health schreiben"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Automatisch starten"].exists)
        // Die Einstellungen dürfen scrollen — der Hauptbildschirm nicht.
        XCTAssertTrue(scrolleZu(app.switches["Debug-Modus"], in: app))
        XCTAssertTrue(scrolleZu(app.switches["Imperiale Einheiten aktivieren"], in: app))
    }

    /// Der Debug-Zugang darf nicht mehr auf dem Hauptbildschirm liegen.
    func testDebugNichtAufDemHauptbildschirm() {
        let app = starte(.portrait)

        XCTAssertFalse(app.navigationBars.buttons["Debug"].exists)
        XCTAssertTrue(app.navigationBars.buttons["Einstellungen"].exists)
    }

    // MARK: - Hilfen

    private func starte(_ lage: UIDeviceOrientation,
                        sprache: String = "deutsch") -> XCUIApplication {
        let app = XCUIApplication()
        // Sprache erzwingen: sonst hängen die Beschriftungen an der Systemsprache
        // des Simulators und die Tests wären nicht reproduzierbar.
        app.launchArguments = ["-sprachwahl", sprache]
        app.launch()
        XCUIDevice.shared.orientation = lage
        // Der Rotationswechsel braucht einen Moment, bis das Layout steht.
        _ = app.staticTexts["km/h"].waitForExistence(timeout: 10)
        return app
    }

    private func pruefeOhneScrollen(_ app: XCUIApplication, lage: String) {
        haengeScreenshotAn(app, name: lage)

        XCTAssertEqual(app.scrollViews.count, 0,
                       "\(lage): der Hauptbildschirm enthält eine ScrollView")

        let fenster = app.windows.element(boundBy: 0).frame
        for beschriftung in ["Distanz", "Zeit", "Kalorien", "Puls"] {
            let element = app.staticTexts[beschriftung]
            XCTAssertTrue(element.exists, "\(lage): »\(beschriftung)« fehlt")
            XCTAssertTrue(fenster.contains(element.frame),
                          "\(lage): »\(beschriftung)« liegt außerhalb des Bildschirms")
        }

        let startknopf = app.buttons["Jetzt starten"]
        XCTAssertTrue(startknopf.exists, "\(lage): Startknopf fehlt")
        XCTAssertTrue(fenster.contains(startknopf.frame),
                      "\(lage): Startknopf ist angeschnitten — \(startknopf.frame) "
                      + "passt nicht in \(fenster)")
    }

    /// Scrollt in einer Liste, bis das Element vorhanden ist. Nötig, weil
    /// SwiftUI in einem Form nur die sichtbaren Zeilen erzeugt.
    private func scrolleZu(_ element: XCUIElement, in app: XCUIApplication,
                           versuche: Int = 6) -> Bool {
        for _ in 0..<versuche {
            if element.exists { return true }
            app.swipeUp()
        }
        return element.exists
    }

    private func haengeScreenshotAn(_ app: XCUIApplication, name: String) {
        let aufnahme = XCUIScreen.main.screenshot()
        let anhang = XCTAttachment(screenshot: aufnahme)
        anhang.name = name
        anhang.lifetime = .keepAlways
        add(anhang)

        // Zusätzlich als Datei, damit sie sich von außen ansehen lässt.
        let pfad = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("layout-\(name).png")
        try? aufnahme.pngRepresentation.write(to: pfad)
    }

    // MARK: - Zweisprachigkeit

    func testEnglischeOberflaeche() {
        let app = starte(.portrait, sprache: "englisch")

        XCTAssertTrue(app.staticTexts["Distance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Calories"].exists)
        XCTAssertTrue(app.buttons["Start now"].exists)
        XCTAssertFalse(app.staticTexts["Distanz"].exists)
    }

    func testDeutscheOberflaeche() {
        let app = starte(.portrait, sprache: "deutsch")

        XCTAssertTrue(app.staticTexts["Distanz"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Jetzt starten"].exists)
        XCTAssertFalse(app.staticTexts["Distance"].exists)
    }

    /// Der Fake-Schalter zeigt die Belehrung. Getippt wird auf sie bewusst
    /// **nicht** — ein Tipp würde die App beenden.
    func testImperialSchalterZeigtBelehrung() {
        let app = starte(.portrait, sprache: "deutsch")
        app.navigationBars.buttons["Einstellungen"].tap()

        let schalter = app.switches["Imperiale Einheiten aktivieren"]
        XCTAssertTrue(scrolleZu(schalter, in: app), "Schalter nicht gefunden")
        // Auf das Bedienelement rechts tippen, nicht auf die Beschriftung —
        // ein Tipp auf das Label schaltet in einem Form nicht um.
        schalter.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()

        XCTAssertTrue(app.staticTexts["Sicherheitsabschaltung"].waitForExistence(timeout: 5),
                      "Belehrung muss erscheinen")
    }
}