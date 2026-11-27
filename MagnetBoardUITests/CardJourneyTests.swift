import XCTest

final class CardJourneyTests: XCTestCase {
    @MainActor
    func testBasketFirstCreatesCardAndBlocksDuplicate() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-welcome.hasSeenMagnetBoardIntro", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.tabBars.buttons["Plan"].tap()
        let scroll = app.scrollViews["plan.scroll"]
        let evening = app.buttons["drop.evening"]
        reveal([evening], in: scroll)
        evening.tap()
        let input = app.textFields["planPicker.title"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        let title = "Lakeside \(Int.random(in: 100000...999999))"
        input.tap()
        input.typeText(title)
        XCTAssertEqual(input.value as? String, title)
        input.typeText("\n")

        let placed = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@ AND label CONTAINS %@",
            "planned.card.", title, "Evening")).firstMatch
        reveal([placed], in: scroll)
        let id = String(placed.identifier.dropFirst("planned.card.".count))
        reveal([evening], in: scroll)
        evening.tap()
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText(title)
        XCTAssertEqual(input.value as? String, title)
        let existing = app.buttons["planPicker.card.\(id)"]
        XCTAssertTrue(existing.waitForExistence(timeout: 8))
        XCTAssertFalse(existing.isEnabled, "One-off placement was offered a second time")
        XCTAssertTrue(existing.label.contains(title))
        XCTAssertFalse(app.buttons["planPicker.confirm"].isEnabled, "An existing one-off card could be added again")
        input.typeText("\n")
        XCTAssertTrue(input.exists, "Keyboard submission accepted a duplicate")
        app.buttons["Cancel"].tap()
        app.terminate()
        app.launch()
        app.tabBars.buttons["Plan"].tap()
        reveal([placed], in: scroll)
        XCTAssertTrue(placed.label.contains(title), "Quick-added placement was lost on relaunch")
        let placements = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "planned.card.", title))
        XCTAssertEqual(placements.count, 1)
    }

    @MainActor
    func testPickBoardCardFromBasketThenUndo() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-welcome.hasSeenMagnetBoardIntro", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.tabBars.buttons["Plan"].tap()
        let scroll = app.scrollViews["plan.scroll"]
        let morning = app.buttons["drop.morning"]
        reveal([morning], in: scroll)
        morning.tap()
        let field = app.textFields["planPicker.title"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("Wunderland")
        let museum = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                                       "planPicker.card.", "Miniatur Wunderland")).firstMatch
        let id = String(museum.identifier.dropFirst("planPicker.card.".count))
        museum.tap()
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 10))
        undo.tap()
        morning.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("Wunderland")
        let restored = app.buttons["planPicker.card.\(id)"]
        XCTAssertTrue(restored.isEnabled, "Undo did not return the original one-off card to the available list")
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["planned.card.\(id)"].exists)
    }

    @MainActor
    func testTapToScheduleRepeatableCard() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-welcome.hasSeenMagnetBoardIntro", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.tabBars.buttons["Plan"].tap()
        let scroll = app.scrollViews["plan.scroll"]
        let elements = app.descendants(matching: .any)
        let card = elements.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
                                                 "tray.card.", "Saturday market,")).firstMatch
        let afternoon = elements["drop.afternoon"]
        reveal([card, afternoon], in: scroll)
        let id = String(card.identifier.dropFirst("tray.card.".count))
        card.tap()
        afternoon.tap()
        let placed = elements.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@",
                                                   "planned.card.\(id)", "Afternoon")).firstMatch
        reveal([placed], in: scroll)
        XCTAssertTrue(placed.label.contains("Saturday market"))
        reveal([card], in: scroll)
        XCTAssertTrue(card.exists, "A repeatable market stop disappeared from the tray")
    }

    @MainActor
    func testCancelEditingBoardCardPreservesOriginal() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-welcome.hasSeenMagnetBoardIntro", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let name = "Market \(Int.random(in: 100000...999999))"
        app.buttons["board.newIdea"].tap()
        let newTitle = app.textFields["newIdea.title"]
        XCTAssertTrue(newTitle.waitForExistence(timeout: 10))
        newTitle.tap()
        newTitle.typeText(name)
        XCTAssertEqual(newTitle.value as? String, name)
        newTitle.typeText("\n")
        let canvas = app.scrollViews["board.canvas"]
        let original = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "board.card.", name + ",")).firstMatch
        reveal([original], in: canvas)
        let originalID = original.identifier
        original.tap()
        let title = app.textFields["cardDetails.title"]
        guard title.waitForExistence(timeout: 10) else {
            print(app.debugDescription)
            return XCTFail("A single tap on a new board card did not open its title for editing")
        }
        XCTAssertEqual(title.value as? String, name, "Tapping a card opened a different card")
        title.tap()
        title.typeText(" revised")
        XCTAssertNotEqual(title.value as? String, name)
        let nav = app.navigationBars["Card details"]
        XCTAssertFalse(nav.buttons["Delete"].exists)
        nav.buttons["Cancel"].tap()
        let saved = app.descendants(matching: .any)[originalID]
        XCTAssertTrue(saved.waitForExistence(timeout: 10), "Cancel deleted the original card")
        XCTAssertTrue(saved.label.hasPrefix(name + ","), "Cancel saved the draft rename")
    }

    @MainActor
    func testWelcomeAndCancelNewCard() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-welcome.hasSeenMagnetBoardIntro", "NO", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let help = app.navigationBars["How it works"]
        XCTAssertTrue(help.waitForExistence(timeout: 15), "A first-time user did not get the introduction")
        help.buttons["Done"].tap()
        let add = app.buttons["board.newIdea"]
        XCTAssertTrue(add.waitForExistence(timeout: 8))
        add.tap()
        let save = app.buttons["newIdea.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "The app accepted an untitled card")
        let field = app.textFields["newIdea.title"]
        for _ in 0..<5 where !field.isHittable { app.swipeUp(velocity: .slow) }
        field.tap()
        let title = "Discard \(UUID().uuidString.prefix(8))"
        field.typeText(title)
        XCTAssertTrue(save.isEnabled)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(add.waitForExistence(timeout: 8))
        let discarded = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "board.card.", title)).firstMatch
        XCTAssertFalse(discarded.exists, "Cancel added the draft to the board")
    }

    @MainActor
    func testAddDragAndScheduleCard() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-welcome.hasSeenMagnetBoardIntro", "YES", "-delight.reduceMotion", "YES",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        let title = "Gallery \(Int.random(in: 100000...999999))"
        let elements = app.descendants(matching: .any)
        let add = app.buttons["board.newIdea"]
        XCTAssertTrue(add.waitForExistence(timeout: 15), "Board did not open")
        add.tap()
        let field = app.textFields["newIdea.title"]
        XCTAssertTrue(field.waitForExistence(timeout: 12))
        XCTAssertTrue(field.isHittable, "Could not reach the new-card title")
        field.tap()
        field.typeText(title)
        let fullTitle = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", title), object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [fullTitle], timeout: 12), .completed,
                       "The title field did not accept the requested name")
        let save = app.buttons["newIdea.save"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(add.waitForExistence(timeout: 15), "Saving did not return to the board")

        let boardCard = elements.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
                                                       "board.card.", title)).firstMatch
        let canvas = app.scrollViews["board.canvas"]
        if !boardCard.waitForExistence(timeout: 10) {
            // Persisted board locations can put a newly added card below the viewport.
            let edge = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.75))
            edge.press(forDuration: 0.02, thenDragTo: edge.withOffset(CGVector(dx: 0, dy: -160)))
        }
        guard boardCard.waitForExistence(timeout: 10) else {
            print(app.debugDescription)
            XCTFail("Saved card named \(title) did not appear on the board")
            return
        }
        let id = String(boardCard.identifier.dropFirst("board.card.".count))
        XCTAssertNotNil(UUID(uuidString: id))
        reveal([boardCard], in: canvas)
        XCTAssertEqual(boardCard.value as? String, "Ideas")
        let center = boardCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // New cards start at board x=120...320. Move left into the Must do zone
        // (x < 270), keeping the touch away from the screen-edge gesture.
        let dx = min(105, center.screenPoint.x - canvas.frame.minX - 24)
        XCTAssertGreaterThan(dx, 50)
        center.press(forDuration: 0.65, thenDragTo: center.withOffset(CGVector(dx: -dx, dy: 0)))
        let moved = NSPredicate(format: "value == %@", "Must do")
        let movedExpectation = XCTNSPredicateExpectation(predicate: moved, object: boardCard)
        XCTAssertEqual(XCTWaiter.wait(for: [movedExpectation], timeout: 8), .completed,
                       "The board drag did not change the card's group")

        let plan = app.tabBars.buttons["Plan"]
        plan.tap()
        let scroll = app.scrollViews["plan.scroll"]
        let tray = app.scrollViews["plan.tray"]
        reveal([tray], in: scroll)
        let source = elements["tray.card.\(id)"]
        for _ in 0..<10 {
            // XCTest on iOS 18 can fail the test (rather than return false)
            // when asked for the hit point of an offscreen horizontal item.
            if source.exists, !source.frame.isEmpty,
               tray.frame.insetBy(dx: 8, dy: 0).contains(source.frame.centerPoint) { break }
            tray.swipeLeft(velocity: .slow)
        }
        let morning = elements["drop.morning"]
        reveal([source, morning], in: scroll)
        let sourcePoint = source.frame.centerPoint
        let destination = morning.frame.centerPoint
        XCTAssertTrue(tray.frame.contains(sourcePoint) && scroll.frame.contains(sourcePoint) &&
                      scroll.frame.contains(destination), "Both drag endpoints must be on screen")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: sourcePoint.x - app.frame.minX, dy: sourcePoint.y - app.frame.minY))
        let end = origin.withOffset(CGVector(dx: destination.x - app.frame.minX, dy: destination.y - app.frame.minY))
        print("Dragging the new card from \(sourcePoint) to the Morning basket at \(destination)")
        start.press(forDuration: 1.0, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.6)
        print("After drop: tray still has card: \(source.exists); Morning row: \(elements["planned.card.\(id)"].exists)")
        let scheduled = elements["planned.card.\(id)"]
        reveal([scheduled], in: scroll)
        XCTAssertTrue(scheduled.label.contains(title) && scheduled.label.contains("Morning"),
                      "Dropping the tray card did not schedule it for the morning")
        XCTAssertFalse(source.exists, "A non-repeatable card should leave the tray")

        app.terminate()
        app.launch()
        plan.tap()
        reveal([scheduled], in: scroll)
        XCTAssertTrue(scheduled.label.contains(title) && scheduled.label.contains("Morning"),
                      "Scheduled placement was lost on relaunch")
    }

    @MainActor
    func testMoveMorningCardToTomorrowAfternoon() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-welcome.hasSeenMagnetBoardIntro", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let plan = app.tabBars.buttons["Plan"]
        plan.tap()
        let scroll = app.scrollViews["plan.scroll"]
        let morning = app.buttons["drop.morning"]
        reveal([morning], in: scroll)
        morning.tap()
        let name = "Harbour \(Int.random(in: 100000...999999))"
        let input = app.textFields["planPicker.title"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText(name)
        app.buttons["planPicker.confirm"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                                   "planned.card.", name)).firstMatch
        reveal([row], in: scroll)
        let id = row.identifier
        XCTAssertTrue(row.label.contains("Morning"))
        row.tap()
        XCTAssertTrue(app.navigationBars["Move card"].waitForExistence(timeout: 8))
        app.buttons["Tomorrow"].tap()
        app.buttons["move.afternoon"].tap()
        let moved = app.buttons[id]
        reveal([moved], in: scroll)
        XCTAssertTrue(moved.label.contains("Afternoon"))
        app.terminate()
        app.launch()
        plan.tap()
        XCTAssertTrue(app.buttons["Next day"].waitForExistence(timeout: 8))
        XCTAssertFalse(moved.exists, "The card was left on its original day")
        app.buttons["Next day"].tap()
        reveal([moved], in: scroll)
        XCTAssertTrue(moved.label.contains(name) && moved.label.contains("Afternoon"))
    }

    @MainActor
    func testFindAndEditOneOfThirtyOverlappingCards() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let target = UUID()
        let fixture: [[String: Any]] = (1...30).map { index in
            ["id": (index == 1 ? target : UUID()).uuidString, "title": "Gallery \(index)",
             "tags": [index == 1 ? "riverfront" : "indoor"], "boardX": 180, "boardY": 200]
        }
        app.launchEnvironment["MAGNETBOARD_TEST_BOARD"] = UUID().uuidString
        app.launchEnvironment["MAGNETBOARD_TEST_IDEAS"] = String(decoding: try JSONSerialization.data(withJSONObject: fixture), as: UTF8.self)
        app.launchArguments = ["-welcome.hasSeenMagnetBoardIntro", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let find = app.buttons["board.find"]
        XCTAssertTrue(find.waitForExistence(timeout: 10))
        find.tap()
        let field = app.textFields["board.find.query"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["board.find.count"].label.contains("30"))
        field.tap()
        field.typeText("riverfront")
        let result = app.buttons["board.result.\(target)"]
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        result.tap()
        let title = app.textFields["cardDetails.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertEqual(title.value as? String, "Gallery 1")
        title.tap()
        title.typeText(" North")
        let edited = try XCTUnwrap(title.value as? String)
        XCTAssertTrue(edited.contains("North"))
        app.buttons["Save"].tap()
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "MAGNETBOARD_TEST_IDEAS")
        app.launch()
        find.tap()
        XCTAssertTrue(app.staticTexts["board.find.count"].label.contains("30"))
        field.tap()
        field.typeText("North")
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertTrue(result.label.contains(edited))
    }

    /// Move the outer scroll view in small increments, keeping both gesture
    /// endpoints inside the actual viewport (not merely in the accessibility tree).
    @MainActor
    private func reveal(_ items: [XCUIElement], in scroll: XCUIElement,
                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(scroll.waitForExistence(timeout: 8), file: file, line: line)
        let app = XCUIApplication()
        let window = app.frame
        let bottom = app.tabBars.firstMatch.frame.minY
        let top = max(window.minY, app.navigationBars.firstMatch.frame.maxY)
        let unobscured = CGRect(x: window.minX, y: top, width: window.width, height: bottom - top)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        for _ in 0..<18 {
            // SwiftUI's scroll frame can extend underneath the bottom tab bar.
            // Keep a further margin so a drag does not trigger edge autoscroll.
            let visible = scroll.frame.intersection(unobscured).insetBy(dx: 6, dy: 36)
            let frames = items.compactMap { item -> CGRect? in
                guard item.exists, !item.frame.isEmpty else { return nil }
                return item.frame
            }
            if frames.count == items.count && frames.allSatisfy({ visible.contains($0.centerPoint) }) {
                return
            }
            let above = frames.contains { $0.midY < visible.minY }
            let start = origin.withOffset(CGVector(dx: visible.maxX - window.minX - 6,
                                                   dy: visible.midY - window.minY))
            let end = start.withOffset(CGVector(dx: 0, dy: above ? 100 : -100))
            start.press(forDuration: 0.02, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        }
        print(app.debugDescription)
        XCTFail("Could not bring the requested elements above the tab bar", file: file, line: line)
    }
}

private extension CGRect {
    var centerPoint: CGPoint { CGPoint(x: midX, y: midY) }
}
