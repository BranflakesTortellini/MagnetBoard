import SwiftUI

struct MovePlacementSheet: View {
    @Environment(\.calendar) private var calendar
    let event: EventItem
    let move: (Date, DayPart?) -> Void
    @State private var date: Date
    @Environment(\.dismiss) private var dismiss

    init(event: EventItem, move: @escaping (Date, DayPart?) -> Void) {
        self.event = event
        self.move = move
        _date = State(initialValue: event.startDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(event.title) {
                    DatePicker("Day", selection: $date, displayedComponents: .date)
                    Button("Tomorrow") {
                        date = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? date
                    }
                }
                Section("Move to") {
                    Button("Any time") { move(date, nil) }
                    ForEach(DayPart.allCases) { part in
                        Button { move(date, part) } label: { Label(part.label, systemImage: part.systemImage) }
                            .accessibilityIdentifier("move.\(part.rawValue)")
                    }
                }
            }
            .navigationTitle("Move card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
