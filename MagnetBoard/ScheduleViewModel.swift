import Foundation
import EventKit
import MapKit
import CoreLocation
import Combine

/// View model for scheduled placements and optional system calendar integration.
@MainActor
public final class ScheduleViewModel: ObservableObject {
    @Published public var events: [EventItem] = [] {
        didSet { save() }
    }
    @Published private(set) var storageIssue: String?
    @Published private(set) var clock: TripClock
    private let clockDefaults: UserDefaults?
    private static let zoneKey = "planning.destinationTimeZone"
    private let transitETA: (MKDirections.Request) async throws -> TimeInterval

    private let eventStore = EKEventStore()
    private let saveURL: URL?
    private var isLoading = false
    private var canSave = true
    private var isExportingToCalendar = false

    public convenience init() {
        self.init(saveURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("magnet_board_events.json"), clockDefaults: .standard)
    }

    init(saveURL: URL?, clockDefaults: UserDefaults? = nil, deviceZone: TimeZone = .current,
         transitETA: @escaping (MKDirections.Request) async throws -> TimeInterval = { request in
             let result = try await MKDirections(request: request).calculateETA()
             return result.expectedTravelTime
         }) {
        self.saveURL = saveURL
        self.clockDefaults = clockDefaults
        self.transitETA = transitETA
        let zone = clockDefaults?.string(forKey: Self.zoneKey).flatMap { TimeZone(identifier: $0) } ?? deviceZone
        clock = TripClock(zone: zone)
        // Anchor even the initial zone so a journey never silently retimes a plan.
        clockDefaults?.set(zone.identifier, forKey: Self.zoneKey)
        load()
    }

    func useTripZone(_ zone: TimeZone) {
        clockDefaults?.set(zone.identifier, forKey: Self.zoneKey)
        clock = TripClock(zone: zone)
    }

    /// Creates an in-app scheduled item only. This intentionally does NOT write to Apple Calendar.
    ///
    /// Duplicate handling is deliberate: most specific cards should not be scheduled twice by
    /// accident, but generic/repeatable cards such as "coffee stop", "bar stop", or
    /// "shopping" can opt into multiple scheduled instances.
    public func scheduleIdea(_ idea: IdeaItem,
                             startDate: Date,
                             locked: Bool = false,
                             invitees: [String] = [],
                             schedulePrecision: SchedulePrecision = .exactTime,
                             dayPart: DayPart? = nil,
                             allowDuplicate: Bool? = nil) -> SchedulingResult {
        let canDuplicate = allowDuplicate ?? idea.allowsMultipleScheduledInstances
        if !canDuplicate, let existing = events.first(where: { $0.ideaID == idea.id }) {
            return .duplicateNotAllowed(existing: existing)
        }

        let duration = idea.duration ?? 60 * 60
        let event = EventItem(
            ideaID: idea.id,
            title: idea.title,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(duration),
            isLocked: locked,
            coordinate: idea.coordinate,
            locationName: idea.locationName,
            notes: idea.notes,
            invitees: invitees,
            category: idea.category,
            isMustDo: idea.group == .mustDo || idea.priority == 1,
            schedulePrecision: schedulePrecision,
            dayPart: schedulePrecision == .dayPart ? dayPart : nil
        )
        events.append(event)
        return .scheduled(event)
    }

    public func hasScheduledInstance(for ideaID: UUID) -> Bool {
        events.contains { $0.ideaID == ideaID }
    }

    public func scheduledInstanceCount(for ideaID: UUID) -> Int {
        events.filter { $0.ideaID == ideaID }.count
    }

    public func hasOtherScheduledInstance(for ideaID: UUID, excluding eventID: UUID) -> Bool {
        events.contains { $0.ideaID == ideaID && $0.id != eventID }
    }

    public func deleteEvent(_ event: EventItem) {
        events.removeAll { $0.id == event.id }
    }

    public func deleteEvents(_ doomedEvents: [EventItem]) {
        let doomedIDs = Set(doomedEvents.map(\.id))
        events.removeAll { doomedIDs.contains($0.id) }
    }

    public func deleteEvents(forIdeaID ideaID: UUID) -> [EventItem] {
        let removed = events.filter { $0.ideaID == ideaID }
        deleteEvents(removed)
        return removed
    }

    public func deleteEvents(on date: Date) -> [EventItem] {
        let removed = events(on: date)
        deleteEvents(removed)
        return removed
    }

    public func deleteAllEvents() -> [EventItem] {
        let removed = events
        events.removeAll()
        return removed
    }

    public func restoreEvent(_ event: EventItem) {
        restoreEvents([event])
    }

    public func restoreEvents(_ restoredEvents: [EventItem]) {
        for event in restoredEvents where !events.contains(where: { $0.id == event.id }) {
            events.append(event)
        }
    }

    public func toggleLocked(_ event: EventItem) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index].isLocked.toggle()
    }

    public func toggleMustDo(_ event: EventItem) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index].isMustDo.toggle()
    }

    public func setMustDo(_ event: EventItem, _ value: Bool) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index].isMustDo = value
    }

    public func moveEvent(_ event: EventItem, to newStart: Date) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        let duration = events[index].endDate.timeIntervalSince(events[index].startDate)
        events[index].startDate = newStart
        events[index].endDate = newStart.addingTimeInterval(duration)
    }

    /// Move one placement, never the underlying idea or its other occurrences.
    @discardableResult
    func rescheduleRough(_ id: UUID, on date: Date, part: DayPart?) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == id }),
              !events[index].isLocked, events[index].schedulePrecision != .exactTime else { return false }
        var event = events[index]
        let precision: SchedulePrecision = part == nil ? .dayOnly : .dayPart
        if clock.calendar.isDate(date, inSameDayAs: event.startDate),
           event.dayPart == part, event.schedulePrecision == precision { return true }
        let duration = event.endDate.timeIntervalSince(event.startDate)
        event.startDate = firstOpenSlot(on: date, preferredHour: part?.proxyHour ?? 12,
                                        duration: duration, excluding: id)
        event.endDate = event.startDate.addingTimeInterval(duration)
        event.dayPart = part
        event.schedulePrecision = precision
        events[index] = event
        return true
    }

    func undoReschedule(from moved: EventItem, to original: EventItem) -> Bool {
        guard moved.id == original.id, let index = events.firstIndex(where: { $0.id == moved.id }) else { return false }
        var current = events[index]
        guard !current.isLocked, current.startDate == moved.startDate, current.endDate == moved.endDate,
              current.dayPart == moved.dayPart, current.schedulePrecision == moved.schedulePrecision else { return false }
        // Undo timing only; keep any unrelated edits made since the move.
        current.startDate = original.startDate
        current.endDate = original.endDate
        current.dayPart = original.dayPart
        current.schedulePrecision = original.schedulePrecision
        events[index] = current
        return true
    }

    /// Promotes a rough scheduled placement into a real clock-time event.
    /// This is the moment where a sticky note becomes calendar-like.
    public func setExactTime(_ event: EventItem, startDate: Date) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        let duration = events[index].endDate.timeIntervalSince(events[index].startDate)
        events[index].startDate = startDate
        events[index].endDate = startDate.addingTimeInterval(duration)
        events[index].schedulePrecision = .exactTime
        events[index].dayPart = nil
    }

    public func setRoughPlacement(_ event: EventItem, precision: SchedulePrecision, dayPart: DayPart? = nil) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index].schedulePrecision = precision
        events[index].dayPart = precision == .dayPart ? dayPart : nil

        // Keep the proxy time aligned with the rough bucket so the visible order
        // matches the user's mental model: morning cards before afternoon cards,
        // and day-only cards in the middle unless manually reordered.
        let duration = max(events[index].endDate.timeIntervalSince(events[index].startDate), 15 * 60)
        let hour = precision == .dayPart ? (dayPart?.proxyHour ?? 12) : 12
        var components = clock.calendar.dateComponents([.year, .month, .day], from: events[index].startDate)
        components.hour = hour
        components.minute = 0
        if let newStart = clock.calendar.date(from: components) {
            events[index].startDate = newStart
            events[index].endDate = newStart.addingTimeInterval(duration)
        }
    }

    /// Reorders only flexible rough placements for a day using the same category rules
    /// that drive warnings. Exact-time and locked items are left untouched.
    ///
    /// This is intentionally conservative: it gives the auto-organizer a first real
    /// planning opinion without pretending to solve the whole itinerary problem.
    @discardableResult
    public func smartArrangeRoughEvents(on date: Date, settings: SequenceRuleSettings) -> [String] {
        let dayEvents = events(on: date)
        let flexible = dayEvents.filter { !$0.isLocked && $0.schedulePrecision != .exactTime }
        guard flexible.count > 1 else {
            return ["Nothing to auto-arrange yet. Add at least two rough, unlocked cards to this day."]
        }

        var updatedEvents = events
        var run: [EventItem] = []
        var reordered: [EventItem] = []
        // Exact and locked rows are anchors. Only arrange adjacent rough cards
        // within the same timing bucket between those anchors.
        for event in dayEvents {
            if let first = run.first, !canReorder(first, with: event) {
                let ordered = categoryAwareOrder(run, settings: settings)
                replaceRoughOrder(original: run, ordered: ordered, in: &updatedEvents)
                if ordered != run { reordered.append(contentsOf: ordered) }
                run.removeAll()
            }
            if canReorder(event, with: event) { run.append(event) }
        }
        let ordered = categoryAwareOrder(run, settings: settings)
        replaceRoughOrder(original: run, ordered: ordered, in: &updatedEvents)
        if ordered != run { reordered.append(contentsOf: ordered) }

        guard !reordered.isEmpty else {
            return ["No rough cards needed reordering within their time buckets."]
        }
        events = updatedEvents
        var notes: [String] = ["Reordered rough cards using your sequence rules."]
        if reordered.contains(where: { $0.isMustDo }) {
            notes.append("Must-do cards were kept high priority inside their rough time bucket.")
        }
        if reordered.contains(where: { $0.coordinate != nil }) {
            notes.append("Nearby coordinates helped choose less silly transitions where possible.")
        }
        notes.append("Exact-time and locked items were left alone.")
        return notes
    }

    private func dateAtHour(_ hour: Int, on date: Date) -> Date {
        var components = clock.calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        return clock.calendar.date(from: components) ?? date
    }

    private func categoryAwareOrder(_ input: [EventItem], settings: SequenceRuleSettings) -> [EventItem] {
        var remaining = input.sorted {
            if $0.isMustDo != $1.isMustDo { return $0.isMustDo && !$1.isMustDo }
            return $0.startDate < $1.startDate
        }
        guard var current = remaining.first else { return [] }
        remaining.removeFirst()
        var output: [EventItem] = [current]

        while !remaining.isEmpty {
            let bestIndex = remaining.indices.min { left, right in
                transitionPenalty(from: current, to: remaining[left], settings: settings) <
                transitionPenalty(from: current, to: remaining[right], settings: settings)
            } ?? remaining.startIndex
            current = remaining.remove(at: bestIndex)
            output.append(current)
        }
        return output
    }

    private func transitionPenalty(from first: EventItem, to second: EventItem, settings: SequenceRuleSettings) -> Int {
        var penalty = 0

        if second.isMustDo { penalty -= 18 }
        if first.isMustDo && !second.isMustDo { penalty += 4 }

        if settings.avoidBackToBackFullMeals,
           first.category == .fullMeal,
           second.category == .fullMeal {
            penalty += 100
        }

        if settings.avoidBackToBackHighEnergy,
           first.category.isHighEnergy,
           second.category.isHighEnergy {
            penalty += 70
        }

        if first.category == .bar, second.category == .bar {
            penalty += settings.allowBarCrawl ? -12 : 80
        }

        if first.category == .shopping, second.category == .shopping {
            penalty += settings.allowShoppingRun ? -10 : 70
        }

        if settings.snackCoffeeCanBuffer,
           second.category == .snackCoffee,
           (first.category == .shopping || first.category.isHighEnergy || first.category == .cultureMuseum) {
            penalty -= 8
        }

        if second.category == .restDowntime, first.category.isHighEnergy {
            penalty -= 10
        }

        // Light route-awareness: when both cards have coordinates, prefer closer
        // transitions. This is not full itinerary optimization, but it makes the
        // first-pass auto-order less silly without making slow MapKit calls.
        if let distanceMeters = straightLineDistanceMeters(from: first, to: second) {
            let kilometers = distanceMeters / 1000.0
            penalty += min(30, Int(kilometers.rounded()))
        }

        return penalty
    }

    private func straightLineDistanceMeters(from first: EventItem, to second: EventItem) -> Double? {
        guard let firstCoordinate = first.coordinate?.clLocationCoordinate2D,
              let secondCoordinate = second.coordinate?.clLocationCoordinate2D else { return nil }
        let firstLocation = CLLocation(latitude: firstCoordinate.latitude, longitude: firstCoordinate.longitude)
        let secondLocation = CLLocation(latitude: secondCoordinate.latitude, longitude: secondCoordinate.longitude)
        return firstLocation.distance(from: secondLocation)
    }

    /// Manually nudges a card earlier/later in the current day's rough ordering.
    /// It swaps proxy start times with a neighbor rather than changing locked items.
    public func moveEventWithinDay(_ event: EventItem, on date: Date, direction: Int) {
        guard direction != 0 else { return }
        let dayEvents = events(on: date)
        guard let currentIndex = dayEvents.firstIndex(where: { $0.id == event.id }) else { return }
        let neighborIndex = currentIndex + (direction < 0 ? -1 : 1)
        guard dayEvents.indices.contains(neighborIndex) else { return }

        let range = min(currentIndex, neighborIndex)...max(currentIndex, neighborIndex)
        let original = Array(dayEvents[range])
        guard canReorder(original[0], with: original[1]) else { return }
        var updatedEvents = events
        replaceRoughOrder(original: original, ordered: Array(original.reversed()), in: &updatedEvents)
        events = updatedEvents
    }

    /// Reorders an unlocked scheduled row by dragging it before another row.
    ///
    /// This keeps the sticky-note metaphor: users can simply rearrange the visible
    /// stack. Locked commitments stay protected. The method preserves each card's
    /// own duration and precision while reassigning the visible order's proxy start
    /// positions.
    public func reorderEvent(_ draggedID: UUID, before targetID: UUID, on date: Date) {
        reorderEvent(draggedID, relativeTo: targetID, on: date, useTargetSlot: false)
    }

    func moveEvent(_ draggedID: UUID, onto targetID: UUID, on date: Date) {
        reorderEvent(draggedID, relativeTo: targetID, on: date, useTargetSlot: true)
    }

    private func reorderEvent(_ draggedID: UUID, relativeTo targetID: UUID, on date: Date, useTargetSlot: Bool) {
        guard draggedID != targetID else { return }

        let dayEvents = events(on: date)
        guard let fromIndex = dayEvents.firstIndex(where: { $0.id == draggedID }),
              let targetIndex = dayEvents.firstIndex(where: { $0.id == targetID }) else { return }

        let lower = min(fromIndex, targetIndex)
        let upper = max(fromIndex, targetIndex)
        let original = Array(dayEvents[lower...upper])
        let dragged = dayEvents[fromIndex]
        guard original.allSatisfy({ canReorder(dragged, with: $0) }) else { return }

        var ordered = original
        ordered.remove(at: fromIndex - lower)
        let insertionIndex = targetIndex - lower - (!useTargetSlot && fromIndex < targetIndex ? 1 : 0)
        ordered.insert(dragged, at: insertionIndex)
        guard ordered != original else { return }
        var updatedEvents = events
        replaceRoughOrder(original: original, ordered: ordered, in: &updatedEvents)
        events = updatedEvents
    }

    private func canReorder(_ first: EventItem, with second: EventItem) -> Bool {
        !first.isLocked && !second.isLocked && first.schedulePrecision != .exactTime &&
            first.schedulePrecision == second.schedulePrecision && first.dayPart == second.dayPart
    }

    private func replaceRoughOrder(original: [EventItem], ordered: [EventItem], in updatedEvents: inout [EventItem]) {
        guard original != ordered else { return }
        // Each displayed slot owns both a timestamp and its storage index
        // (the tiebreaker). Preserve both, including ties with stationary rows.
        let storageSlots = original.compactMap { slot in updatedEvents.firstIndex { $0.id == slot.id } }
        guard storageSlots.count == original.count else { return }
        for ((index, event), originalEvent) in zip(zip(storageSlots, ordered), original) {
            var moved = event
            moved.startDate = originalEvent.startDate
            moved.endDate = moved.startDate.addingTimeInterval(event.endDate.timeIntervalSince(event.startDate))
            updatedEvents[index] = moved
        }
    }

    /// Stores a user-entered estimate for the leg after this event.
    /// The estimate belongs to the "from" event because it describes travel
    /// immediately after that event ends and before the next event begins.
    public func setManualTravelEstimate(after event: EventItem,
                                        minutes: Double,
                                        note: String? = nil) {
        _ = setManualTravelEstimate(after: event, to: nil, minutes: minutes, note: note)
    }

    func setManualTravelEstimate(after event: EventItem, to expectedNextID: UUID?,
                                 minutes: Double, note: String?) -> Bool {
        let seconds = minutes * 60
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max),
              let index = events.firstIndex(where: { $0.id == event.id }) else { return false }
        var updated = events[index]
        let dayEvents = events(on: updated.startDate)
        guard let position = dayEvents.firstIndex(where: { $0.id == event.id }),
              dayEvents.indices.contains(position + 1) else { return false }
        let nextID = dayEvents[position + 1].id
        guard expectedNextID == nil || expectedNextID == nextID else { return false }
        updated.manualTravelTarget = .placement(nextID)
        updated.manualTravelToNextSeconds = seconds
        let cleanedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updated.manualTravelToNextNote = cleanedNote.isEmpty ? nil : cleanedNote
        events[index] = updated
        return true
    }

    public func clearManualTravelEstimate(after event: EventItem) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        var updated = events[index]
        updated.manualTravelToNextSeconds = nil
        updated.manualTravelToNextNote = nil
        updated.manualTravelTarget = nil
        events[index] = updated
    }

    /// Writes a scheduled in-app item to Apple Calendar only when the user asks.
    ///
    /// Important product rule: the app must remain useful as a free-form planner.
    /// Calendar permission is requested lazily here, at the moment of export, rather
    /// than on app launch.
    public func exportToCalendar(_ event: EventItem) async -> CalendarExportResult {
        guard canSave, storageIssue == nil else {
            return .failed("Fix schedule storage before exporting so the Calendar link can be saved.")
        }
        guard let current = events.first(where: { $0.id == event.id }) else {
            return .failed("This card is no longer in the plan.")
        }
        guard current.schedulePrecision == .exactTime else { return .notExactTime }
        guard !isExportingToCalendar else {
            return .failed("Another Calendar export is in progress.")
        }
        isExportingToCalendar = true
        defer { isExportingToCalendar = false }

        do {
            let access = EKEventStore.authorizationStatus(for: .event)
            if current.eventKitID != nil {
                if access != .fullAccess {
                    guard try await eventStore.requestFullAccessToEvents() else {
                        return .failed("Full Calendar access is needed to update the previous export. Check Calendar access in Settings.")
                    }
                }
            } else if access != .fullAccess && access != .writeOnly {
                guard access == .notDetermined, try await eventStore.requestWriteOnlyAccessToEvents() else {
                    return .permissionDenied
                }
            }

            // Permission prompts can suspend this task while the plan changes.
            guard let index = events.firstIndex(where: { $0.id == current.id }) else {
                return .failed("This card was removed while Calendar access was being requested.")
            }
            let event = events[index]
            guard event.schedulePrecision == .exactTime else { return .notExactTime }
            guard storageIssue == nil else {
                return .failed("The schedule could not be saved while Calendar access was being requested.")
            }
            let ekEvent: EKEvent

            // If this in-app plan has already been exported, update that Apple
            // Calendar event instead of creating a duplicate. If the user deleted
            // the old Calendar event, fall back to creating a fresh one and store
            // the new EventKit identifier below.
            if let eventKitID = event.eventKitID,
               let existingEvent = eventStore.event(withIdentifier: eventKitID) {
                ekEvent = existingEvent
            } else {
                guard let calendar = eventStore.defaultCalendarForNewEvents else {
                    return .noDefaultCalendar
                }
                ekEvent = EKEvent(eventStore: eventStore)
                ekEvent.calendar = calendar
            }

            ekEvent.title = event.title
            ekEvent.timeZone = clock.zone
            ekEvent.startDate = event.startDate
            ekEvent.endDate = event.endDate
            ekEvent.notes = event.notes.isEmpty ? nil : event.notes
            ekEvent.location = event.locationName.isEmpty ? nil : event.locationName
            try eventStore.save(ekEvent, span: .thisEvent)

            events[index].eventKitID = ekEvent.eventIdentifier
            if storageIssue != nil {
                return .failed("The event was saved to Calendar, but its link could not be saved in Magnet Board.")
            }
            return .success
        } catch {
            print("Failed to export event to calendar: \(error)")
            return .failed(error.localizedDescription)
        }
    }

    public func events(on date: Date) -> [EventItem] {
        events
            .filter { clock.calendar.isDate($0.startDate, inSameDayAs: date) }
            .sorted { $0.startDate < $1.startDate }
    }

    public func firstOpenSlot(on date: Date,
                              preferredHour: Int = 12,
                              duration: TimeInterval = 60 * 60, excluding id: UUID? = nil) -> Date {
        let calendar = clock.calendar
        let preferred = dateAtHour(preferredHour, on: date)
        guard calendar.isDate(preferred, inSameDayAs: date) else { return date }
        var candidate = preferred

        // Use true interval overlap instead of comparing start times only.
        // This prevents failures such as placing a 13:00 item inside an existing
        // 12:00–15:00 block. Rough placements still have proxy times, so this also
        // keeps the day-part buckets from stacking cards directly on top of each other.
        let safeDuration = max(duration, 15 * 60)
        guard let day = calendar.dateInterval(of: .day, for: date) else { return preferred }
        let dayEvents = eventsOverlapping(day).filter { $0.id != id }
        while candidate < day.end {
            let end = candidate.addingTimeInterval(safeDuration)
            if end <= day.end, !dayEvents.contains(where: { intervalsOverlap(candidate, end, $0.startDate, $0.endDate) }) {
                return candidate
            }
            candidate = candidate.addingTimeInterval(30 * 60)
        }
        // These are proxy times for rough cards. If the day is full, preserve
        // the requested placement instead of silently moving the card to tomorrow.
        return preferred
    }

    public func conflictWarnings(for date: Date) -> [String] {
        guard let day = clock.calendar.dateInterval(of: .day, for: date) else { return [] }
        let exactEvents = eventsOverlapping(day).filter { $0.schedulePrecision == .exactTime }
            .sorted { $0.startDate < $1.startDate }
        guard exactEvents.count > 1 else { return [] }
        var warnings: [String] = []

        // Pairwise interval-overlap check. Sorting-adjacent checks are often enough,
        // but pairwise logic is clearer and safer for a small daily plan.
        for i in exactEvents.indices {
            for j in exactEvents.indices where j > i {
                let first = exactEvents[i]
                let second = exactEvents[j]
                if intervalsOverlap(first.startDate, first.endDate, second.startDate, second.endDate) {
                    warnings.append("\(first.title) overlaps \(second.title).")
                }
            }
        }
        return warnings
    }

    private func intervalsOverlap(_ startA: Date, _ endA: Date, _ startB: Date, _ endB: Date) -> Bool {
        startA < endB && endA > startB
    }

    // Ownership (display, clear, reorder) stays on the start day. Occupancy
    // extends across midnight, up to but excluding the actual end time.
    private func eventsOverlapping(_ day: DateInterval) -> [EventItem] {
        events.filter { intervalsOverlap($0.startDate, $0.endDate, day.start, day.end) }
    }

    public func precisionWarnings(for date: Date) -> [String] {
        let roughEvents = events(on: date).filter { $0.schedulePrecision != .exactTime }
        guard !roughEvents.isEmpty else { return [] }
        if roughEvents.count == 1 {
            return ["1 card is still roughly placed. Set an exact time before relying on conflict checks or exporting to Apple Calendar."]
        }
        return ["\(roughEvents.count) cards are still roughly placed. Set exact times before relying on conflict checks or exporting to Apple Calendar."]
    }


    public func sequenceWarnings(for date: Date, settings: SequenceRuleSettings) -> [String] {
        let dayEvents = events(on: date)
        guard dayEvents.count > 1 else { return [] }

        var warnings: [String] = []
        for pair in zip(dayEvents, dayEvents.dropFirst()) {
            let first = pair.0
            let second = pair.1

            if settings.avoidBackToBackFullMeals,
               first.category == .fullMeal,
               second.category == .fullMeal {
                warnings.append("Two full meals are back-to-back: \(first.title) → \(second.title). Consider adding time, a walk, or another activity between them.")
            }

            if settings.avoidBackToBackHighEnergy,
               first.category.isHighEnergy,
               second.category.isHighEnergy {
                warnings.append("Two high-energy activities are back-to-back: \(first.title) → \(second.title). Consider adding a rest, snack, or lower-energy stop.")
            }

            if !settings.allowBarCrawl,
               first.category == .bar,
               second.category == .bar {
                warnings.append("Two bar stops are back-to-back. Turn on Bar crawl if that is intentional.")
            }

            if !settings.allowShoppingRun,
               first.category == .shopping,
               second.category == .shopping {
                warnings.append("Two shopping stops are back-to-back. Turn on Shopping run if that is intentional.")
            }
        }

        if !settings.snackCoffeeCanBuffer, dayEvents.count >= 3 {
            for index in 1..<(dayEvents.count - 1) {
                let previous = dayEvents[index - 1]
                let middle = dayEvents[index]
                let next = dayEvents[index + 1]
                guard middle.category == .snackCoffee else { continue }

                if previous.category == .fullMeal, next.category == .fullMeal {
                    warnings.append("Snack / coffee is currently not allowed as a buffer between full meals: \(previous.title) → \(middle.title) → \(next.title).")
                }

                if previous.category.isHighEnergy, next.category.isHighEnergy {
                    warnings.append("Snack / coffee is currently not allowed as a recovery buffer between high-energy activities: \(previous.title) → \(middle.title) → \(next.title).")
                }
            }
        }

        return warnings
    }


    public func dayBoundaryWarnings(for date: Date, startHour: Double, endHour: Double) -> [String] {
        guard endHour > startHour else {
            return ["Your day-end preference is earlier than your day-start preference. Check Settings → Day shape."]
        }
        let dayEvents = events(on: date)
        guard !dayEvents.isEmpty else { return [] }

        var warnings: [String] = []
        let exactEvents = dayEvents.filter { $0.schedulePrecision == .exactTime }
        for event in exactEvents {
            let start = planningHour(event.startDate, relativeTo: date, calendar: clock.calendar)
            let end = planningHour(event.endDate, relativeTo: date, calendar: clock.calendar)
            if start < startHour {
                warnings.append("\(event.title) starts before your usual day start.")
            }
            if end > endHour {
                warnings.append("\(event.title) ends after your usual day end.")
            }
        }
        return warnings
    }

    public func plainTextPlanSummary(on date: Date,
                                     planName: String,
                                     homeBaseName: String,
                                     travelLegStatuses: [UUID: TravelLegStatus] = [:],
                                     homeStartTravelStatus: TravelLegStatus? = nil,
                                     homeEndTravelStatus: TravelLegStatus? = nil,
                                     useDayBounds: Bool = false,
                                     startHour: Double = 10,
                                     endHour: Double = 22) -> String {
        let dayEvents = events(on: date)
        let title = planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Magnet Board plan" : planName
        var lines: [String] = []
        lines.append(title)
        lines.append("\(clock.date(date)) · \(clock.zone.identifier)")
        if !homeBaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Home base: \(homeBaseName)")
            if let homeStartTravelStatus {
                lines.append("Home → first stop: \(homeStartTravelStatus.label)")
            }
            if let homeEndTravelStatus {
                lines.append("Last stop → home: \(homeEndTravelStatus.label)")
            }
        }
        if useDayBounds {
            lines.append("Usual day: \(formatDecimalHour(startHour))–\(formatDecimalHour(endHour))")
        }
        lines.append("")

        if dayEvents.isEmpty {
            lines.append("No planned cards yet.")
        } else {
            for (index, event) in dayEvents.enumerated() {
                var line = "\(index + 1). \(event.title) — \(plainPlacementLabel(for: event))"
                if event.isMustDo { line += " ⭐ must happen" }
                if !event.locationName.isEmpty { line += " @ \(event.locationName)" }
                lines.append(line)
                if let status = travelLegStatuses[event.id], index < dayEvents.count - 1 {
                    lines.append("   Travel after: \(status.label)")
                }
            }
        }

        let internalLegs = dayEvents.dropLast().map { travelLegStatuses[$0.id] }
        let knownTravel = TravelLegStatus.knownTotal(internalLegs + [homeStartTravelStatus, homeEndTravelStatus])
        let activity = dayEvents.reduce(0) { $0 + max(0, $1.endDate.timeIntervalSince($1.startDate)) }
        lines.append("")
        lines.append("Summary: \(dayEvents.count) stop\(dayEvents.count == 1 ? "" : "s"), \(formatDuration(activity)) activity, \(knownTravel.map(formatDuration) ?? "unknown") known travel.")
        lines.append("Made with Magnet Board")
        return lines.joined(separator: "\n")
    }

    private func plainPlacementLabel(for event: EventItem) -> String {
        switch event.schedulePrecision {
        case .exactTime:
            return "\(clock.time(event.startDate))–\(clock.time(event.endDate))"
        case .dayPart:
            return event.dayPart.map { "\($0.label), rough" } ?? "part of day, rough"
        case .dayOnly:
            return "sometime today"
        }
    }

    private func formatDecimalHour(_ hour: Double) -> String {
        let minutes = Int((hour * 60).rounded())
        let wrapped = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60)
        return String(format: "%02d:%02d", wrapped / 60, wrapped % 60)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(round(seconds / 60))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    /// One Maps request per leg. For driving and walking, the route already
    /// contains its ETA. For transit, MapKit's ETA request is the supported path.
    func travelEstimate(from: CLLocationCoordinate2D?, to: CLLocationCoordinate2D?,
                        mode: TravelMode, departureDate: Date, arriveBy: Bool = false) async -> (TravelLegStatus, MKPolyline?) {
        guard let request = Self.tripDirectionsRequest(from: from, to: to, mode: mode, date: departureDate, arriveBy: arriveBy) else {
            return (.missingCoordinates, nil)
        }
        do {
            if mode == .transit {
                let seconds = try await transitETA(request)
                return (.mapEstimate(seconds: seconds, mode: mode, note: mode.estimateNote), nil)
            }
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else {
                return (.failed(message: "No route was returned."), nil)
            }
            return (.mapEstimate(seconds: route.expectedTravelTime, mode: mode, note: mode.estimateNote), route.polyline)
        } catch {
            return (.failed(message: error.localizedDescription), nil)
        }
    }

    private func makeDirections(from: CLLocationCoordinate2D?, to: CLLocationCoordinate2D?,
                                mode: TravelMode, departureDate: Date?, arriveBy: Bool = false) -> MKDirections? {
        guard let request = Self.tripDirectionsRequest(from: from, to: to, mode: mode, date: departureDate, arriveBy: arriveBy) else { return nil }
        return MKDirections(request: request)
    }

    static func tripDirectionsRequest(from: CLLocationCoordinate2D?, to: CLLocationCoordinate2D?,
                                      mode: TravelMode, date: Date?, arriveBy: Bool) -> MKDirections.Request? {
        guard let from, let to, CLLocationCoordinate2DIsValid(from), CLLocationCoordinate2DIsValid(to) else { return nil }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = mode.mapKitTransportType
        if arriveBy { request.arrivalDate = date } else { request.departureDate = date }
        return request
    }

    public func calculateTravelLegStatus(fromCoordinate: CLLocationCoordinate2D?,
                                         toCoordinate: CLLocationCoordinate2D?,
                                         travelMode: TravelMode = .driving,
                                         departureDate: Date? = nil,
                                         completion: @escaping (TravelLegStatus) -> Void) {
        guard let directions = makeDirections(from: fromCoordinate, to: toCoordinate,
                                              mode: travelMode, departureDate: departureDate) else {
            completion(.missingCoordinates)
            return
        }

        if travelMode == .transit {
            directions.calculateETA { response, error in
                if let eta = response?.expectedTravelTime {
                    completion(.mapEstimate(seconds: eta, mode: travelMode, note: travelMode.estimateNote))
                } else if let error {
                    completion(.failed(message: error.localizedDescription))
                } else {
                    completion(.failed(message: "No ETA was returned."))
                }
            }
        } else {
            directions.calculate { response, error in
                if let eta = response?.routes.first?.expectedTravelTime {
                    completion(.mapEstimate(seconds: eta, mode: travelMode, note: travelMode.estimateNote))
                } else if let error {
                    completion(.failed(message: error.localizedDescription))
                } else {
                    completion(.failed(message: "No route was returned."))
                }
            }
        }
    }

    public func calculateTravelLegStatus(from: EventItem,
                                          to: EventItem,
                                          travelMode: TravelMode = .driving,
                                          departureDate: Date? = nil,
                                          completion: @escaping (TravelLegStatus) -> Void) {
        if let manual = from.manualTravel(to: to.id) {
            completion(manual)
            return
        }

        calculateTravelLegStatus(
            fromCoordinate: from.coordinate?.clLocationCoordinate2D,
            toCoordinate: to.coordinate?.clLocationCoordinate2D,
            travelMode: travelMode,
            departureDate: departureDate,
            completion: completion
        )
    }


    public func calculateRoute(fromCoordinate: CLLocationCoordinate2D?,
                               toCoordinate: CLLocationCoordinate2D?,
                               travelMode: TravelMode = .driving,
                               departureDate: Date? = nil,
                               completion: @escaping (MKRoute?) -> Void) {
        guard let directions = makeDirections(from: fromCoordinate, to: toCoordinate,
                                              mode: travelMode, departureDate: departureDate) else {
            completion(nil)
            return
        }
        directions.calculate { response, _ in
            completion(response?.routes.first)
        }
    }

    public func calculateRoute(from: EventItem,
                               to: EventItem,
                               travelMode: TravelMode = .driving,
                               departureDate: Date? = nil,
                               completion: @escaping (MKRoute?) -> Void) {
        calculateRoute(
            fromCoordinate: from.coordinate?.clLocationCoordinate2D,
            toCoordinate: to.coordinate?.clLocationCoordinate2D,
            travelMode: travelMode,
            departureDate: departureDate,
            completion: completion
        )
    }


    private func load() {
        guard let saveURL else {
            storageIssue = "The schedule storage folder is unavailable."
            canSave = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try Data(contentsOf: saveURL)
            let decoded = try JSONDecoder.dateDecoder.decode([EventItem].self, from: data)
            events = bindingLegacyEstimates(in: decoded)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return
        } catch {
            canSave = false
            storageIssue = "The saved schedule could not be opened. The original file was kept. Schedule changes will not be saved."
            print("Failed to load scheduled events: \(error)")
        }
    }

    private func bindingLegacyEstimates(in decoded: [EventItem]) -> [EventItem] {
        guard decoded.contains(where: { $0.manualTravelToNextSeconds != nil && $0.manualTravelTarget == nil }) else {
            return decoded
        }
        var migrated = decoded
        let days = Dictionary(grouping: decoded.indices) { clock.calendar.startOfDay(for: decoded[$0].startDate) }
        for indices in days.values {
            let ordered = indices.sorted { decoded[$0].startDate < decoded[$1].startDate }
            for (position, index) in ordered.enumerated() where decoded[index].manualTravelToNextSeconds != nil && decoded[index].manualTravelTarget == nil {
                if ordered.indices.contains(position + 1) {
                    migrated[index].manualTravelTarget = .placement(decoded[ordered[position + 1]].id)
                } else {
                    migrated[index].manualTravelTarget = .unassigned
                }
            }
        }
        return migrated
    }

    private func save() {
        guard !isLoading, canSave, let saveURL else { return }
        do {
            let data = try JSONEncoder.prettyDateEncoder.encode(events)
            try data.write(to: saveURL, options: [.atomic])
            if storageIssue != nil { storageIssue = nil }
        } catch {
            storageIssue = "The schedule could not be saved. Changes are only available for this session."
            print("Failed to save scheduled events: \(error)")
        }
    }
}
