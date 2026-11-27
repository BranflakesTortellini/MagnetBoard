import SwiftUI

struct TripGuideView: View {
    let stops: [EventItem]
    let day: Date
    @AppStorage("planning.tripRegion") private var fallback = ""
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private var codes: [String] { TripCalendar.destinations(stops, fallback: fallback) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        TripRegionPicker(selection: $fallback)
                    } label: { LabeledContent("Trip destination", value: TripCalendar.name(fallback)) }
                } footer: { Text("Countries saved with this day’s places take priority. No location tracking.") }
                if let calendar = TripCalendar.bundled {
                    Section(day.formatted(date: .complete, time: .omitted)) {
                        ForEach(codes, id: \.self) { code in
                            let key = TripCalendar.dateKey(day)
                            let dates = calendar.calendars[code]
                            let hasYear = dates?.keys.contains(where: { $0.hasPrefix(String(key.prefix(4)) + "-") }) == true
                            LabeledContent(TripCalendar.name(code), value: dates?[key] ?? (hasYear ? "No holiday listed" : "No calendar coverage"))
                        }
                        if codes.isEmpty { Text("Choose a destination or add a saved place to this day.") }
                    }
                } else { Text("The offline calendars are unavailable.") }
                Section("Local opening tips") {
                    let tips = OpeningTip.search(query, destinations: codes)
                    if tips.isEmpty { Text(query.isEmpty ? "No opening tips saved for this destination." : "No matching opening tips.") }
                    ForEach(tips) { tip in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tip.title).font(.headline)
                            Text(tip.body)
                            Link("Official source", destination: URL(string: tip.url)!)
                        }
                    }
                }
                if let calendar = TripCalendar.bundled {
                    Section("Calendar coverage") {
                        Text("Offline dates: \(String(calendar.firstYear))–\(String(calendar.lastYear)). Country calendars use the default public-holiday list. Regional dates and future announcements can differ. A holiday is not a live closure report.")
                        Link("Calendar data: Holidays (MIT)", destination: URL(string: "https://holidays.readthedocs.io/")!)
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search tips, e.g. Sunday groceries")
            .navigationTitle("Local guide").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct TripRegionPicker: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private static let options = (TripCalendar.bundled?.calendars.keys.map { ($0, TripCalendar.name($0)) } ?? [])
        .sorted { $0.1.localizedStandardCompare($1.1) == .orderedAscending }

    var body: some View {
        List {
            Button("Use saved places only") { selection = ""; dismiss() }
            ForEach(Self.options.filter { query.isEmpty || $0.1.localizedStandardContains(query) || $0.0.localizedStandardContains(query) }, id: \.0) { code, name in
                Button { selection = code; dismiss() } label: {
                    HStack { Text(name); Spacer(); if selection == code { Image(systemName: "checkmark") } }
                }
            }
        }
        .navigationTitle("Trip destination")
        .searchable(text: $query, prompt: "Country or region")
    }
}
