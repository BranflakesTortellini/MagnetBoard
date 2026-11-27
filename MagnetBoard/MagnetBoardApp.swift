import SwiftUI
#if DEBUG && targetEnvironment(simulator)
import MapKit
#endif

/// Entry point for the Magnet Board Planner app.
@main
@MainActor
struct MagnetBoardApp: App {
    @StateObject private var boardViewModel = MagnetBoardApp.makeBoard()
    @StateObject private var scheduleViewModel = MagnetBoardApp.makeSchedule()
    @StateObject private var undoViewModel = DelightUndoViewModel()

    #if DEBUG && targetEnvironment(simulator)
    private struct TestTransitReply: Decodable {
        let departure: Date
        let from, to: CodableCoordinate
        let seconds: TimeInterval

        func matches(_ item: MKMapItem?, _ pin: CodableCoordinate) -> Bool {
            guard let coord = item?.placemark.coordinate else { return false }
            return abs(coord.latitude - pin.latitude) < 0.00001 && abs(coord.longitude - pin.longitude) < 0.00001
        }
    }
    #endif

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
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("plan-\(id).json")
            if !FileManager.default.fileExists(atPath: file.path), let json = ProcessInfo.processInfo.environment["MAGNETBOARD_TEST_EVENTS"] {
                try? Data(json.utf8).write(to: file, options: .atomic)
            }
            let env = ProcessInfo.processInfo.environment
            let defaults = UserDefaults(suiteName: "MagnetBoard.Test.\(id.uuidString)")
            let device = env["MAGNETBOARD_TEST_DEVICE_ZONE"].flatMap(TimeZone.init(identifier:)) ?? .current
            if let json = env["MAGNETBOARD_TEST_TRANSIT"],
               let reply = try? JSONDecoder.dateDecoder.decode(TestTransitReply.self, from: Data(json.utf8)) {
                // Only replace Apple's remote response. Build the real request
                // from the saved itinerary, checking its pins and absolute time.
                return ScheduleViewModel(saveURL: file, clockDefaults: defaults, deviceZone: device) { request in
                    guard request.transportType == .transit, request.departureDate == reply.departure, request.arrivalDate == nil,
                          reply.matches(request.source, reply.from), reply.matches(request.destination, reply.to)
                    else { throw NSError(domain: "Unexpected test transit request", code: 1) }
                    return reply.seconds
                }
            }
            return ScheduleViewModel(saveURL: file, clockDefaults: defaults, deviceZone: device)
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
