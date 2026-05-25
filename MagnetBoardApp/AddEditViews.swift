import SwiftUI
import CoreLocation

// MARK: - Add / Edit / Detail Views

struct AddIdeaView: View {
    @EnvironmentObject var boardViewModel: BoardViewModel
    @Binding var isPresented: Bool

    @State private var title = ""
    @State private var includeDuration = false
    @State private var durationMinutes = 60.0
    @State private var includeCost = false
    @State private var cost = ""
    @State private var locationName = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var showingLocationSearch = false
    @State private var notes = ""
    @State private var tags = ""
    @State private var people = ""
    @State private var category: ActivityCategory = .unspecified
    @State private var allowsMultipleScheduledInstances = false
    @State private var commitment: CardCommitment = .loose
    @State private var group: BoardGroup = .ideas
    @State private var priority = 2

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick start") {
                    Text("Tap one of these, or write your own card below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        TemplateButton(title: "Coffee stop", systemImage: "cup.and.saucer") { applyTemplate(title: "Coffee stop", category: .snackCoffee, repeatable: true, durationMinutes: 30, group: .ideas) }
                        TemplateButton(title: "Fun dinner", systemImage: "fork.knife") { applyTemplate(title: "Fun dinner", category: .fullMeal, repeatable: false, durationMinutes: 90, group: .maybe) }
                        TemplateButton(title: "Shopping", systemImage: "bag") { applyTemplate(title: "Shopping", category: .shopping, repeatable: true, durationMinutes: 60, group: .ideas) }
                        TemplateButton(title: "Museum", systemImage: "building.columns") { applyTemplate(title: "Museum / culture stop", category: .cultureMuseum, repeatable: false, durationMinutes: 120, group: .mustDo, priority: 1) }
                        TemplateButton(title: "Brunch", systemImage: "fork.knife.circle") { applyTemplate(title: "Brunch", category: .fullMeal, repeatable: false, durationMinutes: 90, group: .maybe) }
                        TemplateButton(title: "Date night", systemImage: "heart") { applyTemplate(title: "Date night", category: .nightlife, repeatable: false, durationMinutes: 180, group: .mustDo, priority: 1, tags: "date night") }
                        TemplateButton(title: "Parents visit", systemImage: "person.2") { applyTemplate(title: "Good with parents", category: .cultureMuseum, repeatable: true, durationMinutes: 120, group: .ideas, tags: "parents, easy") }
                        TemplateButton(title: "Rainy day", systemImage: "cloud.rain") { applyTemplate(title: "Rainy-day backup", category: .cultureMuseum, repeatable: true, durationMinutes: 90, group: .maybe, tags: "rainy day, backup") }
                        TemplateButton(title: "Bar crawl", systemImage: "wineglass") { applyTemplate(title: "Bar stop", category: .bar, repeatable: true, durationMinutes: 45, group: .ideas, tags: "bar crawl") }
                        TemplateButton(title: "Cute café", systemImage: "cup.and.saucer.fill") { applyTemplate(title: "Cute café", category: .snackCoffee, repeatable: true, durationMinutes: 45, group: .ideas, tags: "cute, café") }
                        TemplateButton(title: "Vintage shops", systemImage: "sparkles") { applyTemplate(title: "Vintage / thrift shops", category: .shopping, repeatable: true, durationMinutes: 90, group: .ideas, tags: "shopping, cute") }
                        TemplateButton(title: "Walk by water", systemImage: "water.waves") { applyTemplate(title: "Walk by the water", category: .outdoorSightseeing, repeatable: true, durationMinutes: 60, group: .maybe, tags: "walk, easy") }
                        TemplateButton(title: "Hair appt", systemImage: "scissors") { applyTemplate(title: "Hair appointment", category: .appointment, repeatable: false, durationMinutes: 90, group: .mustDo, priority: 1, tags: "appointment") }
                    }
                }

                Section("Card basics") {
                    TextField("Title, e.g. Saturday market", text: $title)
                    Picker("How real is this?", selection: $commitment) {
                        Text(CardCommitment.loose.label).tag(CardCommitment.loose)
                        Text(CardCommitment.detailed.label).tag(CardCommitment.detailed)
                    }
                    Text("New cards start as loose or detailed ideas. They become scheduled or locked only after being placed into a plan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Board area", selection: $group) {
                        ForEach(BoardGroup.allCases) { group in
                            Text(group.title).tag(group)
                        }
                    }
                    Picker("Category", selection: $category) {
                        ForEach(ActivityCategory.allCases) { category in
                            Label(category.label, systemImage: category.systemImage).tag(category)
                        }
                    }
                    Toggle("Can use this more than once", isOn: $allowsMultipleScheduledInstances)
                    Text("Use this for reusable ideas like coffee, bars, or shopping. Leave it off for reservations, appointments, and one-off visits.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Priority", selection: $priority) {
                        Text("High").tag(1)
                        Text("Normal").tag(2)
                        Text("Low").tag(3)
                    }
                }

                Section("Optional details") {
                    Toggle("Include duration", isOn: $includeDuration)
                    if includeDuration {
                        Stepper(value: $durationMinutes, in: 15...480, step: 15) {
                            Text("Duration: \(Int(durationMinutes)) min")
                        }
                    }

                    Toggle("Include cost", isOn: $includeCost)
                    if includeCost {
                        TextField("Cost", text: $cost)
                            .keyboardType(.decimalPad)
                    }

                    HStack {
                        TextField("Location or neighborhood", text: $locationName)
                        Button("Search") { showingLocationSearch = true }
                    }
                    if selectedCoordinate != nil {
                        Label("Exact place selected for Maps/ETA.", systemImage: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    DisclosureGroup("Developer coordinates") {
                        Text("Normal users should use Search. Coordinates are here only for testing or manual fixes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField("Latitude", text: $latitude)
                                .keyboardType(.numbersAndPunctuation)
                            TextField("Longitude", text: $longitude)
                                .keyboardType(.numbersAndPunctuation)
                        }
                    }
                    TextField("Tags, comma-separated", text: $tags)
                    TextField("People, comma-separated", text: $people)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Why details matter") {
                    Text("Vague cards are valid. Add duration for overpacking warnings, location for map/travel help, and exact time only when something is truly scheduled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New idea")
            .sheet(isPresented: $showingLocationSearch) {
                LocationSearchSheet(initialQuery: locationName) { result in
                    locationName = result.name
                    latitude = String(format: "%.6f", result.coordinate.latitude)
                    longitude = String(format: "%.6f", result.coordinate.longitude)
                    selectedCoordinate = result.coordinate.clLocationCoordinate2D
                    showingLocationSearch = false
                } onCancel: {
                    showingLocationSearch = false
                }
            }
            .onChange(of: category) { newCategory in
                allowsMultipleScheduledInstances = newCategory.isRepeatFriendlyByDefault
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addCard() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func applyTemplate(title: String,
                               category: ActivityCategory,
                               repeatable: Bool,
                               durationMinutes: Double,
                               group: BoardGroup,
                               priority: Int = 2,
                               tags: String = "") {
        self.title = title
        self.category = category
        self.allowsMultipleScheduledInstances = repeatable
        self.includeDuration = true
        self.durationMinutes = durationMinutes
        self.group = group
        self.priority = priority
        if !tags.isEmpty { self.tags = tags }
        Haptics.lightImpact()
    }

    private func addCard() {
        let coordinate: CLLocationCoordinate2D?
        if let selectedCoordinate {
            coordinate = selectedCoordinate
        } else if let lat = Double(latitude), let lon = Double(longitude) {
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            coordinate = nil
        }

        Haptics.success()
        boardViewModel.addIdea(
            title: title,
            duration: includeDuration ? durationMinutes * 60 : nil,
            cost: includeCost ? Double(cost.replacingOccurrences(of: ",", with: ".")) : nil,
            locationName: locationName,
            coordinate: coordinate,
            notes: notes,
            tags: splitCSV(tags),
            people: splitCSV(people),
            category: category,
            allowsMultipleScheduledInstances: allowsMultipleScheduledInstances,
            commitment: commitment,
            group: group,
            priority: priority
        )
        isPresented = false
    }
}

struct TemplateButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(CutePalette.boardBlush.opacity(0.28))
            )
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor.opacity(0.16), lineWidth: 0.7))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }
}

struct IdeaDetailView: View {
    @EnvironmentObject var boardViewModel: BoardViewModel
    @EnvironmentObject var scheduleViewModel: ScheduleViewModel
    @EnvironmentObject var undoViewModel: DelightUndoViewModel
    @Environment(\.dismiss) private var dismiss
    @State var idea: IdeaItem
    @State private var showingLocationSearch = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Card") {
                    TextField("Title", text: $idea.title)
                    if idea.commitment == .scheduled || idea.commitment == .locked {
                        LabeledContent("State", value: idea.commitment.label)
                        Text("Scheduled and locked states are controlled from the Plan view so a card cannot claim to be scheduled without an actual scheduled placement.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("State", selection: $idea.commitment) {
                            Text(CardCommitment.loose.label).tag(CardCommitment.loose)
                            Text(CardCommitment.detailed.label).tag(CardCommitment.detailed)
                        }
                        Text(idea.commitment.helpText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Picker("Category", selection: $idea.category) {
                        ForEach(ActivityCategory.allCases) { category in
                            Label(category.label, systemImage: category.systemImage).tag(category)
                        }
                    }
                    Toggle("Can use this more than once", isOn: $idea.allowsMultipleScheduledInstances)
                    Text("Turn this on for intentionally repeatable cards. Keep it off for reservations, appointments, and one-off visits.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Details") {
                    OptionalDurationEditor(duration: $idea.duration)
                    OptionalCostEditor(cost: $idea.cost)
                    HStack {
                        TextField("Location or neighborhood", text: $idea.locationName)
                        Button("Search") { showingLocationSearch = true }
                    }
                    if let coordinate = idea.coordinate {
                        Label(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude), systemImage: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("No exact coordinate yet. Maps ETA needs coordinates, but manual travel estimates still work.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    TextField("Notes", text: $idea.notes, axis: .vertical)
                        .lineLimit(3...8)
                    TextField("Tags", text: Binding(
                        get: { idea.tags.joined(separator: ", ") },
                        set: { idea.tags = splitCSV($0) }
                    ))
                    TextField("People", text: Binding(
                        get: { idea.people.joined(separator: ", ") },
                        set: { idea.people = splitCSV($0) }
                    ))
                }

                Section("Planning readiness") {
                    if idea.missingInfoHints.isEmpty {
                        Label("Enough information for stronger planning help.", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    } else {
                        Text("Missing: \(idea.missingInfoHints.joined(separator: ", "))")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Card details")
            .sheet(isPresented: $showingLocationSearch) {
                LocationSearchSheet(initialQuery: idea.locationName) { result in
                    idea.locationName = result.name
                    idea.coordinate = result.coordinate
                    showingLocationSearch = false
                } onCancel: {
                    showingLocationSearch = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Delete", role: .destructive) {
                        deleteCardWithUndo()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        boardViewModel.updateIdea(idea)
                        dismiss()
                    }
                }
            }
        }
    }

    private func deleteCardWithUndo() {
        let removedIdea = idea
        let removedEvents = scheduleViewModel.deleteEvents(forIdeaID: idea.id)
        boardViewModel.removeIdea(idea)
        Haptics.warning()
        undoViewModel.register(
            title: "Card deleted",
            message: removedEvents.isEmpty ? "\(removedIdea.title) was removed." : "\(removedIdea.title) and \(removedEvents.count) planned item\(removedEvents.count == 1 ? "" : "s") were removed.",
            systemImage: "sparkles"
        ) {
            boardViewModel.restoreIdea(removedIdea)
            scheduleViewModel.restoreEvents(removedEvents)
        }
        dismiss()
    }

}

struct OptionalDurationEditor: View {
    @Binding var duration: TimeInterval?
    @State private var minutes: Double = 60

    var body: some View {
        Toggle("Has duration", isOn: Binding(
            get: { duration != nil },
            set: { enabled in duration = enabled ? minutes * 60 : nil }
        ))
        if duration != nil {
            Stepper(value: Binding(
                get: { (duration ?? 3600) / 60 },
                set: { duration = $0 * 60; minutes = $0 }
            ), in: 15...480, step: 15) {
                Text("Duration: \(Int((duration ?? 3600) / 60)) min")
            }
        }
    }
}

struct OptionalCostEditor: View {
    @Binding var cost: Double?

    var body: some View {
        Toggle("Has cost", isOn: Binding(
            get: { cost != nil },
            set: { enabled in cost = enabled ? 0 : nil }
        ))
        if cost != nil {
            TextField("Cost", value: Binding(
                get: { cost ?? 0 },
                set: { cost = $0 }
            ), format: .number)
            .keyboardType(.decimalPad)
        }
    }
}
