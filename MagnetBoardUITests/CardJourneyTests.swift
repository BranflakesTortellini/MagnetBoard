import XCTest

final class CardJourneyTests: XCTestCase {
    @MainActor
    func testAddDragAndScheduleCard() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-welcome.hasSeenMagnetBoardIntro", "YES", "-delight.reduceMotion", "YES",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        let title = "Gallery \(UUID().uuidString.prefix(8))"
        let elements = app.descendants(matching: .any)
        let add = app.buttons["board.newIdea"]
        XCTAssertTrue(add.waitForExistence(timeout: 15), "Board did not open")
        add.tap()
        let field = app.textFields["newIdea.title"]
        // The template gallery may push the field below the fold.
        for _ in 0..<5 where !field.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(field.isHittable, "Could not reach the new-card title")
        field.tap()
        field.typeText(title)
        app.buttons["newIdea.save"].tap()

        let boardCard = elements.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
                                                       "board.card.", title)).firstMatch
        XCTAssertTrue(boardCard.waitForExistence(timeout: 8), "Added card did not appear on the board")
        let id = String(boardCard.identifier.dropFirst("board.card.".count))
        XCTAssertNotNil(UUID(uuidString: id))
        let canvas = app.scrollViews["board.canvas"]
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
            if source.exists && source.isHittable && tray.frame.contains(source.frame.centerPoint) { break }
            tray.swipeLeft()
        }
        let morning = elements["drop.morning"]
        reveal([source, morning], in: scroll)
        XCTAssertTrue(source.isHittable && morning.isHittable, "Tray card and morning basket must both be reachable")
        let start = source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = morning.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 1.0, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.6)
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

    /// Move the outer scroll view in small increments, keeping both gesture
    /// endpoints inside the actual viewport (not merely in the accessibility tree).
    @MainActor
    private func reveal(_ items: [XCUIElement], in scroll: XCUIElement,
                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(scroll.waitForExistence(timeout: 8), file: file, line: line)
        for _ in 0..<18 {
            let visible = scroll.frame.insetBy(dx: 4, dy: 16)
            let frames = items.compactMap { item -> CGRect? in
                guard item.exists, !item.frame.isEmpty else { return nil }
                return item.frame
            }
            if frames.count == items.count && frames.allSatisfy({ visible.contains($0.centerPoint) }) {
                return
            }
            let above = frames.contains { $0.midY < visible.minY }
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: above ? 0.38 : 0.65))
            let end = start.withOffset(CGVector(dx: 0, dy: above ? 100 : -100))
            start.press(forDuration: 0.02, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        }
        XCTFail("Could not bring the requested elements into view", file: file, line: line)
    }
}

private extension CGRect {
    var centerPoint: CGPoint { CGPoint(x: midX, y: midY) }
}
