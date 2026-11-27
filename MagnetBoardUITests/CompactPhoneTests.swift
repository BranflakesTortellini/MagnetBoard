import XCTest

final class CompactPhoneTests: XCTestCase {
    @MainActor
    func testLargeTextKeyboardAndUndoOnSmallPhone() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-welcome.hasSeenMagnetBoardIntro", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        XCTAssertLessThanOrEqual(app.frame.width, 375, "Use an iPhone SE rather than a large simulator")
        app.tabBars.buttons["Plan"].tap()
        let scroll = app.scrollViews["plan.scroll"]
        let morning = app.buttons["drop.morning"]
        let heading = app.staticTexts["Add to day"]
        let bar = app.tabBars.firstMatch
        for _ in 0..<18 {
            let visible = scroll.frame.intersection(CGRect(x: 0, y: 0, width: app.frame.width, height: bar.frame.minY))
            if morning.exists && visible.insetBy(dx: 0, dy: 12).contains(CGPoint(x: morning.frame.midX, y: morning.frame.midY)) { break }
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: visible.maxX - 8, dy: visible.midY + 35))
            start.press(forDuration: 0.02, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -85)), withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertGreaterThan(heading.frame.height, 30, "The simulator did not actually render an accessibility-size headline")
        XCTAssertTrue(morning.isHittable)
        morning.tap()
        let field = app.textFields["planPicker.title"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        // Unlike injected typing, a physical tap on a key must wait for the
        // real software keyboard, not the one-time Slide to Type preview.
        let intro = app.otherElements["UIContinuousPathIntroductionView"].buttons["Continue"]
        if intro.waitForExistence(timeout: 3) { intro.tap() }
        let title = "Tea \(Int.random(in: 10000...99999))"
        field.typeText(title)
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 8))
        XCTAssertLessThanOrEqual(field.frame.maxY, keyboard.frame.minY + 1)
        XCTAssertTrue(app.buttons["planPicker.confirm"].isHittable)
        // iOS exposes the return key as a Key or a Button with a localized
        // lowercase label, depending on keyboard layout.
        let done = keyboard.descendants(matching: .any).matching(NSPredicate(
            format: "label ==[c] %@ OR identifier ==[c] %@", "done", "done")).firstMatch
        XCTAssertTrue(done.isHittable && !done.frame.isEmpty && app.frame.contains(done.frame))
        done.tap()
        let undo = app.buttons["Undo"]
        guard undo.waitForExistence(timeout: 10) else {
            print(app.debugDescription)
            return XCTFail("Tapping Done did not schedule the card and offer Undo")
        }
        XCTAssertTrue(undo.isHittable && app.frame.contains(undo.frame))
        undo.tap()
        XCTAssertFalse(undo.exists)
        morning.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        field.typeText(title)
        let original = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "planPicker.card.", title)).firstMatch
        XCTAssertTrue(original.waitForExistence(timeout: 8) && original.isEnabled, "Undo must leave the original card available")
    }
}
