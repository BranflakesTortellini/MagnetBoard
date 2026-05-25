import Foundation
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

// MARK: - Friendly feedback helpers

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
