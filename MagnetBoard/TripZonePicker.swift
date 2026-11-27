import SwiftUI

struct TripZonePicker: View {
    let current: TripClock
    let places: [String: String]
    let select: (TimeZone) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private static let zones = TimeZone.knownTimeZoneIdentifiers.sorted()
    // Hamburg has no IANA identifier of its own. Place-search suggestions
    // use MapKit's actual zone rather than inferring it from a country.
    private static let aliases = ["Europe/Berlin": "Hamburg Munich Frankfurt Cologne Düsseldorf Dresden"]

    private func matches(_ id: String) -> Bool {
        let text = [id.replacingOccurrences(of: "_", with: " "), Self.aliases[id], places[id]].compactMap { $0 }.joined(separator: " ")
        return query.split(whereSeparator: { $0.isWhitespace }).allSatisfy { text.localizedStandardContains(String($0)) }
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section {
                        LabeledContent("Current zone", value: current.zone.identifier)
                    } footer: {
                        Text("One time zone for this plan. Changing it shows existing bookings in the new zone without moving them.")
                    }
                }
                let saved = places.keys.filter(matches).sorted()
                if !saved.isEmpty {
                    Section("From saved places") {
                        ForEach(saved, id: \.self) { id in option(id, detail: places[id]) }
                    }
                }
                Section("Time zones") {
                    ForEach(Self.zones.filter { places[$0] == nil && matches($0) }, id: \.self) { id in option(id) }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "City or time zone")
            .navigationTitle("Plan time zone").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func option(_ id: String, detail: String? = nil) -> some View {
        Button {
            guard let zone = TimeZone(identifier: id) else { return }
            select(zone)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(id.replacingOccurrences(of: "_", with: " "))
                    if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                if current.zone.identifier == id { Image(systemName: "checkmark") }
            }
        }
        .accessibilityIdentifier("zone.option.\(id)")
    }
}
