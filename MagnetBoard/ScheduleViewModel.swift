import Foundation
import EventKit
import MapKit
import CoreLocation

/// View model for scheduled placements and optional system calendar integration.
@MainActor
public final class ScheduleViewModel: ObservableObject {
    @Published public var events: [EventItem] = [] {
        didSet { save() }
    }

    private let eventStore = EKEventStore()
    private let saveURL: URL
    private var isLoading = false

    public init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.saveURL = documents.appendingPathComponent("magnet_board_events.json")
        load()
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
        var components = Calendar.current.dateComponents([.year, .month, .day], from: events[index].startDate)
        components.hour = hour
        components.minute = 0
        if let newStart = Calendar.current.date(from: components) {
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

        let ordered = categoryAwareOrder(flexible, settings: settings)
        var cursorByHour: [Int: Date] = [:]

        for event in ordered {
            guard let index = events.firstIndex(where: { $0.id == event.id }) else { continue }
            let duration = max(events[index].endDate.timeIntervalSince(events[index].startDate), 15 * 60)
            let hour = proxyHour(for: events[index])
            let start = cursorByHour[hour] ?? dateAtHour(hour, on: date)
            events[index].startDate = start
            events[index].endDate = start.addingTimeInterval(duration)
            cursorByHour[hour] = events[index].endDate.addingTimeInterval(15 * 60)
        }

        var notes: [String] = ["Reordered rough cards using your sequence rules."]
        if ordered.contains(where: { $0.isMustDo }) {
            notes.append("Must-do cards were kept high priority inside their rough time bucket.")
        }
        if ordered.contains(where: { $0.coordinate != nil }) {
            notes.append("Nearby coordinates helped choose less silly transitions where possible.")
        }
        notes.append("Exact-time and locked items were left alone.")
        return notes
    }

    private func proxyHour(for event: EventItem) -> Int {
        if event.schedulePrecision == .dayPart, let dayPart = event.dayPart {
            return dayPart.proxyHour
        }
        return 12
    }

    private func dateAtHour(_ hour: Int, on date: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        return Calendar.current.date(from: components) ?? date
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

        let current = dayEvents[currentIndex]
        let neighbor = dayEvents[neighborIndex]
        guard !current.isLocked, !neighbor.isLocked else { return }
        guard let currentStorageIndex = events.firstIndex(where: { $0.id == current.id }),
              let neighborStorageIndex = events.firstIndex(where: { $0.id == neighbor.id }) else { return }

        let currentStart = events[currentStorageIndex].startDate
        let currentEnd = events[currentStorageIndex].endDate
        let neighborStart = events[neighborStorageIndex].startDate
        let neighborEnd = events[neighborStorageIndex].endDate

        events[currentStorageIndex].startDate = neighborStart
        events[currentStorageIndex].endDate = neighborEnd
        events[neighborStorageIndex].startDate = currentStart
        events[neighborStorageIndex].endDate = currentEnd
    }

    /// Reorders an unlocked scheduled row by dragging it before another row.
    ///
    /// This keeps the sticky-note metaphor: users can simply rearrange the visible
    /// stack. Locked commitments stay protected. The method preserves each card's
    /// own duration and precision while reassigning the visible order's proxy start
    /// positions.
    public func reorderEvent(_ draggedID: UUID, before targetID: UUID, on date: Date) {
        guard draggedID != targetID else { return }

        var dayEvents = events(on: date)
        guard let fromIndex = dayEvents.firstIndex(where: { $0.id == draggedID }),
              let targetIndex = dayEvents.firstIndex(where: { $0.id == targetID }) else { return }

        let dragged = dayEvents[fromIndex]
        let target = dayEvents[targetIndex]
        guard !dragged.isLocked, !target.isLocked else { return }

        let originalSlots = dayEvents.map { $0.startDate }
        let moving = dayEvents.remove(at: fromIndex)
        let adjustedTargetIndex = dayEvents.firstIndex(where: { $0.id == targetID }) ?? targetIndex
        dayEvents.insert(moving, at: adjustedTargetIndex)

        for (slotIndex, event) in dayEvents.enumerated() {
            guard let storageIndex = events.firstIndex(where: { $0.id == event.id }),
                  originalSlots.indices.contains(slotIndex) else { continue }
            let duration = max(events[storageIndex].endDate.timeIntervalSince(events[storageIndex].startDate), 15 * 60)
            let newStart = originalSlots[slotIndex]
            events[storageIndex].startDate = newStart
            events[storageIndex].endDate = newStart.addingTimeInterval(duration)
        }
    }

    /// Stores a user-entered estimate for the leg after this event.
    /// The estimate belongs to the "from" event because it describes travel
    /// immediately after that event ends and before the next event begins.
    public func setManualTravelEstimate(after event: EventItem,
                                        minutes: Double,
                                        note: String? = nil) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        let clampedMinutes = max(0, minutes)
        events[index].manualTravelToNextSeconds = clampedMinutes * 60
        let cleanedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        events[index].manualTravelToNextNote = cleanedNote.isEmpty ? nil : cleanedNote
    }

    public func clearManualTravelEstimate(after event: EventItem) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index].manualTravelToNextSeconds = nil
        events[index].manualTravelToNextNote = nil
    }

    /// Writes a scheduled in-app item to Apple Calendar only when the user asks.
    ///
    /// Important product rule: the app must remain useful as a free-form planner.
    /// Calendar permission is requested lazily here, at the moment of export, rather
    /// than on app launch.
    public func exportToCalendar(_ event: EventItem) async -> CalendarExportResult {
        guard event.schedulePrecision == .exactTime else {
            return .notExactTime
        }

        guard await ensureCalendarWriteAccess() else {
            return .permissionDenied
        }

        do {
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
            ekEvent.startDate = event.startDate
            ekEvent.endDate = event.endDate
            ekEvent.notes = event.notes.isEmpty ? nil : event.notes
            ekEvent.location = event.locationName.isEmpty ? nil : event.locationName
            try eventStore.save(ekEvent, span: .thisEvent)

            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].eventKitID = ekEvent.eventIdentifier
            }
            return .success
        } catch {
            print("Failed to export event to calendar: \(error)")
            return .failed(error.localizedDescription)
        }
    }

    public func events(on date: Date) -> [EventItem] {
        events
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
            .sorted { $0.startDate < $1.startDate }
    }

    public func firstOpenSlot(on date: Date,
                              preferredHour: Int = 12,
                              duration: TimeInterval = 60 * 60) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = preferredHour
        components.minute = 0
        var candidate = Calendar.current.date(from: components) ?? date

        // Use true interval overlap instead of comparing start times only.
        // This prevents failures such as placing a 13:00 item inside an existing
        // 12:00–15:00 block. Rough placements still have proxy times, so this also
        // keeps the day-part buckets from stacking cards directly on top of each other.
        let dayEvents = events(on: date)
        let safeDuration = max(duration, 15 * 60)
        var attempts = 0
        while dayEvents.contains(where: { intervalsOverlap(candidate,
                                                          candidate.addingTimeInterval(safeDuration),
                                                          $0.startDate,
                                                          $0.endDate) }) && attempts < 48 {
            candidate = candidate.addingTimeInterval(30 * 60)
            attempts += 1
        }
        return candidate
    }

    public func conflictWarnings(for date: Date) -> [String] {
        let exactEvents = events(on: date).filter { $0.schedulePrecision == .exactTime }
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
            let start = decimalHour(event.startDate)
            let end = decimalHour(event.endDate)
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
        lines.append(date.formatted(date: .abbreviated, time: .omitted))
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

        let knownTravel = travelLegStatuses.values.compactMap(\.seconds).reduce(0, +) + [homeStartTravelStatus, homeEndTravelStatus].compactMap { $0?.seconds }.reduce(0, +)
        let activity = dayEvents.reduce(0) { $0 + max(0, $1.endDate.timeIntervalSince($1.startDate)) }
        lines.append("")
        lines.append("Summary: \(dayEvents.count) stop\(dayEvents.count == 1 ? "" : "s"), \(formatDuration(activity)) activity, \(knownTravel > 0 ? formatDuration(knownTravel) : "unknown") known travel.")
        lines.append("Made with Magnet Board")
        return lines.joined(separator: "\n")
    }

    private func plainPlacementLabel(for event: EventItem) -> String {
        switch event.schedulePrecision {
        case .exactTime:
            return "\(event.startDate.formatted(date: .omitted, time: .shortened))–\(event.endDate.formatted(date: .omitted, time: .shortened))"
        case .dayPart:
            return event.dayPart.map { "\($0.label), rough" } ?? "part of day, rough"
        case .dayOnly:
            return "sometime today"
        }
    }

    private func decimalHour(_ date: Date) -> Double {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
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


    public func calculateTravelLegStatus(fromCoordinate: CLLocationCoordinate2D?,
                                         toCoordinate: CLLocationCoordinate2D?,
                                         travelMode: TravelMode = .driving,
                                         departureDate: Date? = nil,
                                         completion: @escaping (TravelLegStatus) -> Void) {
        guard let fromLoc = fromCoordinate, let toLoc = toCoordinate else {
            completion(.missingCoordinates)
            return
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: fromLoc))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: toLoc))
        request.transportType = travelMode.mapKitTransportType
        if let departure = departureDate { request.departureDate = departure }

        let directions = MKDirections(request: request)
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
        if let manualSeconds = from.manualTravelToNextSeconds {
            completion(.manualEstimate(seconds: manualSeconds, note: from.manualTravelToNextNote))
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
        guard let fromLoc = fromCoordinate, let toLoc = toCoordinate else {
            completion(nil)
            return
        }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: fromLoc))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: toLoc))
        request.transportType = travelMode.mapKitTransportType
        if let departure = departureDate { request.departureDate = departure }

        MKDirections(request: request).calculate { response, _ in
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


    private func hasCalendarWriteAccess() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, macOS 14.0, *) {
            return status == .fullAccess || status == .writeOnly || status == .authorized
        } else {
            return status == .authorized
        }
    }

    private func ensureCalendarWriteAccess() async -> Bool {
        if hasCalendarWriteAccess() { return true }

        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .notDetermined else { return false }

        do {
            if #available(iOS 17.0, macOS 14.0, *) {
                return try await eventStore.requestWriteOnlyAccessToEvents()
            } else {
                return try await eventStore.requestAccess(to: .event)
            }
        } catch {
            print("Calendar access request failed: \(error)")
            return false
        }
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
        do {
            let data = try Data(contentsOf: saveURL)
            events = try JSONDecoder.dateDecoder.decode([EventItem].self, from: data)
        } catch {
            print("Failed to load scheduled events: \(error)")
        }
    }

    private func save() {
        guard !isLoading else { return }
        do {
            let data = try JSONEncoder.prettyDateEncoder.encode(events)
            try data.write(to: saveURL, options: [.atomic])
        } catch {
            print("Failed to save scheduled events: \(error)")
        }
    }
}
