import SwiftUI

/// Starting from a basket should not require a round trip through the board.
struct PlanCardPicker: View {
    let basketTitle: String
    let date: Date
    let ideas: [IdeaItem]
    let availableIDs: Set<UUID>
    let onPick: (UUID) -> Void
    let onCreate: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var committed = false
    @FocusState private var typing: Bool

    private var title: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var matches: [IdeaItem] {
        ideas.filter { title.isEmpty || $0.title.localizedStandardContains(title) }
    }
    private var exact: [IdeaItem] {
        matches.filter { $0.title.compare(title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }
    private var canCreate: Bool { !title.isEmpty && exact.isEmpty }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Find or name a card", text: $query)
                        .focused($typing)
                        .submitLabel(.done)
                        .onSubmit {
                            if canCreate { create() }
                            else if exact.count == 1, let card = exact.first { pick(card) }
                        }
                        .accessibilityIdentifier("planPicker.title")
                    if canCreate {
                        Button { create() } label: {
                            Label("Create “\(title)”", systemImage: "plus")
                        }
                        .accessibilityIdentifier("planPicker.create")
                    }
                } header: {
                    Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                }
                if !matches.isEmpty {
                    Section("Board cards") {
                        ForEach(matches) { idea in
                            let available = availableIDs.contains(idea.id)
                            Button { pick(idea) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(idea.title)
                                    if !available {
                                        Text("Already in the plan").font(.caption).foregroundStyle(.secondary)
                                    } else if !idea.locationName.isEmpty {
                                        Text(idea.locationName).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(!available)
                            .accessibilityIdentifier("planPicker.card.\(idea.id.uuidString)")
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add to \(basketTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear { typing = true }
        }
    }

    private func pick(_ idea: IdeaItem) {
        guard !committed, availableIDs.contains(idea.id) else { return }
        committed = true
        onPick(idea.id)
    }

    private func create() {
        guard !committed, canCreate else { return }
        committed = true
        onCreate(title)
    }
}
