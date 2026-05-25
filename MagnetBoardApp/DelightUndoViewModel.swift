import SwiftUI
import Foundation
import Combine

/// Lightweight, app-wide undo/toast controller for high-risk actions.
///
/// This is intentionally simple: it keeps the most recent reversible action and
/// shows a friendly banner. Deletions and bulk clears should feel safe, not scary.
@MainActor
public final class DelightUndoViewModel: ObservableObject {
    public let objectWillChange = ObservableObjectPublisher()

    public struct UndoBanner: Identifiable, Equatable {
        public let id = UUID()
        public let title: String
        public let message: String
        public let systemImage: String
    }

    @Published public private(set) var banner: UndoBanner?

    private var undoAction: (() -> Void)?
    private var dismissWorkItem: DispatchWorkItem?

    public init() {}

    public func register(title: String,
                         message: String,
                         systemImage: String = "arrow.uturn.backward",
                         autoDismissSeconds: Double = 7,
                         undo: @escaping () -> Void) {
        dismissWorkItem?.cancel()
        undoAction = undo
        banner = UndoBanner(title: title, message: message, systemImage: systemImage)

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.clear() }
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + max(1.0, autoDismissSeconds), execute: workItem)
    }

    public func undo() {
        let action = undoAction
        clear()
        action?()
    }

    public func clear() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        undoAction = nil
        banner = nil
    }
}

struct UndoBannerView: View {
    @EnvironmentObject var undoViewModel: DelightUndoViewModel

    var body: some View {
        Group {
            if let banner = undoViewModel.banner {
                HStack(spacing: 12) {
                    Image(systemName: banner.systemImage)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.accentColor))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(banner.title)
                            .font(.subheadline.weight(.semibold))
                        Text(banner.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    Button("Undo") {
                        Haptics.success()
                        undoViewModel.undo()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(12)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: undoViewModel.banner)
    }
}

struct ClearBurstView: View {
    let isVisible: Bool

    var body: some View {
        ZStack {
            if isVisible {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.22))
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Text("🔥")
                        Text("✨")
                        Text("💨")
                    }
                    .font(.system(size: 54))
                    .scaleEffect(isVisible ? 1.15 : 0.65)

                    Text("Schedule cleared")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Undo is available below")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(28)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(0.30), radius: 24, x: 0, y: 14)
                .transition(.scale(scale: 0.55).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isVisible)
    }
}
