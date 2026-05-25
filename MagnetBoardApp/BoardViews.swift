import SwiftUI
import MapKit

// MARK: - Free Board Mode

struct FreeBoardView: View {
    @EnvironmentObject var boardViewModel: BoardViewModel
    @Binding var showingAddIdea: Bool
    @State private var selectedIdea: IdeaItem?
    @State private var dragStartPositions: [UUID: CGPoint] = [:]
    @State private var liftedIdeaID: UUID?
    @State private var boardNotice: String?
    @AppStorage(PlanningSettingsKeys.reduceMotion) private var reduceMotion = false

    private let canvasSize = CGSize(width: 960, height: 1500)

    var body: some View {
        VStack(spacing: 0) {
            BoardHelpBanner()
            BoardQuickActions(
                onAdd: { showingAddIdea = true },
                onTidy: { boardViewModel.tidyBoardByPlanningState() },
                onSample: {
                    let added = boardViewModel.addSampleIdeas()
                    boardNotice = added == 0 ? "The sample cards are already on the board." : "Added \(added) sample card\(added == 1 ? "" : "s")."
                }
            )

            if boardViewModel.ideas.isEmpty {
                EmptyBoardPrompt(
                    onAdd: { showingAddIdea = true },
                    onSample: {
                        let added = boardViewModel.addSampleIdeas()
                        boardNotice = added == 0 ? "The sample cards are already on the board." : "Added \(added) sample card\(added == 1 ? "" : "s")."
                    }
                )
            }

            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    BoardBackground(size: canvasSize)

                    ForEach(boardViewModel.ideas) { idea in
                        MagnetCardView(idea: idea, mode: .board)
                            .position(x: idea.boardX, y: idea.boardY)
                            .scaleEffect(!reduceMotion && liftedIdeaID == idea.id ? 1.05 : 1.0)
                            .shadow(color: Color.black.opacity(liftedIdeaID == idea.id ? 0.24 : 0.10), radius: liftedIdeaID == idea.id ? 18 : 4, x: 0, y: liftedIdeaID == idea.id ? 14 : 3)
                            .rotationEffect(!reduceMotion && liftedIdeaID == idea.id ? .degrees(-1.2) : .degrees(0))
                            .zIndex(liftedIdeaID == idea.id ? 10 : 0)
                            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.78), value: liftedIdeaID)
                            .gesture(boardMoveGesture(for: idea))
                            .onTapGesture {
                                selectedIdea = idea
                            }
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    boardViewModel.tidyBoardByPlanningState()
                } label: {
                    Label("Tidy", systemImage: "wand.and.stars")
                }
                Button {
                    showingAddIdea = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $selectedIdea) { idea in
            IdeaDetailView(idea: idea)
        }
        .alert("Board", isPresented: Binding(
            get: { boardNotice != nil },
            set: { if !$0 { boardNotice = nil } }
        )) {
            Button("OK", role: .cancel) { boardNotice = nil }
        } message: {
            Text(boardNotice ?? "")
        }
    }

    /// iPhone-friendly board movement: tap edits; touch-and-hold lifts the
    /// sticky note; then dragging moves it. This avoids most accidental moves
    /// while scrolling the two-axis board.
    private func boardMoveGesture(for idea: IdeaItem) -> some Gesture {
        LongPressGesture(minimumDuration: 0.16)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first(true):
                    beginMoving(idea)
                case .second(true, let drag?):
                    beginMoving(idea)
                    move(idea, translation: drag.translation)
                default:
                    break
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, let drag?):
                    finishMoving(idea, translation: drag.translation)
                default:
                    dragStartPositions[idea.id] = nil
                    liftedIdeaID = nil
                }
            }
    }

    private func beginMoving(_ idea: IdeaItem) {
        if liftedIdeaID != idea.id { Haptics.lightImpact() }
        liftedIdeaID = idea.id
        if dragStartPositions[idea.id] == nil {
            dragStartPositions[idea.id] = CGPoint(x: idea.boardX, y: idea.boardY)
        }
    }

    private func move(_ idea: IdeaItem, translation: CGSize) {
        let start = dragStartPositions[idea.id] ?? CGPoint(x: idea.boardX, y: idea.boardY)
        boardViewModel.updatePosition(
            for: idea.id,
            x: start.x + translation.width,
            y: start.y + translation.height
        )
    }

    private func finishMoving(_ idea: IdeaItem, translation: CGSize) {
        let start = dragStartPositions[idea.id] ?? CGPoint(x: idea.boardX, y: idea.boardY)
        let finalPosition = CGPoint(
            x: start.x + translation.width,
            y: start.y + translation.height
        )
        boardViewModel.updatePosition(for: idea.id, x: finalPosition.x, y: finalPosition.y)
        boardViewModel.updateGroup(for: idea.id, group: groupForBoardPosition(finalPosition))
        Haptics.success()
        dragStartPositions[idea.id] = nil
        liftedIdeaID = nil
    }

    /// Converts a physical board drop position into a soft board group.
    /// The zones intentionally match the visible board labels, but they remain
    /// forgiving so the board feels like sticky notes, not a spreadsheet grid.
    private func groupForBoardPosition(_ point: CGPoint) -> BoardGroup {
        if point.y >= 650 { return .scheduledSoon }
        if point.x < 270 { return .mustDo }
        if point.x < 510 { return .ideas }
        if point.x < 750 { return .maybe }
        return .needsInfo
    }
}

struct BoardHelpBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Make cute little cards first. Turn them into a real plan only when you’re ready.")
                .font(.subheadline.weight(.semibold))
            Text("A card can be just an idea, a must-do, a maybe, or a real commitment. Details are optional until they help.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            LinearGradient(
                colors: [CutePalette.boardBlush.opacity(0.55), CutePalette.boardLavender.opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}


struct EmptyBoardPrompt: View {
    let onAdd: () -> Void
    let onSample: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
            Text("What kind of day are you making?")
                .font(.headline)
            Text("Start from a tiny cute board, then rename cards into your real places and plans.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("Blank card") { onAdd() }
                    .buttonStyle(.borderedProminent)
                Button("Cute starter board") { onSample() }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(CutePalette.boardCream.opacity(0.45))
    }
}

struct BoardQuickActions: View {
    let onAdd: () -> Void
    let onTidy: () -> Void
    let onSample: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.lightImpact()
                onAdd()
            } label: {
                Label("New idea", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                Haptics.success()
                onTidy()
            } label: {
                Label("Tidy", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                Haptics.success()
                onSample()
            } label: {
                Label("Starter", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(CutePalette.boardCream.opacity(0.45))
    }
}

struct BoardBackground: View {
    let size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [CutePalette.boardCream, CutePalette.boardBlush.opacity(0.50), CutePalette.boardLavender.opacity(0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            BoardDoodle(text: "♡", x: 70, y: 185, size: 34, opacity: 0.20)
            BoardDoodle(text: "✦", x: 890, y: 170, size: 40, opacity: 0.18)
            BoardDoodle(text: "✿", x: 690, y: 560, size: 42, opacity: 0.16)
            BoardDoodle(text: "☁︎", x: 120, y: 820, size: 38, opacity: 0.14)
            BoardDoodle(text: "♡", x: 820, y: 1050, size: 44, opacity: 0.14)

            GroupLabel(group: .mustDo, subtitle: "High priority", x: 30, y: 34, width: 230)
            GroupLabel(group: .ideas, subtitle: "Loose magnets", x: 270, y: 34, width: 230)
            GroupLabel(group: .maybe, subtitle: "Nice if it fits", x: 510, y: 34, width: 230)
            GroupLabel(group: .needsInfo, subtitle: "Add time/place/details", x: 750, y: 34, width: 180)
            GroupLabel(group: .scheduledSoon, subtitle: "Already dropped into a day", x: 270, y: 700, width: 340)
        }
        .frame(width: size.width, height: size.height)
    }
}

struct GroupLabel: View {
    let group: BoardGroup
    let subtitle: String
    let x: Double
    let y: Double
    let width: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(group.cuteEmoji)
                Text(group.title).font(.headline)
            }
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(group.cuteBackground)
                .shadow(color: group.cuteTint.opacity(0.12), radius: 8, x: 0, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(group.cuteTint.opacity(0.30), lineWidth: 0.8))
        .position(x: x + width / 2, y: y + 45)
    }
}

struct BoardDoodle: View {
    let text: String
    let x: Double
    let y: Double
    let size: Double
    let opacity: Double

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(Color.accentColor.opacity(opacity))
            .rotationEffect(.degrees(-8))
            .position(x: x, y: y)
            .accessibilityHidden(true)
    }
}
