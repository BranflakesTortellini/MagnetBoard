import Foundation
import SwiftUI
import UIKit

// MARK: - Shared Card UI

enum MagnetCardMode { case board, compact, dragPreview }

struct MagnetCardView: View {
    let idea: IdeaItem
    let mode: MagnetCardMode

    var body: some View {
        cardBody
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabelText)
            .accessibilityHint(accessibilityHintText)
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 9) {
                Text(idea.category.cuteEmoji)
                    .font(mode == .compact ? .title3 : .title2)
                    .accessibilityHidden(true)

                Text(idea.title)
                    .font(mode == .compact ? .subheadline.weight(.semibold) : .headline)
                    .lineLimit(mode == .compact ? 2 : 3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    CommitmentPill(commitment: idea.commitment)
                    if idea.allowsMultipleScheduledInstances {
                        CuteBadge(emoji: "🔁", text: "Repeat", tint: .secondary)
                    }
                }
            }

            if mode == .board {
                Label("Tap to edit · hold to move", systemImage: "hand.tap")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if mode != .compact {
                knownInfoRows
                missingInfoRow
                tagRow
            } else {
                compactInfoLine
            }
        }
        .padding(12)
        .frame(width: mode == .compact ? 178 : (mode == .dragPreview ? 268 : 218), alignment: .leading)
        .background(cardBackground)
        .overlay(pinDot, alignment: .topTrailing)
        .shadow(color: mode == .dragPreview ? CutePalette.liftedShadow : CutePalette.noteShadow,
                radius: mode == .dragPreview ? 18 : 6,
                x: 0,
                y: mode == .dragPreview ? 12 : 4)
        .scaleEffect(mode == .dragPreview ? 1.08 : 1.0)
        .rotationEffect(mode == .dragPreview ? .degrees(-1.5) : .degrees(0))
    }

    private var accessibilityHintText: String {
        switch mode {
        case .board:
            return "Tap to edit. Touch and hold, then drag to move this sticky note."
        case .compact:
            return "Hold and drag into a day part, or tap to select and then tap a basket."
        case .dragPreview:
            return "Dragging card."
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [idea.category.cuteWash, SystemPalette.systemBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(idea.category.cuteTint.opacity(0.30), lineWidth: 0.8)
            )
    }

    private var pinDot: some View {
        Circle()
            .fill(idea.group.cuteTint.opacity(0.78))
            .frame(width: 11, height: 11)
            .padding(9)
            .shadow(color: idea.group.cuteTint.opacity(0.25), radius: 4, x: 0, y: 2)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var knownInfoRows: some View {
        if let duration = idea.duration {
            Label(formatDuration(duration), systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if let cost = idea.cost {
            Label(String(format: "€%.0f", cost), systemImage: "eurosign.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if !idea.locationName.isEmpty {
            Label(idea.locationName, systemImage: "mappin.and.ellipse")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        if idea.category != .unspecified {
            HStack(spacing: 5) {
                Text(idea.category.cuteEmoji)
                Text(idea.category.label)
            }
            .font(.caption)
            .foregroundStyle(idea.category.cuteTint)
            .lineLimit(1)
        }
        if !idea.people.isEmpty {
            Label(idea.people.joined(separator: ", "), systemImage: "person.2")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder private var missingInfoRow: some View {
        let missing = idea.missingInfoHints
        if !missing.isEmpty {
            Text("Needs: \(missing.joined(separator: ", "))")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.orange)
                .lineLimit(1)
        }
    }

    @ViewBuilder private var tagRow: some View {
        if !idea.tags.isEmpty {
            Text(idea.tags.prefix(3).map { "#\($0)" }.joined(separator: "  "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder private var compactInfoLine: some View {
        let bits = compactBits
        if !bits.isEmpty {
            Text(bits.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    var accessibilityLabelText: String {
        var parts = [idea.title, idea.commitment.label]
        if idea.category != .unspecified { parts.append(idea.category.label) }
        if let duration = idea.duration { parts.append(formatDuration(duration)) }
        if !idea.locationName.isEmpty { parts.append(idea.locationName) }
        if !idea.missingInfoHints.isEmpty { parts.append("Needs \(idea.missingInfoHints.joined(separator: ", "))") }
        return parts.joined(separator: ", ")
    }

    private var compactBits: [String] {
        var bits: [String] = []
        if let duration = idea.duration { bits.append(formatDuration(duration)) }
        if !idea.locationName.isEmpty { bits.append(idea.locationName) }
        if idea.category != .unspecified { bits.append(idea.category.label) }
        if let firstTag = idea.tags.first { bits.append("#\(firstTag)") }
        return bits
    }
}

/// A native button lets the enclosing scroll views handle immediate swipes.
/// Only a stationary hold starts a drag; a normal tap selects or opens the card.
struct MagnetCardControl: UIViewRepresentable {
    enum Surface {
        case tray
        case board(BoardGroup)
    }
    let label: String
    let id: UUID
    let selected: Bool
    var surface: Surface = .tray
    let tap: () -> Void
    let moved: (CGPoint?) -> Void
    let released: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.isAccessibilityElement = true
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapCard), for: .touchUpInside)
        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.hold(_:)))
        hold.minimumPressDuration = 0.35
        button.addGestureRecognizer(hold)
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.control = self
        button.accessibilityLabel = label
        switch surface {
        case .tray:
            button.accessibilityIdentifier = "tray.card.\(id.uuidString)"
            button.accessibilityHint = "Tap to select, then tap a basket. Or hold and drag to a basket."
            button.accessibilityValue = nil
        case .board(let group):
            button.accessibilityIdentifier = "board.card.\(id.uuidString)"
            button.accessibilityHint = "Tap to edit. Hold and drag to move this card."
            button.accessibilityValue = group.title
        }
        button.accessibilityTraits = selected ? [.button, .selected] : [.button]
    }

    @MainActor final class Coordinator: NSObject {
        var control: MagnetCardControl
        private var start: CGPoint?
        init(_ control: MagnetCardControl) { self.control = control }
        @objc func tapCard() { control.tap() }
        @objc func hold(_ gesture: UILongPressGestureRecognizer) {
            let point: CGPoint
            switch control.surface {
            case .tray:
                point = gesture.location(in: gesture.view)
            case .board:
                // The note follows the finger, so measure movement in the stationary window.
                let location = gesture.location(in: gesture.view?.window)
                if gesture.state == .began { start = location }
                let origin = start ?? location
                point = CGPoint(x: location.x - origin.x, y: location.y - origin.y)
            }
            switch gesture.state {
            case .began, .changed: control.moved(point)
            case .ended: start = nil; control.released(point)
            case .cancelled, .failed: start = nil; control.moved(nil)
            default: break
            }
        }
    }
}

struct CommitmentPill: View {
    let commitment: CardCommitment

    var body: some View {
        Text("\(commitment.cuteEmoji) \(commitment.label)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(backgroundColor))
            .foregroundStyle(foregroundColor)
    }

    private var backgroundColor: Color {
        switch commitment {
        case .loose: return Color.gray.opacity(0.18)
        case .detailed: return Color.blue.opacity(0.16)
        case .scheduled: return Color.green.opacity(0.16)
        case .locked: return Color.red.opacity(0.16)
        }
    }

    private var foregroundColor: Color {
        switch commitment {
        case .loose: return .secondary
        case .detailed: return .blue
        case .scheduled: return .green
        case .locked: return .red
        }
    }
}
