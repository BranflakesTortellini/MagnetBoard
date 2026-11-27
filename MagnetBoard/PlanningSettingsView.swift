import SwiftUI
import CoreLocation

// MARK: - Planning Settings

/// Centralized keys/defaults for lightweight user preferences.
/// These are intentionally simple @AppStorage/UserDefaults settings rather than
/// another persisted JSON model. They control the planning feel, not the cards.
enum PlanningSettingsKeys {
    static let planName = "planning.planName"
    static let hasHomeBase = "planning.hasHomeBase"
    static let homeBaseName = "planning.homeBaseName"
    static let homeBaseLatitude = "planning.homeBaseLatitude"
    static let homeBaseLongitude = "planning.homeBaseLongitude"

    static let useSearchBias = "planning.useSearchBias"
    static let searchBiasName = "planning.searchBiasName"
    static let searchBiasLatitude = "planning.searchBiasLatitude"
    static let searchBiasLongitude = "planning.searchBiasLongitude"
    static let searchRadiusKm = "planning.searchRadiusKm"

    static let useDayBounds = "planning.useDayBounds"
    static let preferredDayStartHour = "planning.preferredDayStartHour"
    static let preferredDayEndHour = "planning.preferredDayEndHour"

    static let includeHomeStartLeg = "planning.includeHomeStartLeg"
    static let includeHomeEndLeg = "planning.includeHomeEndLeg"

    static let reduceMotion = "delight.reduceMotion"
}

enum PlanningSettingsDefaults {
    static let searchBiasName = "Hamburg"
    static let latitude = 53.5511
    static let longitude = 9.9937
    static let searchRadiusKm = 80.0
    static let preferredDayStartHour = 10.0
    static let preferredDayEndHour = 22.0
}

/// A friendly settings page for the practical things a non-technical user will
/// care about: where plans usually start from, and where location searches should
/// prefer. This replaces the old hard-coded "Search near Hamburg" behavior with
/// an editable planning context.
struct PlanningSettingsView: View {
    @Binding var isPresented: Bool

    @AppStorage(PlanningSettingsKeys.planName) private var planName = ""
    @AppStorage(PlanningSettingsKeys.hasHomeBase) private var hasHomeBase = false
    @AppStorage(PlanningSettingsKeys.homeBaseName) private var homeBaseName = ""
    @AppStorage(PlanningSettingsKeys.homeBaseLatitude) private var homeBaseLatitude = PlanningSettingsDefaults.latitude
    @AppStorage(PlanningSettingsKeys.homeBaseLongitude) private var homeBaseLongitude = PlanningSettingsDefaults.longitude

    @AppStorage(PlanningSettingsKeys.useSearchBias) private var useSearchBias = true
    @AppStorage(PlanningSettingsKeys.searchBiasName) private var searchBiasName = PlanningSettingsDefaults.searchBiasName
    @AppStorage(PlanningSettingsKeys.searchBiasLatitude) private var searchBiasLatitude = PlanningSettingsDefaults.latitude
    @AppStorage(PlanningSettingsKeys.searchBiasLongitude) private var searchBiasLongitude = PlanningSettingsDefaults.longitude
    @AppStorage(PlanningSettingsKeys.searchRadiusKm) private var searchRadiusKm = PlanningSettingsDefaults.searchRadiusKm
    @AppStorage(PlanningSettingsKeys.useDayBounds) private var useDayBounds = false
    @AppStorage(PlanningSettingsKeys.preferredDayStartHour) private var preferredDayStartHour = PlanningSettingsDefaults.preferredDayStartHour
    @AppStorage(PlanningSettingsKeys.preferredDayEndHour) private var preferredDayEndHour = PlanningSettingsDefaults.preferredDayEndHour
    @AppStorage(PlanningSettingsKeys.includeHomeStartLeg) private var includeHomeStartLeg = true
    @AppStorage(PlanningSettingsKeys.includeHomeEndLeg) private var includeHomeEndLeg = true
    @AppStorage(PlanningSettingsKeys.reduceMotion) private var reduceMotion = false

    @State private var showingHomeSearch = false
    @State private var showingSearchAreaSearch = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Plan name", text: $planName)
                    Text("Examples: Weekend with parents, Date night, Hamburg visit. This is just a friendly label so the board feels like a real plan instead of a blank app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Current plan")
                }

                Section {
                    if hasHomeBase {
                        LabeledContent("Home base", value: homeBaseName.isEmpty ? "Selected place" : homeBaseName)
                        Text(String(format: "%.5f, %.5f", homeBaseLatitude, homeBaseLongitude))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No home base set yet.")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingHomeSearch = true
                    } label: {
                        Label(hasHomeBase ? "Change Home Base" : "Choose Home Base", systemImage: "house")
                    }

                    if hasHomeBase {
                        Button {
                            useHomeBaseForSearchArea()
                        } label: {
                            Label("Use home base for searches", systemImage: "mappin.and.ellipse")
                        }

                        Button("Clear home base", role: .destructive) {
                            hasHomeBase = false
                            homeBaseName = ""
                        }
                    }
                } header: {
                    Text("Home base")
                } footer: {
                    Text("Use this for trips, hotel-based days, or ordinary life. Future travel planning can use it as the natural start/end point for a day.")
                }

                Section {
                    Toggle("Prefer searching near a place", isOn: $useSearchBias)
                    if useSearchBias {
                        LabeledContent("Search area", value: searchBiasName.isEmpty ? "Selected area" : searchBiasName)
                        Stepper(value: $searchRadiusKm, in: 5...250, step: 5) {
                            Text("Radius: \(Int(searchRadiusKm)) km")
                        }
                        Button {
                            showingSearchAreaSearch = true
                        } label: {
                            Label("Change Search Area", systemImage: "magnifyingglass.circle")
                        }
                    }
                } header: {
                    Text("Location search")
                } footer: {
                    Text("This only biases search results. It does not require location permission and does not force exact locations on loose cards.")
                }

                Section {
                    Toggle("Start the day from home base", isOn: $includeHomeStartLeg)
                        .disabled(!hasHomeBase)
                    Toggle("End the day back at home base", isOn: $includeHomeEndLeg)
                        .disabled(!hasHomeBase)
                    Text("These make the day summary include Home → first stop and last stop → Home. Turn them off for one-way days or open-ended nights.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Home-base travel")
                }

                Section {
                    Toggle("Use a usual start/end for the day", isOn: $useDayBounds)
                    if useDayBounds {
                        Stepper(value: $preferredDayStartHour, in: 4...15, step: 0.5) {
                            Text("Start around: \(formatHour(preferredDayStartHour))")
                        }
                        Stepper(value: $preferredDayEndHour, in: 12...28, step: 0.5) {
                            Text("Be done around: \(formatHour(preferredDayEndHour))")
                        }
                        if preferredDayEndHour <= preferredDayStartHour {
                            Text("End time should be later than start time.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                } header: {
                    Text("Day shape")
                } footer: {
                    Text("This is not a hard rule. It helps the day summary warn when a plan is getting unrealistic, like starting too early or ending too late.")
                }

                Section {
                    Toggle("Reduce playful motion", isOn: $reduceMotion)
                } header: {
                    Text("Comfort")
                } footer: {
                    Text("Keep this on if the clear animations or bouncy card movement feel distracting. Undo and safety behavior still work either way.")
                }
            }
            .navigationTitle("Planning Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
            }
            .sheet(isPresented: $showingHomeSearch) {
                LocationSearchSheet(initialQuery: homeBaseName.isEmpty ? searchBiasName : homeBaseName) { result in
                    homeBaseName = result.name
                    homeBaseLatitude = result.coordinate.latitude
                    homeBaseLongitude = result.coordinate.longitude
                    hasHomeBase = true
                    // Most people expect the search area to follow their hotel/home
                    // after choosing it, but they can still change it separately.
                    searchBiasName = result.name
                    searchBiasLatitude = result.coordinate.latitude
                    searchBiasLongitude = result.coordinate.longitude
                    useSearchBias = true
                    showingHomeSearch = false
                } onCancel: {
                    showingHomeSearch = false
                }
            }
            .sheet(isPresented: $showingSearchAreaSearch) {
                LocationSearchSheet(initialQuery: searchBiasName) { result in
                    searchBiasName = result.name
                    searchBiasLatitude = result.coordinate.latitude
                    searchBiasLongitude = result.coordinate.longitude
                    useSearchBias = true
                    showingSearchAreaSearch = false
                } onCancel: {
                    showingSearchAreaSearch = false
                }
            }
        }
    }

    private func formatHour(_ hour: Double) -> String {
        let normalized = Int((hour * 60).rounded())
        let dayMinutes = ((normalized % (24 * 60)) + (24 * 60)) % (24 * 60)
        let h = dayMinutes / 60
        let m = dayMinutes % 60
        return String(format: "%02d:%02d", h, m)
    }

    private func useHomeBaseForSearchArea() {
        guard hasHomeBase else { return }
        searchBiasName = homeBaseName.isEmpty ? "Home base" : homeBaseName
        searchBiasLatitude = homeBaseLatitude
        searchBiasLongitude = homeBaseLongitude
        useSearchBias = true
        Haptics.success()
    }
}

struct PlanContextBanner: View {
    @AppStorage(PlanningSettingsKeys.planName) private var planName = ""
    @AppStorage(PlanningSettingsKeys.hasHomeBase) private var hasHomeBase = false
    @AppStorage(PlanningSettingsKeys.homeBaseName) private var homeBaseName = ""
    @AppStorage(PlanningSettingsKeys.useSearchBias) private var useSearchBias = true
    @AppStorage(PlanningSettingsKeys.searchBiasName) private var searchBiasName = PlanningSettingsDefaults.searchBiasName

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: hasHomeBase ? "house.fill" : "mappin.and.ellipse")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                if !planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(planName)
                        .font(.caption.weight(.semibold))
                }
                if hasHomeBase {
                    Text("Planning from \(homeBaseName.isEmpty ? "home base" : homeBaseName)")
                        .font(.caption.weight(.semibold))
                } else if useSearchBias {
                    Text("Searching near \(searchBiasName.isEmpty ? "your chosen area" : searchBiasName)")
                        .font(.caption.weight(.semibold))
                } else {
                    Text("Location searches are worldwide")
                        .font(.caption.weight(.semibold))
                }
                Text("Change this anytime in Settings.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(SystemPalette.secondaryGroupedBackground))
        .accessibilityElement(children: .combine)
    }
}
