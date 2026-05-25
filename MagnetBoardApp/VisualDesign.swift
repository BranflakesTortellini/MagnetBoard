import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Cute visual design helpers

/// Centralized visual language for the gift/prototype build.
/// These are intentionally soft, friendly colors that still work in light/dark mode.
enum CutePalette {
    static let boardCream = Color(red: 1.00, green: 0.97, blue: 0.91)
    static let boardBlush = Color(red: 1.00, green: 0.91, blue: 0.94)
    static let boardLavender = Color(red: 0.92, green: 0.90, blue: 1.00)
    static let boardMint = Color(red: 0.88, green: 0.98, blue: 0.94)
    static let boardButter = Color(red: 1.00, green: 0.95, blue: 0.74)
    static let boardSky = Color(red: 0.86, green: 0.94, blue: 1.00)

    static let noteShadow = Color.black.opacity(0.16)
    static let liftedShadow = Color.black.opacity(0.28)
}

/// Small wrapper around platform system colors. Keeping these in one place avoids
/// repeated UIKit references inside SwiftUI layout code and gives the app a safe
/// fallback if the files are ever opened in a non-iOS SwiftUI target.
enum SystemPalette {
    static var systemBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemBackground)
        #elseif canImport(AppKit)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color.white
        #endif
    }

    static var groupedBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color.gray.opacity(0.08)
        #endif
    }

    static var secondaryGroupedBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor.secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(NSColor.textBackgroundColor)
        #else
        return Color.gray.opacity(0.12)
        #endif
    }

    static var tertiaryGroupedBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor.tertiarySystemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(NSColor.underPageBackgroundColor)
        #else
        return Color.gray.opacity(0.16)
        #endif
    }
}

extension ActivityCategory {
    var cuteEmoji: String {
        switch self {
        case .unspecified: return "✨"
        case .fullMeal: return "🍝"
        case .snackCoffee: return "☕️"
        case .bar: return "🍸"
        case .shopping: return "🛍️"
        case .exercise: return "🏃‍♀️"
        case .hike: return "🥾"
        case .cultureMuseum: return "🏛️"
        case .outdoorSightseeing: return "🌤️"
        case .errand: return "✅"
        case .appointment: return "📅"
        case .restDowntime: return "🛋️"
        case .nightlife: return "🌙"
        }
    }

    var cuteTint: Color {
        switch self {
        case .unspecified: return .purple
        case .fullMeal: return .orange
        case .snackCoffee: return .brown
        case .bar: return .pink
        case .shopping: return .mint
        case .exercise: return .green
        case .hike: return .teal
        case .cultureMuseum: return .indigo
        case .outdoorSightseeing: return .cyan
        case .errand: return .blue
        case .appointment: return .red
        case .restDowntime: return .gray
        case .nightlife: return .purple
        }
    }

    var cuteWash: Color { cuteTint.opacity(0.14) }
}

extension BoardGroup {
    var cuteEmoji: String {
        switch self {
        case .mustDo: return "⭐️"
        case .ideas: return "💡"
        case .maybe: return "🌷"
        case .needsInfo: return "🔎"
        case .scheduledSoon: return "📌"
        }
    }

    var cuteTint: Color {
        switch self {
        case .mustDo: return .yellow
        case .ideas: return .blue
        case .maybe: return .pink
        case .needsInfo: return .orange
        case .scheduledSoon: return .green
        }
    }

    var cuteBackground: Color { cuteTint.opacity(0.16) }
}

extension CardCommitment {
    var cuteEmoji: String {
        switch self {
        case .loose: return "🌱"
        case .detailed: return "📝"
        case .scheduled: return "📌"
        case .locked: return "🔒"
        }
    }
}

struct CuteBadge: View {
    let emoji: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.14)))
        .foregroundStyle(tint)
    }
}

struct SoftSectionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.thinMaterial)
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
            )
    }
}
