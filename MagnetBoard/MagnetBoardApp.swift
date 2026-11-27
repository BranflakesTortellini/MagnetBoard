import SwiftUI

/// Entry point for the Magnet Board Planner app.
@main
@MainActor
struct MagnetBoardApp: App {
    @StateObject private var boardViewModel = MagnetBoardApp.makeBoard()
    @StateObject private var scheduleViewModel = MagnetBoardApp.makeSchedule()
    @StateObject private var undoViewModel = DelightUndoViewModel()

    private static func makeBoard() -> BoardViewModel {
        #if DEBUG && targetEnvironment(simulator)
        // A UI test can open a real, isolated board file without touching Documents.
        let environment = ProcessInfo.processInfo.environment
        if let key = environment["MAGNETBOARD_TEST_BOARD"], let id = UUID(uuidString: key) {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("board-\(id).json")
            if !FileManager.default.fileExists(atPath: file.path), let json = environment["MAGNETBOARD_TEST_IDEAS"] {
                try? Data(json.utf8).write(to: file, options: .atomic)
            }
            return BoardViewModel(saveURL: file)
        }
        #endif
        return BoardViewModel()
    }

    private static func makeSchedule() -> ScheduleViewModel {
        #if DEBUG && targetEnvironment(simulator)
        if let key = ProcessInfo.processInfo.environment["MAGNETBOARD_TEST_BOARD"], let id = UUID(uuidString: key) {
            return ScheduleViewModel(saveURL: FileManager.default.temporaryDirectory.appendingPathComponent("plan-\(id).json"))
        }
        #endif
        return ScheduleViewModel()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(boardViewModel)
                .environmentObject(scheduleViewModel)
                .environmentObject(undoViewModel)
        }
    }
}
