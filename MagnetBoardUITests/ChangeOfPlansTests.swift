import XCTest

final class ChangeOfPlansTests: XCTestCase {
    @MainActor
    func testHamburgWeekWithRainLateFriendAndClosedMarket() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let names = ["Record hunting", "Pottery studio", "Alster sketches", "Station reunion", "Bookshop browsing",
                     "Waterfront print market", "Farewell brunch", "Courtyard sketch", "Zine shop", "Distant gallery"]
        let ids = names.map { _ in UUID().uuidString }
        var ideas: [[String: Any]] = []
        for (i, name) in names.enumerated() {
            var idea: [String: Any] = ["id": ids[i], "title": name, "duration": 2700]
            // Only activities where the user deliberately saved a map pin.
            if let lat = [5: 53.545, 7: 53.5455, 8: 53.547, 9: 53.63][i] {
                idea["coordinate"] = ["latitude": lat, "longitude": 9.998]
            }
            if i == 8 || i == 9 { idea["tags"] = ["rainy day"] }
            ideas.append(idea)
        }
        app.launchEnvironment["MAGNETBOARD_TEST_BOARD"] = UUID().uuidString
        app.launchEnvironment["MAGNETBOARD_TEST_IDEAS"] = String(decoding: try JSONSerialization.data(withJSONObject: ideas), as: UTF8.self)
        app.launchArguments = ["-welcome.hasSeenMagnetBoardIntro", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let plan = app.tabBars.buttons["Plan"]
        plan.tap()
        let scroll = app.scrollViews["plan.scroll"]
        let afternoon = app.buttons["drop.afternoon"]
        let next = app.buttons["Next day"]
        func row(_ index: Int) -> XCUIElement { app.buttons["planned.card.\(ids[index])"] }
        func openBackup(_ index: Int) {
            let button = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@",
                                                          "planned.backup.", "Plan B for " + names[index])).firstMatch
            reveal([button], in: scroll)
            button.tap()
            XCTAssertTrue(app.navigationBars["Plan B"].waitForExistence(timeout: 10))
        }
        func chooseZines() {
            openBackup(5)
            let outdoor = app.buttons["backup.choice.\(ids[7])"]
            let zines = app.buttons["backup.choice.\(ids[8])"]
            XCTAssertTrue(outdoor.exists && zines.exists)
            XCTAssertLessThan(outdoor.frame.midY, zines.frame.midY, "Closer saved place should come first")
            XCTAssertFalse(app.buttons["backup.choice.\(ids[9])"].exists)
            app.switches["backup.rain"].tap()
            XCTAssertFalse(outdoor.exists, "Outdoor stop still offered after asking for rainy-day ideas")
            zines.tap()
        }

        for i in 0..<7 {
            if i > 0 { next.tap() }
            reveal([afternoon], in: scroll)
            afternoon.tap()
            let input = app.textFields["planPicker.title"]
            XCTAssertTrue(input.waitForExistence(timeout: 10))
            input.tap()
            input.typeText(String(names[i].prefix(3)))
            let choice = app.buttons["planPicker.card.\(ids[i])"]
            XCTAssertTrue(choice.waitForExistence(timeout: 8))
            choice.tap()
            reveal([row(i)], in: scroll)
            XCTAssertTrue(row(i).label.contains("Afternoon"))
            switch i {
            case 2: // It is pouring. Skip the sketches; don't delete the underlying idea.
                openBackup(i)
                XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "No saved pin")).firstMatch.exists)
                app.buttons["backup.skip"].tap()
                XCTAssertFalse(row(i).exists)
            case 4: // Our visitor wants to go later today.
                row(i).tap()
                app.buttons["move.evening"].tap()
                XCTAssertTrue(row(i).label.contains("Evening"))
            case 5: // The planned market is closed; a wet courtyard is not a good substitute.
                chooseZines()
                let undo = app.buttons["Undo"]
                XCTAssertTrue(undo.waitForExistence(timeout: 10))
                undo.tap()
                XCTAssertTrue(row(5).exists && !row(8).exists)
                chooseZines()
                XCTAssertTrue(row(8).label.contains("Afternoon") && !row(5).exists)
            default: break
            }
        }
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "MAGNETBOARD_TEST_IDEAS")
        app.launch()
        plan.tap()
        for i in 0..<7 {
            if i > 0 { next.tap() }
            if i == 2 {
                XCTAssertFalse(row(2).exists)
            } else {
                let expected = i == 5 ? 8 : i
                reveal([row(expected)], in: scroll)
                XCTAssertTrue(row(expected).label.contains(i == 4 ? "Evening" : "Afternoon"))
            }
        }
    }
}
