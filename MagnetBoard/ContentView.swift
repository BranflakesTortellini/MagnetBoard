import SwiftUI

public struct ContentView: View {
    @EnvironmentObject var boardViewModel: BoardViewModel
    @EnvironmentObject var scheduleViewModel: ScheduleViewModel
    @EnvironmentObject var undoViewModel: DelightUndoViewModel

    @State private var showingAddIdea = false
    @State private var selectedDate = Date()
    @State private var showingHelp = false
    @State private var showingSettings = false
    @AppStorage("welcome.hasSeenMagnetBoardIntro") private var hasSeenIntro = false
    @AppStorage(PlanningSettingsKeys.planName) private var planName = ""

    public init() {}

    public var body: some View {
        TabView {
            NavigationStack {
                FreeBoardView(showingAddIdea: $showingAddIdea)
                    .navigationTitle(planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Magnet Board" : planName)
                    .toolbar { helpToolbar }
            }
            .tabItem { Label("Board", systemImage: "square.grid.2x2") }

            NavigationStack {
                SchedulePlannerView(selectedDate: $selectedDate)
                    .navigationTitle("Plan")
                    .toolbar { helpToolbar }
            }
            .tabItem { Label("Plan", systemImage: "calendar") }
        }
        .sheet(isPresented: $showingAddIdea) {
            AddIdeaView(isPresented: $showingAddIdea)
        }
        .sheet(isPresented: $showingHelp) {
            WelcomeHelpView(showingHelp: $showingHelp)
        }
        .sheet(isPresented: $showingSettings) {
            PlanningSettingsView(isPresented: $showingSettings)
        }
        .onAppear {
            if !hasSeenIntro {
                showingHelp = true
                hasSeenIntro = true
            }
        }
        .safeAreaInset(edge: .bottom) {
            UndoBannerView()
                .environmentObject(undoViewModel)
        }
    }

    @ToolbarContentBuilder
    private var helpToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingHelp = true
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}
