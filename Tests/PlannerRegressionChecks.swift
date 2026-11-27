import Foundation
import MapKit

// Compiled with the production models, outside the app target. No personal
// documents, Maps queries, or Calendar authorization are needed for these cases.
@main
@MainActor
struct PlannerRegressionChecks {
    static func main() async throws {
        if CommandLine.arguments.contains("--probe-hamburg-transit") {
            await sampleHamburgTransit()
            return
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_740_000_000))
        checkAnchoredOrder(day, file: directory.appendingPathComponent("order.json"))
        checkOvernight(day, file: directory.appendingPathComponent("overnight.json"))
        checkEstimates(day, file: directory.appendingPathComponent("estimates.json"))
        try checkOldSave(day, file: directory.appendingPathComponent("legacy.json"))
        checkRepeatAndUndo(day, file: directory.appendingPathComponent("undo.json"))
        checkMoveAcrossDays(day, file: directory.appendingPathComponent("move.json"))
        checkHamburgWeek(directory: directory)
        try checkTripGuide()
        checkDestinationClock(file: directory.appendingPathComponent("hamburg-clock.json"))
        try checkDamagedSave(day, file: directory.appendingPathComponent("damaged.json"))
        print("Planner regression checks passed.")
    }

    /// Non-gating service diagnostic. Query near today's timetable, not the
    /// fixed future date used for the reproducible iPhone regression.
    static func sampleHamburgTransit() async {
        let clock = TripClock(zone: TimeZone(identifier: "Europe/Berlin")!)
        let nextDay = clock.calendar.date(byAdding: .day, value: 1, to: Date())!
        let departure = clock.calendar.date(bySettingHour: 15, minute: 0, second: 0, of: nextDay)!
        let vm = ScheduleViewModel(saveURL: nil, deviceZone: clock.zone)
        print("Live Hamburg transit: \(clock.date(departure)), depart \(clock.time(departure)) from Kunsthalle towards Speicherstadt.")
        let (result, _) = await vm.travelEstimate(from: .init(latitude: 53.555, longitude: 10.003),
            to: .init(latitude: 53.543, longitude: 9.988), mode: .transit, departureDate: departure)
        if let seconds = result.seconds {
            print("Live Hamburg transit: \(result.label); arrival \(clock.time(departure.addingTimeInterval(seconds))).")
        } else {
            print("Live Hamburg transit unavailable: \(result.label). No live duration verified.")
        }
    }

    static func checkDestinationClock(file: URL) {
        let suite = "MagnetBoard.ClockChecks.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let formatter = ISO8601DateFormatter()
        func utc(_ s: String) -> Date { formatter.date(from: s)! }
        let home = TimeZone(identifier: "America/Los_Angeles")!, hamburg = TimeZone(identifier: "Europe/Berlin")!
        let vm = ScheduleViewModel(saveURL: file, clockDefaults: defaults, deviceZone: home)
        precondition(vm.clock.zone == home)
        vm.useTripZone(hamburg)
        for (day, start) in [("2027-07-10", "12"), ("2027-01-10", "13"), ("2027-03-20", "13")] {
            // March 20 falls between the US and European spring transitions.
            let instant = vm.firstOpenSlot(on: utc("\(day)T10:00:00Z"), preferredHour: 14)
            precondition(instant == utc("\(day)T\(start):00:00Z"))
        }
        var museum = IdeaItem(title: "Museum")
        museum.duration = 3600
        let day = utc("2027-07-10T12:00:00Z")
        guard case let .scheduled(visit) = vm.scheduleIdea(museum, startDate: vm.firstOpenSlot(on: day, preferredHour: 14))
        else { preconditionFailure("Could not schedule museum") }
        precondition(visit.startDate == day && visit.endDate == utc("2027-07-10T13:00:00Z"))
        let arrived = ScheduleViewModel(saveURL: file, clockDefaults: defaults, deviceZone: hamburg)
        let abroad = ScheduleViewModel(saveURL: file, clockDefaults: defaults, deviceZone: TimeZone(identifier: "Asia/Tokyo")!)
        for reopened in [arrived, abroad] {
            precondition(reopened.clock.zone == hamburg && reopened.events(on: day) == [visit])
            precondition(reopened.clock.calendar.component(.hour, from: visit.startDate) == 14)
            precondition(reopened.clock.calendar.component(.hour, from: visit.endDate) == 15)
        }
        let early = card("Early train", utc("2027-07-09T22:15:00Z"))
        arrived.restoreEvent(early)
        precondition(arrived.events(on: day).first == early, "00:15 belongs to July 10 in Hamburg")
        let nearMidnight = utc("2027-07-10T06:30:00Z") // Still July 9 in Los Angeles.
        let sameDay = vm.clock.keepingDay(nearMidnight, from: TripClock(zone: home))
        precondition(TripCalendar.dateKey(sameDay, zone: hamburg) == "2027-07-09")
        arrived.useTripZone(home)
        precondition(arrived.events.first { $0.id == visit.id } == visit, "Zone edits must not move a booking")
        print("Hamburg 14:00 from Los Angeles: summer, winter, DST mismatch, relaunch, midnight and existing bookings passed.")
    }

    static func checkTripGuide() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: "MagnetBoard/TravelHolidays.json"))
        let guide = try JSONDecoder().decode(TripCalendar.self, from: data)
        let day = ISO8601DateFormatter().date(from: "2026-10-03T12:00:00Z")!
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        let nearMidnight = ISO8601DateFormatter().date(from: "2026-10-02T22:30:00Z")!
        precondition(TripCalendar.dateKey(nearMidnight, zone: berlin) == "2026-10-03")
        precondition(guide.calendars["DE"]?["2026-10-03"] == "German Unity Day")
        precondition(guide.calendars["DE-HH"]?["2026-10-31"] == "Reformation Day")
        precondition(guide.calendars["DE"]?["2026-10-31"] == nil)
        precondition(guide.calendars["GB-ENG"]?["2026-12-28"]?.contains("observed") == true)
        precondition(guide.calendars["DE"]?["2031-01-01"] == nil)
        var first = card("Museum", day), second = card("Lunch", day.addingTimeInterval(3600))
        var pin = CodableCoordinate(latitude: 53.54, longitude: 9.99)
        pin.countryCode = "DE"
        first.coordinate = pin
        pin.countryCode = "DK"
        second.coordinate = pin
        precondition(TripCalendar.destinations([first, second], fallback: "DE-HH") == ["DE-HH", "DK"])
        precondition(TripCalendar.destinations([], fallback: "GB") == ["GB"])
        precondition(!OpeningTip.search("Sunday grocery Germany", destinations: ["US"]).isEmpty)
        precondition(OpeningTip.search("", destinations: ["US"]).isEmpty)
        let coord = pin.clLocationCoordinate2D
        let transit = ScheduleViewModel.tripDirectionsRequest(from: coord, to: coord, mode: .transit, date: first.endDate, arriveBy: false)
        precondition(transit?.transportType == .transit && transit?.departureDate == first.endDate && transit?.arrivalDate == nil)
        let walk = ScheduleViewModel.tripDirectionsRequest(from: coord, to: coord, mode: .walking, date: first.startDate, arriveBy: true)
        precondition(walk?.transportType == .walking && walk?.arrivalDate == first.startDate && walk?.departureDate == nil)
        precondition(ScheduleViewModel.tripDirectionsRequest(from: nil, to: coord, mode: .transit, date: day, arriveBy: false) == nil)
        print("Offline holidays, subdivisions, cross-border days, opening tips, timed transit and walking requests: passed")
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

    static func checkMoveAcrossDays(_ day: Date, file: URL) {
        let vm = ScheduleViewModel(saveURL: file)
        let next = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        let afternoon = Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: next)!
        var morning = card("Harbour walk", day.addingTimeInterval(9 * 3600), minutes: 45)
        morning.dayPart = .morning
        morning.schedulePrecision = .dayPart
        morning.isMustDo = true
        let anchor = card("Reservation", afternoon, minutes: 30, exact: true)
        var repeatVisit = morning
        repeatVisit.id = UUID()
        repeatVisit.isLocked = true
        vm.events = [morning, anchor, repeatVisit]
        precondition(!vm.rescheduleRough(anchor.id, on: day, part: nil))
        precondition(!vm.rescheduleRough(repeatVisit.id, on: next, part: .evening))
        precondition(vm.rescheduleRough(morning.id, on: next, part: .afternoon))
        let moved = ScheduleViewModel(saveURL: file).events.first { $0.id == morning.id }!
        precondition(moved.ideaID == morning.ideaID && moved.isMustDo && moved.dayPart == .afternoon)
        precondition(moved.startDate == anchor.endDate && moved.endDate.timeIntervalSince(moved.startDate) == 45 * 60)
        precondition(vm.events(on: day) == [repeatVisit] && vm.events(on: next) == [anchor, moved])
        vm.setMustDo(moved, false)
        precondition(vm.undoReschedule(from: moved, to: morning))
        var expected = morning
        expected.isMustDo = false
        precondition(vm.events.first { $0.id == morning.id } == expected)
        precondition(!vm.undoReschedule(from: moved, to: morning))
        print("Cross-day move, lock, exact time, repeat placement, duration, persistence and undo: passed")
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
