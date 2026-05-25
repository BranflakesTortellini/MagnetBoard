import SwiftUI

/// Entry point for the Magnet Board Planner app.
@main
struct MagnetBoardApp: App {
    @StateObject private var boardViewModel = BoardViewModel()
    @StateObject private var scheduleViewModel = ScheduleViewModel()
    @StateObject private var undoViewModel = DelightUndoViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(boardViewModel)
                .environmentObject(scheduleViewModel)
                .environmentObject(undoViewModel)
        }
    }
}