import Foundation
import OSLog
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Helpers

func formatDuration(_ duration: TimeInterval) -> String {
    let totalMinutes = Int(duration / 60)
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
    if hours > 0 { return "\(hours)h" }
    return "\(minutes)m"
}

func splitCSV(_ text: String) -> [String] {
    text.split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

enum PlannerDragPayload {
    static func trace(_ stage: String) {
        #if DEBUG
        Logger(subsystem: "chrysalis.MagnetBoard", category: "TrayDrop").notice("\(stage, privacy: .public)")
        #endif
    }

    static let idea = UTType(exportedAs: "chrysalis.magnetboard.idea-id", conformingTo: .data)
    static let placement = UTType(exportedAs: "chrysalis.magnetboard.placement-id", conformingTo: .data)

    static func provider(for id: UUID, type: UTType) -> NSItemProvider {
        let provider = NSItemProvider()
        let data = Data(id.uuidString.utf8)
        provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .ownProcess) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    static func loadID(from providers: [NSItemProvider], type: UTType, receive: @escaping @MainActor (UUID) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type.identifier) }) else {
            return false
        }
        provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
            guard let data, let id = UUID(uuidString: String(decoding: data, as: UTF8.self)) else { return }
            Task { @MainActor in receive(id) }
        }
        return true
    }
}

// MARK: - Friendly feedback helpers

@MainActor
enum Haptics {
    static func lightImpact() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func mediumImpact() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func warning() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}
