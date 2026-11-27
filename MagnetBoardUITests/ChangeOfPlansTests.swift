import XCTest

final class ChangeOfPlansTests: XCTestCase {
    @MainActor
    func testHolidayDayTravelAndSearchableLocalGuide() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-welcome.hasSeenMagnetBoardIntro", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["MAGNETBOARD_TEST_BOARD"] = UUID().uuidString
        app.launchEnvironment["MAGNETBOARD_TEST_DAY"] = "2026-10-03T12:00:00Z"
        let events: [[String: Any]] = ["Museum", "Lunch"].enumerated().map { index, title in
            var row: [String: Any] = ["id": UUID().uuidString, "ideaID": UUID().uuidString, "title": title,
                "startDate": index == 0 ? "2026-10-03T13:00:00Z" : "2026-10-03T15:00:00Z",
                "endDate": index == 0 ? "2026-10-03T14:00:00Z" : "2026-10-03T16:00:00Z",
                "coordinate": ["latitude": 53.55 + 0.01 * Double(index), "longitude": 9.99, "countryCode": "DE"]]
            // A saved estimate lets this journey run without a live Maps service.
            if index == 0 { row["manualTravelToNextSeconds"] = 900 }
            return row
        }
        app.launchEnvironment["MAGNETBOARD_TEST_EVENTS"] = String(decoding: try JSONSerialization.data(withJSONObject: events), as: UTF8.self)
        app.launch()
        app.tabBars.buttons["Plan"].tap()
        func identified(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
        let scroll = app.scrollViews["plan.scroll"]
        let holiday = identified("trip.holiday")
        XCTAssertTrue(holiday.waitForExistence(timeout: 10))
        XCTAssertTrue(holiday.label.contains("German Unity Day"), holiday.label)
        let checked = identified("travel.checked")
        XCTAssertFalse(checked.exists, "Opening a day must not refresh Maps")
        let mode = app.buttons["travel.mode"]
        mode.tap()
        app.buttons["Transit"].tap()
        let refresh = app.buttons["travel.refresh"]
        XCTAssertTrue(refresh.isEnabled)
        refresh.tap()
        XCTAssertTrue(checked.waitForExistence(timeout: 8))
        let manual = app.staticTexts["Manual travel estimate: 15 min"]
        let directions = app.buttons["Bus, stops & transfers in Maps"]
        reveal([directions], in: scroll)
        XCTAssertTrue(manual.exists)
        XCTAssertTrue(directions.isHittable)
        let guide = app.buttons["trip.guide"]
        reveal([guide], in: scroll)
        guide.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap()
        search.typeText("Sunday groceries")
        XCTAssertTrue(app.staticTexts["Sunday groceries in Germany"].exists)
        search.buttons["Clear text"].tap()
        search.typeText("France")
        XCTAssertTrue(app.staticTexts["Sunday groceries in France"].waitForExistence(timeout: 8))
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        app.buttons["Done"].firstMatch.tap()
        app.buttons["Next day"].tap()
        XCTAssertFalse(holiday.exists)
        XCTAssertFalse(checked.exists)
        XCTAssertFalse(refresh.isEnabled)
    }

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
            if i == 8 || i == 9 { idea["tags"] = ["indoors"] }
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
            let scope = app.segmentedControls["backup.scope"]
            XCTAssertTrue(scope.buttons["All nearby"].isSelected)
            let rain = scope.buttons["Indoors"]
            rain.tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: rain)
            let filtered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: outdoor)
            XCTAssertEqual(XCTWaiter.wait(for: [selected, filtered], timeout: 8), .completed,
                           "Indoors must be selected and remove the outdoor stop")
            XCTAssertTrue(app.buttons["backup.map.\(ids[8])"].exists)
            XCTAssertTrue(zines.isHittable, "The saved indoor stop must remain available")
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
