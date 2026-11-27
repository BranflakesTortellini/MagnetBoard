import Foundation

extension PlannerRegressionChecks {
    // Fictional stops, pins and weather: a personal week, not live venue information.
    static func checkHamburgWeek(directory: URL) {
        let calendar = Calendar.current
        let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))!
        func at(_ offset: Int, _ hour: Int) -> Date {
            let date = calendar.date(byAdding: .day, value: offset, to: monday)!
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
        }
        func idea(_ name: String, _ latitude: Double? = nil, minutes: Int = 45, tags: [String] = []) -> IdeaItem {
            var item = IdeaItem(title: name)
            item.duration = Double(minutes * 60)
            item.tags = tags
            if let latitude { item.coordinate = CodableCoordinate(latitude: latitude, longitude: 9.998) }
            return item
        }
        let file = directory.appendingPathComponent("hamburg-plan.json")
        let boardFile = directory.appendingPathComponent("hamburg-board.json")
        let board = BoardViewModel(saveURL: boardFile)
        let plan = ScheduleViewModel(saveURL: file)
        let records = idea("Dig for records in St. Pauli")
        let clay = idea("Try a pottery studio")
        let sketch = idea("Draw by the Alster")
        let reunion = idea("Meet Lea at the station")
        let browse = idea("Browse bookshops with Lea")
        let market = idea("Waterfront print market", 53.545, minutes: 60)
        let brunch = idea("Long farewell brunch")
        let train = idea("Catch the train")
        let court = idea("Courtyard sketch", 53.5455, minutes: 20)
        let zines = idea("Browse the zine shop", 53.547, minutes: 30, tags: ["Indoor"])
        let cocoa = idea("Hot cocoa by the canal", 53.553, minutes: 40, tags: ["rainy day"])
        let far = idea("Record shop across town", 53.63, tags: ["indoor"])
        let long = idea("Two-hour workshop", 53.546, minutes: 120, tags: ["indoor"])
        let bad = idea("Bad imported pin", 95)
        var booked = idea("Sunday gallery booking", 53.546, tags: ["indoor"])
        booked.commitment = .scheduled
        board.ideas = [records, clay, sketch, reunion, browse, market, brunch, train, court, zines, cocoa, far, long, bad, booked]
        @discardableResult
        func place(_ item: IdeaItem, _ d: Int, _ hour: Int, exact: Bool = false) -> EventItem {
            let part: DayPart = hour < 12 ? .morning : (hour < 17 ? .afternoon : .evening)
            guard case let .scheduled(event) = plan.scheduleIdea(item, startDate: at(d, hour), locked: exact,
                    schedulePrecision: exact ? .exactTime : .dayPart, dayPart: part) else { preconditionFailure("Unexpected duplicate") }
            return event
        }
        place(records, 0, 10); place(clay, 1, 13)
        let rainyWalk = place(sketch, 2, 10)
        let friend = place(reunion, 3, 18, exact: true)
        let browsing = place(browse, 4, 9)
        let closed = place(market, 5, 13)
        let anchor = place(train, 5, 14, exact: true)
        place(brunch, 6, 10); place(booked, 6, 15)
        precondition((0..<7).allSatisfy { !plan.events(on: at($0, 12)).isEmpty })
        // Rain cancels a stop, not its underlying interest. Lea wants a late start on Friday.
        plan.deleteEvent(rainyWalk)
        precondition(plan.events(on: at(2, 12)).isEmpty && board.ideas.contains(sketch))
        precondition(plan.rescheduleRough(browsing.id, on: at(4, 12), part: .afternoon))
        precondition(plan.events(on: at(4, 12)).first?.dayPart == .afternoon)
        precondition(plan.events.contains(friend) && plan.events.contains(anchor))
        let options = plan.nearbyBackups(for: closed, board: board.ideas, indoorsOnly: false)
        precondition(options.map(\.id) == [court.id, zines.id, cocoa.id], "Distance/time/duplicate/pin filtering failed")
        let rain = plan.nearbyBackups(for: closed, board: board.ideas, indoorsOnly: true)
        precondition(rain.map(\.id) == [zines.id] && (150...300).contains(rain[0].meters), "An old rainy-day tag does not prove a place is indoors")
        precondition(plan.nearbyBackups(for: browsing, board: board.ideas, indoorsOnly: false).isEmpty)
        precondition(plan.backupOrigin(for: rainyWalk, board: board.ideas) == nil)
        precondition(plan.useBackup(court.id, insteadOf: closed, board: board.ideas, indoorsOnly: true) == nil)
        precondition(plan.useBackup(zines.id, insteadOf: anchor, board: board.ideas, indoorsOnly: false) == nil)
        guard let swapped = plan.useBackup(zines.id, insteadOf: closed, board: board.ideas, indoorsOnly: true) else {
            preconditionFailure("Closed market did not yield its slot to the saved zine shop")
        }
        precondition(swapped.id != closed.id && swapped.startDate == closed.startDate && swapped.dayPart == .afternoon)
        precondition(swapped.endDate == at(5, 13).addingTimeInterval(1800) && plan.events.contains(anchor))
        precondition(plan.useBackup(cocoa.id, insteadOf: closed, board: board.ideas, indoorsOnly: false) == nil)
        let reopened = ScheduleViewModel(saveURL: file)
        precondition(reopened.events(on: at(5, 12)) == [swapped, anchor])
        precondition(BoardViewModel(saveURL: boardFile).ideas.contains(market))
        precondition(reopened.undoBackup(swapped, restoring: closed, originalIdea: market))
        precondition(reopened.events(on: at(5, 12)) == [closed, anchor])
        print("Hamburg: seven days, solo + visitor plans, rain cancellation, late start, nearby replacement, train, relaunch and Undo: passed")
    }
}
