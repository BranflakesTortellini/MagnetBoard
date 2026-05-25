import SwiftUI
import UniformTypeIdentifiers
import MapKit

// MARK: - Schedule / Calendar Mode

struct SchedulePlannerView: View {
    @EnvironmentObject var boardViewModel: BoardViewModel
    @EnvironmentObject var scheduleViewModel: ScheduleViewModel
    @EnvironmentObject var undoViewModel: DelightUndoViewModel
    @Binding var selectedDate: Date

    @State private var selectedTravelMode: TravelMode = .driving
    @State private var travelLegStatuses: [UUID: TravelLegStatus] = [:]
    @State private var homeStartTravelStatus: TravelLegStatus?
    @State private var homeEndTravelStatus: TravelLegStatus?
    @State private var routePolylines: [MKPolyline] = []
    @State private var exportMessage: String?
    @State private var showClearBurst = false
    @State private var draggedScheduledEventID: UUID?
    @AppStorage("sequence.avoidBackToBackFullMeals") private var avoidBackToBackFullMeals = true
    @AppStorage("sequence.avoidBackToBackHighEnergy") private var avoidBackToBackHighEnergy = true
    @AppStorage("sequence.allowBarCrawl") private var allowBarCrawl = true
    @AppStorage("sequence.allowShoppingRun") private var allowShoppingRun = true
    @AppStorage("sequence.snackCoffeeCanBuffer") private var snackCoffeeCanBuffer = true
    @AppStorage(PlanningSettingsKeys.planName) private var planName = ""
    @AppStorage(PlanningSettingsKeys.useDayBounds) private var useDayBounds = false
    @AppStorage(PlanningSettingsKeys.preferredDayStartHour) private var preferredDayStartHour = PlanningSettingsDefaults.preferredDayStartHour
    @AppStorage(PlanningSettingsKeys.preferredDayEndHour) private var preferredDayEndHour = PlanningSettingsDefaults.preferredDayEndHour
    @AppStorage(PlanningSettingsKeys.reduceMotion) private var reduceMotion = false
    @AppStorage(PlanningSettingsKeys.hasHomeBase) private var hasHomeBase = false
    @AppStorage(PlanningSettingsKeys.homeBaseName) private var homeBaseName = ""
    @AppStorage(PlanningSettingsKeys.homeBaseLatitude) private var homeBaseLatitude = PlanningSettingsDefaults.latitude
    @AppStorage(PlanningSettingsKeys.homeBaseLongitude) private var homeBaseLongitude = PlanningSettingsDefaults.longitude
    @AppStorage(PlanningSettingsKeys.includeHomeStartLeg) private var includeHomeStartLeg = true
    @AppStorage(PlanningSettingsKeys.includeHomeEndLeg) private var includeHomeEndLeg = true

    private var sequenceRuleSettings: SequenceRuleSettings {
        SequenceRuleSettings(
            avoidBackToBackFullMeals: avoidBackToBackFullMeals,
            avoidBackToBackHighEnergy: avoidBackToBackHighEnergy,
            allowBarCrawl: allowBarCrawl,
            allowShoppingRun: allowShoppingRun,
            snackCoffeeCanBuffer: snackCoffeeCanBuffer
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding()

            Picker("Travel", selection: $selectedTravelMode) {
                ForEach(TravelMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: selectedTravelMode) { _ in computeTravel() }

            PlanQuickHelp()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PlanContextBanner()
                    DaySummaryCard(
                        events: scheduleViewModel.events(on: selectedDate),
                        travelLegStatuses: travelLegStatuses,
                        homeStartTravelStatus: homeStartTravelStatus,
                        homeEndTravelStatus: homeEndTravelStatus,
                        hasHomeBase: hasHomeBase,
                        homeBaseName: homeBaseName,
                        includeHomeStartLeg: includeHomeStartLeg,
                        includeHomeEndLeg: includeHomeEndLeg,
                        useDayBounds: useDayBounds,
                        preferredDayStartHour: preferredDayStartHour,
                        preferredDayEndHour: preferredDayEndHour
                    )
                    unscheduledStrip
                    sequenceRulesView
                    warningsView
                    dropTargets
                    scheduledList
                    routeMap
                }
                .padding()
            }
        }
        .onAppear { computeTravel() }
        .onChange(of: selectedDate) { _ in computeTravel() }
        .overlay {
            ClearBurstView(isVisible: showClearBurst)
                .allowsHitTesting(false)
        }
        .alert("Calendar", isPresented: Binding(
            get: { exportMessage != nil },
            set: { if !$0 { exportMessage = nil } }
        )) {
            Button("OK", role: .cancel) { exportMessage = nil }
        } message: {
            Text(exportMessage ?? "")
        }
    }

    private var unscheduledStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card tray")
                .font(.headline)
            Text("Pull a card into the day. It stays flexible until you set a real time.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(boardViewModel.ideas.filter { idea in
                        idea.commitment != .locked &&
                        (idea.allowsMultipleScheduledInstances || !scheduleViewModel.hasScheduledInstance(for: idea.id))
                    }) { idea in
                        MagnetCardView(idea: idea, mode: .compact)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var sequenceRulesView: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Avoid full meals back-to-back", isOn: $avoidBackToBackFullMeals)
                Toggle("Avoid high-energy stops back-to-back", isOn: $avoidBackToBackHighEnergy)
                Toggle("Bar crawl / repeated bars are intentional", isOn: $allowBarCrawl)
                Toggle("Shopping run / repeated shops are intentional", isOn: $allowShoppingRun)
                Toggle("Snacks and coffee can act as buffer stops", isOn: $snackCoffeeCanBuffer)
                Text("These are soft preferences. They help the app notice awkward sequences without bossing you around.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        } label: {
            Label("Planning preferences", systemImage: "slider.horizontal.3")
                .font(.headline)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    @ViewBuilder private var warningsView: some View {
        let conflictWarnings = scheduleViewModel.conflictWarnings(for: selectedDate)
        let precisionWarnings = scheduleViewModel.precisionWarnings(for: selectedDate)
        let sequenceWarnings = scheduleViewModel.sequenceWarnings(for: selectedDate, settings: sequenceRuleSettings)
        let boundaryWarnings = useDayBounds ? scheduleViewModel.dayBoundaryWarnings(for: selectedDate, startHour: preferredDayStartHour, endHour: preferredDayEndHour) : []
        let modeWarnings = selectedTravelMode.estimateNote.map { [$0] } ?? []
        let warnings = conflictWarnings + precisionWarnings + sequenceWarnings + boundaryWarnings + modeWarnings

        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label("Things to check", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                ForEach(warnings, id: \.self) { warning in
                    Text("• \(warning)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.10)))
        }
    }

    private var dropTargets: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Drop into the day")
                .font(.headline)
            Text("These are soft baskets first. Use Must happen today when the timing is flexible but the card matters.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ScheduleDropZone(title: "Morning", subtitle: "rough, not exact", hour: DayPart.morning.proxyHour, selectedDate: selectedDate, targetPrecision: .dayPart, dayPart: .morning, forceMustDo: false)
                ScheduleDropZone(title: "Afternoon", subtitle: "rough, not exact", hour: DayPart.afternoon.proxyHour, selectedDate: selectedDate, targetPrecision: .dayPart, dayPart: .afternoon, forceMustDo: false)
                ScheduleDropZone(title: "Evening", subtitle: "rough, not exact", hour: DayPart.evening.proxyHour, selectedDate: selectedDate, targetPrecision: .dayPart, dayPart: .evening, forceMustDo: false)
            }
            HStack(spacing: 10) {
                ScheduleDropZone(title: "Sometime today", subtitle: "nice if it fits", hour: 12, selectedDate: selectedDate, targetPrecision: .dayOnly, dayPart: nil, forceMustDo: false)
                ScheduleDropZone(title: "Must happen today", subtitle: "flexible, but important", hour: 11, selectedDate: selectedDate, targetPrecision: .dayOnly, dayPart: nil, forceMustDo: true)
            }
        }
    }

    private var scheduledList: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Today’s flow")
                        .font(.headline)
                    Spacer()
                    Menu {
                        Button("Clear this day", role: .destructive) { clearThisDay() }
                        Button("Clear all scheduled cards", role: .destructive) { clearAllScheduledCards() }
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .font(.caption)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        makeDayFlowBetter()
                    } label: {
                        Label("Make it flow", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    ShareLink(item: dayShareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Text("Tip: drag planned rows up or down. Locked rows stay put.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            let events = scheduleViewModel.events(on: selectedDate)
            if events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No cards in the day yet")
                        .font(.headline)
                    Text("Drag a card from the tray into a soft basket above.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
            } else {
                ForEach(events) { event in
                    ScheduledEventRow(
                        event: event,
                        travelMode: selectedTravelMode,
                        travelLegStatus: travelLegStatuses[event.id],
                        onExport: { export(event) },
                        onManualTravelEstimate: { minutes, note in
                            scheduleViewModel.setManualTravelEstimate(after: event, minutes: minutes, note: note)
                            computeTravel()
                        },
                        onClearManualTravelEstimate: {
                            scheduleViewModel.clearManualTravelEstimate(after: event)
                            computeTravel()
                        },
                        onSetExactTime: { newStart in
                            scheduleViewModel.setExactTime(event, startDate: newStart)
                            computeTravel()
                        },
                        onSetRoughPlacement: { precision, dayPart, mustDo in
                            scheduleViewModel.setRoughPlacement(event, precision: precision, dayPart: dayPart)
                            if let mustDo { scheduleViewModel.setMustDo(event, mustDo) }
                            Haptics.lightImpact()
                            computeTravel()
                        },
                        onMoveEarlier: {
                            scheduleViewModel.moveEventWithinDay(event, on: selectedDate, direction: -1)
                            Haptics.lightImpact()
                            computeTravel()
                        },
                        onMoveLater: {
                            scheduleViewModel.moveEventWithinDay(event, on: selectedDate, direction: 1)
                            Haptics.lightImpact()
                            computeTravel()
                        },
                        onLockToggle: { scheduleViewModel.toggleLocked(event) },
                        onMustDoToggle: { scheduleViewModel.toggleMustDo(event) },
                        onDelete: { deleteScheduledEvent(event) }
                    )
                    .opacity(draggedScheduledEventID == event.id ? 0.55 : 1.0)
                    .onDrag {
                        draggedScheduledEventID = event.id
                        Haptics.lightImpact()
                        return NSItemProvider(object: event.id.uuidString as NSString)
                    } preview: {
                        ScheduledDragPreview(title: event.title, subtitle: event.schedulePrecision.label)
                    }
                    .onDrop(of: [UTType.plainText], delegate: ScheduledEventDropDelegate(
                        targetEvent: event,
                        selectedDate: selectedDate,
                        draggedEventID: $draggedScheduledEventID,
                        scheduleViewModel: scheduleViewModel,
                        onReordered: {
                            Haptics.lightImpact()
                            computeTravel()
                        }
                    ))
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
                }
                .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: events)
            }
        }
    }


    private func makeDayFlowBetter() {
        let eventsBefore = scheduleViewModel.events(on: selectedDate)
        guard !eventsBefore.isEmpty else {
            exportMessage = "Add a few cards to the day first, then I can help the plan flow."
            return
        }

        let notes = scheduleViewModel.smartArrangeRoughEvents(on: selectedDate, settings: sequenceRuleSettings)
        Haptics.success()
        computeTravel()

        if notes.isEmpty {
            exportMessage = "I checked the flow and travel. Nothing obvious needed changing."
        } else {
            exportMessage = notes.joined(separator: "\n")
        }
    }


    private var dayShareText: String {
        scheduleViewModel.plainTextPlanSummary(
            on: selectedDate,
            planName: planName,
            homeBaseName: hasHomeBase ? homeBaseName : "",
            travelLegStatuses: travelLegStatuses,
            homeStartTravelStatus: homeStartTravelStatus,
            homeEndTravelStatus: homeEndTravelStatus,
            useDayBounds: useDayBounds,
            startHour: preferredDayStartHour,
            endHour: preferredDayEndHour
        )
    }

    private func deleteScheduledEvent(_ event: EventItem) {
        let removedEvent = event
        withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
            scheduleViewModel.deleteEvent(event)
        }
        if !scheduleViewModel.hasScheduledInstance(for: event.ideaID) {
            boardViewModel.markUnscheduled(event.ideaID)
        }
        Haptics.lightImpact()
        undoViewModel.register(
            title: "Removed from plan",
            message: "\(event.title) was removed.",
            systemImage: "sparkles"
        ) {
            scheduleViewModel.restoreEvent(removedEvent)
            boardViewModel.markScheduled(removedEvent.ideaID, locked: removedEvent.isLocked)
            computeTravel()
        }
        computeTravel()
    }

    private func clearThisDay() {
        let removed = scheduleViewModel.events(on: selectedDate)
        guard !removed.isEmpty else {
            exportMessage = "Nothing to clear for this day."
            return
        }
        withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
            _ = scheduleViewModel.deleteEvents(on: selectedDate)
        }
        refreshBoardCommitmentsAfterRemoving(removed)
        showClearAnimation()
        Haptics.warning()
        undoViewModel.register(
            title: "Cleared this day",
            message: "Removed \(removed.count) planned card\(removed.count == 1 ? "" : "s").",
            systemImage: "flame"
        ) {
            scheduleViewModel.restoreEvents(removed)
            for event in removed {
                boardViewModel.markScheduled(event.ideaID, locked: event.isLocked)
            }
            computeTravel()
        }
        computeTravel()
    }

    private func clearAllScheduledCards() {
        let removed = scheduleViewModel.events
        guard !removed.isEmpty else {
            exportMessage = "There are no scheduled cards to clear."
            return
        }
        withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
            _ = scheduleViewModel.deleteAllEvents()
        }
        refreshBoardCommitmentsAfterRemoving(removed)
        showClearAnimation()
        Haptics.warning()
        undoViewModel.register(
            title: "Cleared schedule",
            message: "Removed \(removed.count) planned card\(removed.count == 1 ? "" : "s").",
            systemImage: "flame"
        ) {
            scheduleViewModel.restoreEvents(removed)
            for event in removed {
                boardViewModel.markScheduled(event.ideaID, locked: event.isLocked)
            }
            computeTravel()
        }
        computeTravel()
    }

    private func refreshBoardCommitmentsAfterRemoving(_ removed: [EventItem]) {
        let affectedIdeaIDs = Set(removed.map(\.ideaID))
        for ideaID in affectedIdeaIDs where !scheduleViewModel.hasScheduledInstance(for: ideaID) {
            boardViewModel.markUnscheduled(ideaID)
        }
    }

    private func showClearAnimation() {
        guard !reduceMotion else { return }
        showClearBurst = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 950_000_000)
            showClearBurst = false
        }
    }

    @ViewBuilder private var routeMap: some View {
        if !routePolylines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Route preview")
                    .font(.headline)
                RouteMapView(polylines: routePolylines)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private func export(_ event: EventItem) {
        guard event.schedulePrecision == .exactTime else {
            exportMessage = "Set an exact time for \(event.title) before exporting it to Apple Calendar. Rough sticky-note placements can stay in Magnet Board until you are ready."
            return
        }

        Task {
            let result = await scheduleViewModel.exportToCalendar(event)
            switch result {
            case .success:
                exportMessage = "Exported \(event.title) to Apple Calendar."
            case .notExactTime:
                exportMessage = "Set an exact time before exporting this sticky-note plan to Apple Calendar."
            case .permissionDenied:
                exportMessage = "Calendar access was not granted. You can still keep this as an in-app plan."
            case .noDefaultCalendar:
                exportMessage = "No default Apple Calendar is available for new events."
            case .failed(let message):
                exportMessage = "Could not export \(event.title): \(message)"
            }
        }
    }

    private func computeTravel() {
        travelLegStatuses = [:]
        homeStartTravelStatus = nil
        homeEndTravelStatus = nil
        routePolylines = []
        let events = scheduleViewModel.events(on: selectedDate)
        guard !events.isEmpty else { return }

        computeHomeBaseTravel(for: events)

        guard events.count > 1 else { return }

        for idx in 0..<(events.count - 1) {
            let from = events[idx]
            let to = events[idx + 1]
            travelLegStatuses[from.id] = .calculating

            scheduleViewModel.calculateTravelLegStatus(from: from, to: to, travelMode: selectedTravelMode, departureDate: from.endDate) { status in
                Task { @MainActor in travelLegStatuses[from.id] = status }
            }

            // Manual estimates are a deliberate opt-out from the Maps ETA path for this leg.
            // Do not draw a route for a leg where the user has chosen to supply their own estimate.
            guard from.manualTravelToNextSeconds == nil else { continue }

            scheduleViewModel.calculateRoute(from: from, to: to, travelMode: selectedTravelMode, departureDate: from.endDate) { route in
                guard let route else { return }
                Task { @MainActor in routePolylines.append(route.polyline) }
            }
        }
    }


    private func computeHomeBaseTravel(for events: [EventItem]) {
        guard hasHomeBase else { return }
        let homeCoordinate = CLLocationCoordinate2D(latitude: homeBaseLatitude, longitude: homeBaseLongitude)
        guard let first = events.first, let last = events.last else { return }

        if includeHomeStartLeg {
            homeStartTravelStatus = .calculating
            scheduleViewModel.calculateTravelLegStatus(
                fromCoordinate: homeCoordinate,
                toCoordinate: first.coordinate?.clLocationCoordinate2D,
                travelMode: selectedTravelMode,
                departureDate: first.startDate
            ) { status in
                Task { @MainActor in homeStartTravelStatus = status }
            }

            scheduleViewModel.calculateRoute(
                fromCoordinate: homeCoordinate,
                toCoordinate: first.coordinate?.clLocationCoordinate2D,
                travelMode: selectedTravelMode,
                departureDate: first.startDate
            ) { route in
                guard let route else { return }
                Task { @MainActor in routePolylines.append(route.polyline) }
            }
        }

        if includeHomeEndLeg {
            homeEndTravelStatus = .calculating
            scheduleViewModel.calculateTravelLegStatus(
                fromCoordinate: last.coordinate?.clLocationCoordinate2D,
                toCoordinate: homeCoordinate,
                travelMode: selectedTravelMode,
                departureDate: last.endDate
            ) { status in
                Task { @MainActor in homeEndTravelStatus = status }
            }

            scheduleViewModel.calculateRoute(
                fromCoordinate: last.coordinate?.clLocationCoordinate2D,
                toCoordinate: homeCoordinate,
                travelMode: selectedTravelMode,
                departureDate: last.endDate
            ) { route in
                guard let route else { return }
                Task { @MainActor in routePolylines.append(route.polyline) }
            }
        }
    }
}


struct PlanQuickHelp: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.draw")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text("Rough first. Exact later.")
                    .font(.subheadline.weight(.semibold))
                Text("Drop cards into broad parts of the day. Use exact times only for real commitments.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGroupedBackground))
    }
}


struct DaySummaryCard: View {
    let events: [EventItem]
    let travelLegStatuses: [UUID: TravelLegStatus]
    let homeStartTravelStatus: TravelLegStatus?
    let homeEndTravelStatus: TravelLegStatus?
    let hasHomeBase: Bool
    let homeBaseName: String
    let includeHomeStartLeg: Bool
    let includeHomeEndLeg: Bool
    let useDayBounds: Bool
    let preferredDayStartHour: Double
    let preferredDayEndHour: Double

    private var activitySeconds: TimeInterval {
        events.reduce(0) { $0 + max(0, $1.endDate.timeIntervalSince($1.startDate)) }
    }

    private var knownTravelSeconds: TimeInterval {
        let internalSeconds = travelLegStatuses.values.compactMap(\.seconds).reduce(0, +)
        let homeSeconds = [homeStartTravelStatus, homeEndTravelStatus].compactMap { $0?.seconds }.reduce(0, +)
        return internalSeconds + homeSeconds
    }

    private var roughCount: Int { events.filter { $0.schedulePrecision != .exactTime }.count }
    private var mustDoCount: Int { events.filter { $0.isMustDo }.count }
    private var missingLocationCount: Int { events.filter { $0.coordinate == nil }.count }

    private var planMoodLabel: String {
        if events.isEmpty { return "Blank canvas" }
        if missingLocationCount > 0 { return "Needs details" }
        if events.count >= 6 || (activitySeconds + knownTravelSeconds) >= 8 * 60 * 60 { return "Packed" }
        if roughCount > 0 { return "Flexible" }
        return "Looks tidy"
    }

    private var planMoodIcon: String {
        if events.isEmpty { return "sparkles" }
        if missingLocationCount > 0 { return "mappin.slash" }
        if events.count >= 6 || (activitySeconds + knownTravelSeconds) >= 8 * 60 * 60 { return "figure.run" }
        if roughCount > 0 { return "leaf" }
        return "checkmark.seal"
    }

    private var planMoodHelp: String {
        if events.isEmpty { return "Drag in a card to start shaping the day." }
        if missingLocationCount > 0 { return "Some cards need a place before travel can be trusted." }
        if events.count >= 6 || (activitySeconds + knownTravelSeconds) >= 8 * 60 * 60 { return "This may be a full day. Consider breaks or backup options." }
        if roughCount > 0 { return "Nice: some parts are still movable." }
        return "Everything is placed clearly."
    }

    private var leaveHomeSuggestion: String? {
        guard let first = events.first,
              first.schedulePrecision == .exactTime,
              let seconds = homeStartTravelStatus?.seconds else { return nil }
        let leave = first.startDate.addingTimeInterval(-seconds)
        return "Leave home around \(leave.formatted(date: .omitted, time: .shortened))."
    }

    private var backHomeDate: Date? {
        guard let last = events.last,
              last.schedulePrecision == .exactTime,
              let seconds = homeEndTravelStatus?.seconds else { return nil }
        return last.endDate.addingTimeInterval(seconds)
    }

    private var backHomeSuggestion: String? {
        guard let backHomeDate else { return nil }
        return "Back home around \(backHomeDate.formatted(date: .omitted, time: .shortened))."
    }

    private var backHomeIsLate: Bool {
        guard useDayBounds, let backHomeDate else { return false }
        return hourValue(for: backHomeDate) > preferredDayEndHour
    }

    private func hourValue(for date: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return Double(hour) + Double(minute) / 60.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Day summary", systemImage: "sparkles.rectangle.stack")
                    .font(.headline)
                Spacer()
                Label(planMoodLabel, systemImage: planMoodIcon)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                    .foregroundStyle(Color.accentColor)
            }

            Text(planMoodHelp)
                .font(.caption)
                .foregroundStyle(.secondary)

            if events.isEmpty {
                Text("No cards in this day yet. Drag in a loose card to start shaping the plan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    SummaryPill(title: "Stops", value: "\(events.count)", systemImage: "rectangle.stack")
                    SummaryPill(title: "Must-do", value: "\(mustDoCount)", systemImage: "star")
                    SummaryPill(title: "Activity", value: formatDuration(activitySeconds), systemImage: "clock")
                    SummaryPill(title: "Known travel", value: knownTravelSeconds > 0 ? formatDuration(knownTravelSeconds) : "unknown", systemImage: "arrow.triangle.swap")
                    SummaryPill(title: "Rough cards", value: "\(roughCount)", systemImage: "hand.draw")
                }

                if hasHomeBase && (includeHomeStartLeg || includeHomeEndLeg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Home base legs", systemImage: "house.fill")
                            .font(.caption.weight(.semibold))
                        Text("Home-base travel is included for the parts of the day you turned on in Settings.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if includeHomeStartLeg, let homeStartTravelStatus {
                            Text("• Home → first stop: \(homeStartTravelStatus.label)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let text = leaveHomeSuggestion {
                                Text("  \(text)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        if includeHomeEndLeg, let homeEndTravelStatus {
                            Text("• Last stop → home: \(homeEndTravelStatus.label)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let text = backHomeSuggestion {
                                Text("  \(text)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(backHomeIsLate ? .orange : Color.accentColor)
                            }
                        }
                    }
                }

                if useDayBounds {
                    Text("Usual day shape: \(formatHour(preferredDayStartHour))–\(formatHour(preferredDayEndHour)). This is a soft guide, not a hard rule.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if missingLocationCount > 0 {
                    Text("\(missingLocationCount) card\(missingLocationCount == 1 ? "" : "s") need exact coordinates before map travel can be fully estimated. Manual estimates still work.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [CutePalette.boardSky.opacity(0.38), Color(.secondarySystemGroupedBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.accentColor.opacity(0.18), lineWidth: 0.8))
        .accessibilityElement(children: .combine)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(round(seconds / 60))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    private func formatHour(_ hour: Double) -> String {
        let minutes = Int((hour * 60).rounded())
        let wrapped = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60)
        return String(format: "%02d:%02d", wrapped / 60, wrapped % 60)
    }
}

struct SummaryPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.tertiarySystemGroupedBackground).opacity(0.88)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor.opacity(0.10), lineWidth: 0.6))
    }
}

struct ScheduleDropZone: View {
    @EnvironmentObject var boardViewModel: BoardViewModel
    @EnvironmentObject var scheduleViewModel: ScheduleViewModel

    let title: String
    let subtitle: String
    let hour: Int
    let selectedDate: Date
    let targetPrecision: SchedulePrecision
    let dayPart: DayPart?
    let forceMustDo: Bool
    @State private var isTargeted = false
    @State private var dropNotice: String?

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: dayPart?.systemImage ?? "arrow.down.app")
                .font(.title3)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(isTargeted ? targetHint : subtitle)
                .font(.caption2.weight(isTargeted ? .semibold : .regular))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 90)
        .padding(8)
        .scaleEffect(isTargeted ? 1.04 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isTargeted)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isTargeted ? Color.accentColor.opacity(0.18) : dropZoneWash)
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(isTargeted ? Color.accentColor : dropZoneTint.opacity(0.25), lineWidth: isTargeted ? 2 : 0.8))
        .onDrop(of: [UTType.plainText], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        .alert("Could not schedule card", isPresented: Binding(
            get: { dropNotice != nil },
            set: { if !$0 { dropNotice = nil } }
        )) {
            Button("OK", role: .cancel) { dropNotice = nil }
        } message: {
            Text(dropNotice ?? "")
        }
    }

    private var dropZoneTint: Color {
        if forceMustDo { return .yellow }
        switch dayPart {
        case .morning: return .orange
        case .afternoon: return .blue
        case .evening: return .purple
        case .none: return .pink
        }
    }

    private var dropZoneWash: Color { dropZoneTint.opacity(0.12) }

    private var targetHint: String {
        switch targetPrecision {
        case .exactTime:
            return "Drop to make exact"
        case .dayPart:
            return "Drop to place in \(dayPart?.label.lowercased() ?? "this part of the day")"
        case .dayOnly:
            return "Drop here"
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                let idString: String?
                if let data = item as? Data {
                    idString = String(data: data, encoding: .utf8)
                } else if let string = item as? String {
                    idString = string
                } else {
                    idString = nil
                }
                guard let idString, let uuid = UUID(uuidString: idString) else { return }
                Task { @MainActor in
                    guard let idea = boardViewModel.ideas.first(where: { $0.id == uuid }) else { return }
                    let start = scheduleViewModel.firstOpenSlot(
                        on: selectedDate,
                        preferredHour: hour,
                        duration: idea.duration ?? 60 * 60
                    )
                    let result = scheduleViewModel.scheduleIdea(
                        idea,
                        startDate: start,
                        schedulePrecision: targetPrecision,
                        dayPart: dayPart
                    )
                    switch result {
                    case .scheduled(let event):
                        if forceMustDo { scheduleViewModel.toggleMustDo(event) }
                        Haptics.success()
                        boardViewModel.markScheduled(idea.id)
                    case .duplicateNotAllowed(let existing):
                        Haptics.warning()
                        dropNotice = "\(idea.title) is already in the plan at \(existing.startDate.formatted(date: .abbreviated, time: .shortened)). Turn on ‘Can use this more than once’ in the card details if that is intentional."
                    }
                }
            }
        }
        return true
    }
}

struct ScheduledEventRow: View {
    let event: EventItem
    let travelMode: TravelMode
    let travelLegStatus: TravelLegStatus?
    let onExport: () -> Void
    let onManualTravelEstimate: (_ minutes: Double, _ note: String?) -> Void
    let onClearManualTravelEstimate: () -> Void
    let onSetExactTime: (_ startDate: Date) -> Void
    let onSetRoughPlacement: (_ precision: SchedulePrecision, _ dayPart: DayPart?, _ mustDo: Bool?) -> Void
    let onMoveEarlier: () -> Void
    let onMoveLater: () -> Void
    let onLockToggle: () -> Void
    let onMustDoToggle: () -> Void
    let onDelete: () -> Void

    @State private var showingManualTravelSheet = false
    @State private var showingExactTimeSheet = false

    private var mustDoTimingText: String {
        switch event.schedulePrecision {
        case .dayOnly: return "today"
        case .dayPart: return "this \(event.dayPart?.label.lowercased() ?? "part of the day")"
        case .exactTime: return "at this time"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(event.category.cuteEmoji)
                    .font(.title2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.headline)
                    HStack(spacing: 5) {
                        Label(schedulePlacementLabel, systemImage: schedulePlacementIcon)
                        if event.isLocked {
                            Label("Locked", systemImage: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button(event.isLocked ? "Unlock" : "Lock") { onLockToggle() }
                    Button(event.isMustDo ? "Mark as flexible/maybe" : "Mark must happen today") { onMustDoToggle() }
                    Button(event.schedulePrecision == .exactTime ? "Change exact time…" : "Set exact time…") { showingExactTimeSheet = true }
                    Menu("Make rough / flexible") {
                        Button("Sometime today") { onSetRoughPlacement(.dayOnly, nil, nil) }
                        Button("Must happen today") { onSetRoughPlacement(.dayOnly, nil, true) }
                        Divider()
                        Button("Morning") { onSetRoughPlacement(.dayPart, .morning, nil) }
                        Button("Must happen this morning") { onSetRoughPlacement(.dayPart, .morning, true) }
                        Button("Afternoon") { onSetRoughPlacement(.dayPart, .afternoon, nil) }
                        Button("Must happen this afternoon") { onSetRoughPlacement(.dayPart, .afternoon, true) }
                        Button("Evening") { onSetRoughPlacement(.dayPart, .evening, nil) }
                        Button("Must happen this evening") { onSetRoughPlacement(.dayPart, .evening, true) }
                    }
                    Button("Export to Apple Calendar") { onExport() }
                    Divider()
                    Button("Move earlier") { onMoveEarlier() }
                        .disabled(event.isLocked)
                    Button("Move later") { onMoveLater() }
                        .disabled(event.isLocked)
                    Divider()
                    Button("Set manual travel to next…") { showingManualTravelSheet = true }
                    if event.manualTravelToNextSeconds != nil {
                        Button("Clear manual travel estimate") { onClearManualTravelEstimate() }
                    }
                    Divider()
                    Button("Delete from plan", role: .destructive) { onDelete() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }

            if !event.locationName.isEmpty {
                Label(event.locationName, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if event.category != .unspecified {
                CuteBadge(emoji: event.category.cuteEmoji, text: event.category.label, tint: event.category.cuteTint)
            }

            if event.isMustDo {
                Label("Must happen \(mustDoTimingText)", systemImage: "star.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
            }

            if let travelLegStatus {
                TravelLegStatusView(status: travelLegStatus, travelMode: travelMode)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [event.category.cuteWash, Color(.secondarySystemGroupedBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(event.category.cuteTint.opacity(0.24), lineWidth: 0.8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Planned card, \(event.title), \(schedulePlacementLabel)")
        .accessibilityHint(event.isLocked ? "Locked. Use the actions menu for options." : "Drag to reorder, or use the actions menu for options.")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingManualTravelSheet) {
            ManualTravelEstimateSheet(
                initialMinutes: event.manualTravelToNextSeconds.map { $0 / 60 } ?? 20,
                initialNote: event.manualTravelToNextNote ?? "",
                onSave: { minutes, note in
                    onManualTravelEstimate(minutes, note)
                    showingManualTravelSheet = false
                },
                onCancel: { showingManualTravelSheet = false }
            )
        }
        .sheet(isPresented: $showingExactTimeSheet) {
            ExactTimeSheet(
                initialStart: event.startDate,
                duration: event.endDate.timeIntervalSince(event.startDate),
                onSave: { newStart in
                    onSetExactTime(newStart)
                    showingExactTimeSheet = false
                },
                onCancel: { showingExactTimeSheet = false }
            )
        }
    }

    private var schedulePlacementLabel: String {
        switch event.schedulePrecision {
        case .exactTime:
            return "\(event.startDate.formatted(date: .omitted, time: .shortened))–\(event.endDate.formatted(date: .omitted, time: .shortened))"
        case .dayPart:
            if let dayPart = event.dayPart {
                return "\(dayPart.label) · rough"
            }
            return "Part of day · rough"
        case .dayOnly:
            return "Sometime today"
        }
    }

    private var schedulePlacementIcon: String {
        switch event.schedulePrecision {
        case .exactTime:
            return "clock.badge.checkmark"
        case .dayPart:
            return event.dayPart?.systemImage ?? "clock"
        case .dayOnly:
            return "calendar"
        }
    }
}

struct TravelLegStatusView: View {
    let status: TravelLegStatus
    let travelMode: TravelMode

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: status.systemImage)
            Text(status.label)
        }
        .font(.caption)
        .foregroundStyle(foregroundStyle)
    }

    private var foregroundStyle: Color {
        switch status {
        case .failed, .missingCoordinates:
            return .orange
        case .manualEstimate:
            return .blue
        default:
            return .secondary
        }
    }
}

struct ExactTimeSheet: View {
    @State private var startDate: Date

    let duration: TimeInterval
    let onSave: (_ startDate: Date) -> Void
    let onCancel: () -> Void

    init(initialStart: Date,
         duration: TimeInterval,
         onSave: @escaping (_ startDate: Date) -> Void,
         onCancel: @escaping () -> Void) {
        _startDate = State(initialValue: initialStart)
        self.duration = duration
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    Text("End: \(startDate.addingTimeInterval(duration).formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Exact time")
                } footer: {
                    Text("Use this when the sticky note has become a real scheduled commitment. Exact times unlock stronger conflict checking and Apple Calendar export.")
                }
            }
            .navigationTitle("Set Exact Time")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(startDate) }
                }
            }
        }
    }
}

struct ManualTravelEstimateSheet: View {
    @State private var minutesText: String
    @State private var note: String

    let onSave: (_ minutes: Double, _ note: String?) -> Void
    let onCancel: () -> Void

    init(initialMinutes: Double,
         initialNote: String,
         onSave: @escaping (_ minutes: Double, _ note: String?) -> Void,
         onCancel: @escaping () -> Void) {
        _minutesText = State(initialValue: String(Int(round(initialMinutes))))
        _note = State(initialValue: initialNote)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Minutes", text: $minutesText)
                        .keyboardType(.numberPad)
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Manual travel estimate")
                } footer: {
                    Text("Use this when you already know the travel time, do not want to use Maps, or do not have exact coordinates yet.")
                }
            }
            .navigationTitle("Travel Estimate")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let minutes = Double(minutesText), minutes >= 0 else { return }
                        onSave(minutes, note)
                    }
                    .disabled(Double(minutesText) == nil)
                }
            }
        }
    }
}

// MARK: - Drag-to-reorder support

struct ScheduledDragPreview: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.draw")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .shadow(radius: 12, y: 8)
    }
}

struct ScheduledEventDropDelegate: DropDelegate {
    let targetEvent: EventItem
    let selectedDate: Date
    @Binding var draggedEventID: UUID?
    let scheduleViewModel: ScheduleViewModel
    let onReordered: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedEventID,
              draggedEventID != targetEvent.id else { return }
        scheduleViewModel.reorderEvent(draggedEventID, before: targetEvent.id, on: selectedDate)
        onReordered()
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedEventID = nil
        Haptics.success()
        return true
    }

    func dropExited(info: DropInfo) {}

    func validateDrop(info: DropInfo) -> Bool {
        true
    }
}
