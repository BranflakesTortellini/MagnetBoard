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
        ideas.filter {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
                .compare(title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }
    private var canCreate: Bool { !title.isEmpty && exact.isEmpty }
    private var exactAvailable: IdeaItem? {
        let candidates = exact.filter { availableIDs.contains($0.id) }
        return candidates.count == 1 ? candidates[0] : nil
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Find or name a card", text: $query)
                        .focused($typing)
                        .submitLabel(.done)
                        .onSubmit { confirm() }
                        .accessibilityIdentifier("planPicker.title")
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
                ToolbarItem(placement: .confirmationAction) {
                    Button(canCreate ? "Create" : "Add") { confirm() }
                        .accessibilityIdentifier("planPicker.confirm")
                        .disabled(committed || (!canCreate && exactAvailable == nil))
                }
            }
            .onAppear {
                query = ""
                committed = false
                typing = true
            }
        }
    }

    private func pick(_ idea: IdeaItem) {
        guard !committed, availableIDs.contains(idea.id) else { return }
        committed = true
        onPick(idea.id)
    }

    private func confirm() {
        guard !committed else { return }
        if let idea = exactAvailable {
            pick(idea)
        } else if canCreate {
            committed = true
            onCreate(title)
        }
    }
}
