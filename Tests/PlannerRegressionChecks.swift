import Foundation

// Compiled with the production models, outside the app target. No personal
// documents, Maps queries, or Calendar authorization are needed for these cases.
@main
@MainActor
struct PlannerRegressionChecks {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_740_000_000))
        checkAnchoredOrder(day, file: directory.appendingPathComponent("order.json"))
        checkOvernight(day, file: directory.appendingPathComponent("overnight.json"))
        checkEstimates(day, file: directory.appendingPathComponent("estimates.json"))
        try checkOldSave(day, file: directory.appendingPathComponent("legacy.json"))
        checkRepeatAndUndo(day, file: directory.appendingPathComponent("undo.json"))
        try checkDamagedSave(day, file: directory.appendingPathComponent("damaged.json"))
        print("Planner regression checks passed.")
    }

    static func card(_ title: String, _ start: Date, minutes: Int = 30,
                     exact: Bool = false, locked: Bool = false) -> EventItem {
        EventItem(ideaID: UUID(), title: title, startDate: start,
                  endDate: start.addingTimeInterval(Double(minutes) * 60), isLocked: locked,
                  schedulePrecision: exact ? .exactTime : .dayOnly)
    }

    static func checkAnchoredOrder(_ day: Date, file: URL) {
        let vm = ScheduleViewModel(saveURL: file)
        let noon = day.addingTimeInterval(12 * 3600)
        let anchor = card("Locked", noon, locked: true)
        let a = card("A", noon)
        let b = card("B", noon.addingTimeInterval(3600), minutes: 75)
        vm.events = [b, anchor, a] // Deliberately different storage and displayed orders.
        vm.moveEvent(b.id, onto: a.id, on: day)
        let ordered = vm.events(on: day)
        precondition(ordered.map(\.id) == [anchor.id, b.id, a.id], "Drag jumped across a locked tie")
        precondition(ordered[0] == anchor && ordered[1].endDate == noon.addingTimeInterval(75 * 60))
        vm.moveEventWithinDay(b, on: day, direction: -1)
        precondition(vm.events(on: day) == ordered, "Nudge moved a locked anchor")
        precondition(ScheduleViewModel(saveURL: file).events(on: day) == ordered, "Order changed on relaunch")
    }

    static func checkOvernight(_ day: Date, file: URL) {
        let vm = ScheduleViewModel(saveURL: file)
        let overnight = card("Overnight", day.addingTimeInterval(-3600), minutes: 120, exact: true)
        let morning = card("Morning", day, exact: true)
        let one = day.addingTimeInterval(3600)
        vm.events = [morning, overnight]
        precondition(vm.conflictWarnings(for: day).count == 1, "Missed yesterday's appointment")
        precondition(vm.firstOpenSlot(on: day, preferredHour: 0, duration: 1800) == one)
        vm.moveEvent(morning, to: one)
        precondition(vm.conflictWarnings(for: day).isEmpty, "Touching endpoints are not a conflict")
        precondition(planningHour(one, relativeTo: overnight.startDate) == 25)
        precondition(vm.dayBoundaryWarnings(for: overnight.startDate, startHour: 0, endHour: 23).count == 1)
        precondition(vm.dayBoundaryWarnings(for: overnight.startDate, startHour: 0, endHour: 26).isEmpty)
        _ = vm.deleteEvents(on: day)
        precondition(vm.events == [overnight], "Clearing today deleted yesterday's appointment")
    }

    static func checkEstimates(_ day: Date, file: URL) {
        let vm = ScheduleViewModel(saveURL: file)
        let a = card("A", day), b = card("B", day.addingTimeInterval(3600))
        let c = card("C", day.addingTimeInterval(7200))
        vm.events = [a, b, c]
        precondition(vm.setManualTravelEstimate(after: a, to: b.id, minutes: 0, note: " Same venue "))
        let zero = TravelLegStatus.manualEstimate(seconds: 0, note: "Same venue")
        let summary = vm.plainTextPlanSummary(on: day, planName: "", homeBaseName: "",
                                              travelLegStatuses: [a.id: zero, c.id: .manualEstimate(seconds: 900, note: nil)])
        precondition(summary.contains("0m known travel"), "Zero or non-departing legs counted incorrectly")
        precondition(TravelLegStatus.knownTotal([nil, .missingCoordinates]) == nil)
        vm.moveEventWithinDay(c, on: day, direction: -1)
        precondition(vm.events(on: day).map(\.id) == [a.id, c.id, b.id])
        precondition(!vm.setManualTravelEstimate(after: a, to: b.id, minutes: 45, note: nil),
                     "An editor for the old route overwrote the new route")
        let reopened = ScheduleViewModel(saveURL: file)
        precondition(reopened.events(on: day)[0].manualTravel(to: c.id) == nil, "A to B leaked onto A to C")
        precondition(!reopened.setManualTravelEstimate(after: b, to: nil, minutes: 20, note: nil))
        reopened.moveEventWithinDay(b, on: day, direction: -1)
        precondition(reopened.events(on: day)[0].manualTravel(to: b.id) == zero, "Lost original route estimate")
    }

    static func checkOldSave(_ day: Date, file: URL) throws {
        var a = card("A", day), b = card("B", day), last = card("Last", day.addingTimeInterval(7200))
        a.manualTravelToNextSeconds = 600
        b.manualTravelToNextSeconds = 0
        last.manualTravelToNextSeconds = 300
        // The original format had only seconds and a note; it had no destination key.
        let legacy = try JSONEncoder.prettyDateEncoder.encode([last, a, b])
        precondition(!String(decoding: legacy, as: UTF8.self).contains("manualTravelTarget"))
        try legacy.write(to: file)
        let vm = ScheduleViewModel(saveURL: file)
        let next = card("New", day.addingTimeInterval(10800))
        vm.restoreEvent(next)
        let saved = ScheduleViewModel(saveURL: file).events(on: day)
        precondition(saved.map(\.id) == [a.id, b.id, last.id, next.id])
        precondition(saved[0].manualTravel(to: b.id)?.seconds == 600)
        precondition(saved[1].manualTravel(to: last.id)?.seconds == 0)
        precondition(saved[2].manualTravel(to: next.id) == nil, "Old last stop adopted a new destination")
    }

    static func checkRepeatAndUndo(_ day: Date, file: URL) {
        let vm = ScheduleViewModel(saveURL: file)
        let reservation = IdeaItem(title: "Reservation")
        var breakIdea = IdeaItem(title: "Coffee")
        breakIdea.allowsMultipleScheduledInstances = true
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        guard case .scheduled(let dinner) = vm.scheduleIdea(reservation, startDate: day),
              case .duplicateNotAllowed(let original) = vm.scheduleIdea(reservation, startDate: tomorrow),
              case .scheduled(let first) = vm.scheduleIdea(breakIdea, startDate: day.addingTimeInterval(3600)),
              case .scheduled(let second) = vm.scheduleIdea(breakIdea, startDate: tomorrow) else {
            preconditionFailure("One-off and repeatable cards must have different duplicate rules")
        }
        precondition(original.id == dinner.id && first.id != second.id)
        let removed = vm.deleteEvents(on: day)
        precondition(vm.events == [second], "Clearing today changed tomorrow")
        vm.restoreEvents(removed)
        vm.restoreEvents(removed)
        let reopened = ScheduleViewModel(saveURL: file)
        precondition(reopened.events(on: day) == [dinner, first] && reopened.events(on: tomorrow) == [second],
                     "Restoring a cleared day lost, duplicated, or changed a placement")
        print("One-off vs repeatable, clear-day scope, restore and relaunch: passed")
    }

    static func checkDamagedSave(_ day: Date, file: URL) throws {
        let original = Data("[unfinished".utf8)
        try original.write(to: file)
        let vm = ScheduleViewModel(saveURL: file)
        precondition(vm.storageIssue != nil, "Unreadable schedule was presented as a clean plan")
        vm.restoreEvent(card("Session only", day))
        let after = try Data(contentsOf: file)
        precondition(after == original, "Editing the session overwrote a damaged file")
        print("Unreadable schedule preserved byte-for-byte: passed")
    }
}
