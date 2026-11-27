import SwiftUI

struct PlanBSheet: View {
    let stop: EventItem
    let onPick: (UUID, Bool) -> Void
    let onSkip: () -> Void
    @EnvironmentObject private var board: BoardViewModel
    @EnvironmentObject private var schedule: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var indoorsOnly = false

    var body: some View {
        NavigationStack {
            List {
                let hasPin = schedule.backupOrigin(for: stop, board: board.ideas) != nil
                if hasPin {
                    Section {
                        Picker("Show saved ideas", selection: $indoorsOnly) {
                            Text("All nearby").tag(false)
                            Text("Indoors").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("backup.scope")
                    }
                    Section {
                        let ideas = schedule.nearbyBackups(for: stop, board: board.ideas, indoorsOnly: indoorsOnly)
                        if ideas.isEmpty {
                            Text(indoorsOnly ? "No nearby ideas marked Indoors." : "No available saved ideas with a pin within 2 km that fit this stop.")
                        }
                        ForEach(ideas) { result in
                          HStack {
                            Button {
                                onPick(result.id, indoorsOnly)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.idea.title)
                                    let distance = Measurement(value: result.meters, unit: UnitLength.meters)
                                    let duration = result.idea.duration.map { formatDuration($0) } ?? "Duration not set"
                                    Text("\(distance.formatted(.measurement(width: .abbreviated, usage: .road))) · \(duration)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityIdentifier("backup.choice.\(result.id)")
                            Spacer()
                            Button { TripMaps.place(result.idea) } label: {
                                Image(systemName: "map").frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("View \(result.idea.title) in Maps")
                            .accessibilityIdentifier("backup.map.\(result.id)")
                          }
                          .buttonStyle(.borderless)
                        }
                    } header: {
                        Text("Replace \(stop.title) with")
                    } footer: {
                        Text("From your board, closest first. Distances are straight-line from this stop, not walking routes. Opening hours aren't checked.")
                    }
                } else {
                    Section(stop.title) {
                        Text("No saved pin for this stop. Select a place on its board card to find nearby ideas.")
                    }
                }
                Section {
                    Button("Skip this stop", action: onSkip).accessibilityIdentifier("backup.skip")
                } footer: { Text("The original idea stays on your board.") }
            }
            .navigationTitle("Plan B")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
