import SwiftUI

/// Tiny, parent-friendly first-run explanation. The goal is not to teach every
/// feature; it is to make the app feel obvious in the first 30 seconds.
struct WelcomeHelpView: View {
    @Binding var showingHelp: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Plan with little magnets")
                            .font(.largeTitle.weight(.bold))
                        Text("Add ideas, move them around, and only turn them into real scheduled plans when you are ready.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    HelpStepCard(number: "1", title: "Add a card", systemImage: "plus.rectangle.on.rectangle", text: "Start vague: ‘cute dinner’, ‘Saturday market’, or ‘something fun near the harbor’ is enough.")
                    HelpStepCard(number: "2", title: "Move it around", systemImage: "hand.draw", text: "Drag cards on the Board like sticky notes. Group by must-do, maybe, needs info, or whatever makes sense.")
                    HelpStepCard(number: "3", title: "Drop into a rough plan", systemImage: "calendar.badge.plus", text: "Use Morning, Afternoon, Evening, Sometime today, or Must happen today. These are rough placements, not scary calendar commitments.")
                    HelpStepCard(number: "4", title: "Make it real only when ready", systemImage: "clock.badge.checkmark", text: "Set an exact time when something is confirmed. Home base and travel help can estimate the day, and exact-time cards can export to Apple Calendar.")
                    HelpStepCard(number: "5", title: "Mistakes are okay", systemImage: "arrow.uturn.backward.circle", text: "Deleted or cleared something? Use Undo at the bottom. Planning should feel safe.")

                    Button {
                        Haptics.success()
                        showingHelp = false
                    } label: {
                        Label("Start planning", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .navigationTitle("How it works")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingHelp = false }
                }
            }
        }
    }
}

struct HelpStepCard: View {
    let number: String
    let title: String
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.16))
                Text(number).font(.headline.weight(.bold)).foregroundStyle(Color.accentColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 5) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SystemPalette.secondaryGroupedBackground))
    }
}
