import Foundation
import CoreLocation
import Combine

/// View model for managing loose and detailed cards on the free magnet board.
@MainActor
public final class BoardViewModel: ObservableObject {
    @Published public var ideas: [IdeaItem] = [] {
        didSet { save() }
    }
    @Published private(set) var storageIssue: String?

    private let saveURL: URL?
    private var isLoading = false
    private var canSave = true

    public convenience init() {
        self.init(saveURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("magnet_board_ideas.json"))
    }

    init(saveURL: URL?) {
        self.saveURL = saveURL
        if load() { seedIfNeeded() }
    }

    public func addIdea(title: String,
                        duration: TimeInterval?,
                        cost: Double?,
                        locationName: String,
                        coordinate: CLLocationCoordinate2D?,
                        notes: String,
                        tags: [String],
                        people: [String],
                        category: ActivityCategory,
                        allowsMultipleScheduledInstances: Bool,
                        commitment: CardCommitment,
                        group: BoardGroup,
                        priority: Int) {
        var item = IdeaItem(title: title.trimmingCharacters(in: .whitespacesAndNewlines))
        item.duration = duration
        item.cost = cost
        item.locationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        item.coordinate = coordinate.map(CodableCoordinate.init)
        item.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        item.tags = tags
        item.people = people
        item.category = category
        item.allowsMultipleScheduledInstances = allowsMultipleScheduledInstances
        item.commitment = commitment
        item.group = group
        item.priority = priority
        insertIdea(item)
    }

    @discardableResult
    func insertIdea(_ idea: IdeaItem) -> IdeaItem {
        var item = idea
        item.boardX = Double.random(in: 120...320)
        item.boardY = Double.random(in: 120...520)
        ideas.append(item)
        return item
    }

    public func updateIdea(_ updated: IdeaItem) {
        guard let index = ideas.firstIndex(where: { $0.id == updated.id }) else { return }
        ideas[index] = updated
    }

    public func removeIdea(_ idea: IdeaItem) {
        ideas.removeAll { $0.id == idea.id }
    }

    public func restoreIdea(_ idea: IdeaItem) {
        guard !ideas.contains(where: { $0.id == idea.id }) else { return }
        ideas.append(idea)
    }

    public func restoreIdeas(_ restoredIdeas: [IdeaItem]) {
        for idea in restoredIdeas where !ideas.contains(where: { $0.id == idea.id }) {
            ideas.append(idea)
        }
    }

    public func updatePosition(for ideaID: UUID, x: Double, y: Double) {
        guard let index = ideas.firstIndex(where: { $0.id == ideaID }) else { return }
        var idea = ideas[index]
        idea.boardX = max(70, min(900, x))
        idea.boardY = max(70, min(1400, y))
        ideas[index] = idea
    }

    func moveIdea(_ ideaID: UUID, x: Double, y: Double, group: BoardGroup) {
        guard let index = ideas.firstIndex(where: { $0.id == ideaID }) else { return }
        var idea = ideas[index]
        idea.boardX = x
        idea.boardY = y
        applyGroup(group, to: &idea)
        ideas[index] = idea
    }

    /// Updates the visual group when the user drops a card into a board zone.
    /// This is intentionally lightweight: board zones are soft organization labels,
    /// not scheduling commitments.
    public func updateGroup(for ideaID: UUID, group: BoardGroup) {
        guard let index = ideas.firstIndex(where: { $0.id == ideaID }) else { return }
        var idea = ideas[index]
        applyGroup(group, to: &idea)
        ideas[index] = idea
    }

    private func applyGroup(_ group: BoardGroup, to idea: inout IdeaItem) {
        idea.group = group

        // A card moved into “Needs info” should remain loose unless it was already
        // scheduled/locked. Moving around the board should not silently unschedule it.
        if group == .needsInfo,
           idea.commitment != .scheduled,
           idea.commitment != .locked {
            idea.commitment = .loose
        }
    }

    public func markScheduled(_ ideaID: UUID, locked: Bool = false) {
        guard let index = ideas.firstIndex(where: { $0.id == ideaID }) else { return }
        var idea = ideas[index]
        idea.commitment = locked ? .locked : .scheduled
        idea.group = .scheduledSoon
        if idea != ideas[index] { ideas[index] = idea }
    }

    public func markUnscheduled(_ ideaID: UUID) {
        guard let index = ideas.firstIndex(where: { $0.id == ideaID }) else { return }
        var idea = ideas[index]
        guard idea.commitment == .scheduled || idea.commitment == .locked else { return }
        idea.commitment = idea.missingInfoHints.isEmpty ? .detailed : .loose
        if idea.group == .scheduledSoon { idea.group = .ideas }
        idea.group = inferredGroup(for: idea)
        ideas[index] = idea
    }

    public func duplicate(_ idea: IdeaItem) {
        var copy = idea
        copy.id = UUID()
        copy.title = "\(idea.title) copy"
        copy.boardX += 28
        copy.boardY += 28
        ideas.append(copy)
    }


    /// Adds a small friendly demo set without wiping the user's own cards.
    /// Useful for first-time testing and for showing the sticky-note flow quickly.
    /// Returns the number of cards actually added so the UI can avoid quietly
    /// duplicating the same demo set over and over.
    @discardableResult
    public func addSampleIdeas() -> Int {
        var sampleIdeas: [IdeaItem] = []

        var brunch = IdeaItem(title: "Brunch somewhere cute")
        brunch.duration = 90 * 60
        brunch.category = .fullMeal
        brunch.group = .ideas
        brunch.tags = ["brunch", "easy"]
        brunch.boardX = 340
        brunch.boardY = 150

        var shop = IdeaItem(title: "Wander through little shops")
        shop.duration = 75 * 60
        shop.category = .shopping
        shop.allowsMultipleScheduledInstances = true
        shop.group = .ideas
        shop.tags = ["shopping"]
        shop.boardX = 390
        shop.boardY = 270

        var coffee = IdeaItem(title: "Coffee / snack break")
        coffee.duration = 30 * 60
        coffee.category = .snackCoffee
        coffee.allowsMultipleScheduledInstances = true
        coffee.group = .ideas
        coffee.tags = ["buffer", "snack"]
        coffee.boardX = 570
        coffee.boardY = 170

        var rainy = IdeaItem(title: "Rainy-day backup")
        rainy.duration = 90 * 60
        rainy.category = .cultureMuseum
        rainy.allowsMultipleScheduledInstances = true
        rainy.group = .maybe
        rainy.tags = ["rainy day", "backup"]
        rainy.boardX = 570
        rainy.boardY = 300

        var dateNight = IdeaItem(title: "Date night")
        dateNight.duration = 3 * 60 * 60
        dateNight.category = .nightlife
        dateNight.group = .mustDo
        dateNight.priority = 1
        dateNight.tags = ["date night"]
        dateNight.boardX = 170
        dateNight.boardY = 460

        var cafe = IdeaItem(title: "Cute café")
        cafe.duration = 45 * 60
        cafe.category = .snackCoffee
        cafe.allowsMultipleScheduledInstances = true
        cafe.group = .ideas
        cafe.tags = ["cute", "café"]
        cafe.boardX = 760
        cafe.boardY = 170

        var vintage = IdeaItem(title: "Vintage / thrift shops")
        vintage.duration = 90 * 60
        vintage.category = .shopping
        vintage.allowsMultipleScheduledInstances = true
        vintage.group = .ideas
        vintage.tags = ["shopping", "cute"]
        vintage.boardX = 760
        vintage.boardY = 300

        var walk = IdeaItem(title: "Walk by the water")
        walk.duration = 60 * 60
        walk.category = .outdoorSightseeing
        walk.allowsMultipleScheduledInstances = true
        walk.group = .maybe
        walk.tags = ["walk", "easy"]
        walk.boardX = 430
        walk.boardY = 455

        sampleIdeas = [brunch, shop, coffee, rainy, dateNight, cafe, vintage, walk]
        let existingTitles = Set(ideas.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        let newIdeas = sampleIdeas.filter { !existingTitles.contains($0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
        ideas.append(contentsOf: newIdeas)
        return newIdeas.count
    }

    /// Soft auto-organize: does not pretend to build a real itinerary.
    /// It simply clusters cards visually by current uncertainty/commitment.
    public func tidyBoardByPlanningState() {
        let columns: [(BoardGroup, Double)] = [
            (.mustDo, 150), (.ideas, 350), (.maybe, 550), (.needsInfo, 750), (.scheduledSoon, 350)
        ]
        var rowCounters: [BoardGroup: Int] = [:]

        var tidiedIdeas = ideas
        for index in tidiedIdeas.indices {
            let inferredGroup = inferredGroup(for: tidiedIdeas[index])
            tidiedIdeas[index].group = inferredGroup
            rowCounters[inferredGroup, default: 0] += 1
            let row = rowCounters[inferredGroup, default: 1]
            let x = columns.first(where: { $0.0 == inferredGroup })?.1 ?? 350
            let yBase = inferredGroup == .scheduledSoon ? 760.0 : 150.0
            tidiedIdeas[index].boardX = x
            tidiedIdeas[index].boardY = yBase + Double(row - 1) * 118.0
        }
        ideas = tidiedIdeas
    }

    private func inferredGroup(for idea: IdeaItem) -> BoardGroup {
        if idea.commitment == .scheduled || idea.commitment == .locked { return .scheduledSoon }
        if !idea.missingInfoHints.isEmpty && idea.commitment == .loose { return .needsInfo }
        if idea.priority == 1 { return .mustDo }
        if idea.priority == 3 { return .maybe }
        return idea.group
    }

    /// Returns true only for a new board. A damaged save or a deliberately empty
    /// board must never be overwritten by the starter cards on launch.
    private func load() -> Bool {
        guard let saveURL else {
            canSave = false
            storageIssue = "The board storage folder is unavailable."
            return false
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try Data(contentsOf: saveURL)
            ideas = try JSONDecoder().decode([IdeaItem].self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return true
        } catch {
            canSave = false
            storageIssue = "The saved board could not be opened. The original file was kept. Board changes will not be saved."
            print("Failed to load board ideas: \(error)")
        }
        return false
    }

    private func save() {
        guard !isLoading, canSave, let saveURL else { return }
        do {
            let data = try JSONEncoder.prettyDateEncoder.encode(ideas)
            try data.write(to: saveURL, options: [.atomic])
            if storageIssue != nil { storageIssue = nil }
        } catch {
            storageIssue = "The board could not be saved. Changes are only available for this session."
            print("Failed to save board ideas: \(error)")
        }
    }

    private func seedIfNeeded() {
        guard ideas.isEmpty else { return }
        var market = IdeaItem(title: "Saturday market")
        market.tags = ["food", "morning"]
        market.category = .snackCoffee
        market.allowsMultipleScheduledInstances = true
        market.group = .ideas
        market.boardX = 180
        market.boardY = 150

        var dinner = IdeaItem(title: "Go somewhere fun for dinner")
        dinner.tags = ["food", "friends"]
        dinner.category = .fullMeal
        dinner.allowsMultipleScheduledInstances = false
        dinner.group = .maybe
        dinner.boardX = 430
        dinner.boardY = 230

        var museum = IdeaItem(title: "Miniatur Wunderland")
        museum.duration = 3 * 60 * 60
        museum.locationName = "Speicherstadt"
        museum.tags = ["culture", "rainy day"]
        museum.category = .cultureMuseum
        museum.allowsMultipleScheduledInstances = false
        museum.commitment = .detailed
        museum.priority = 1
        museum.group = .mustDo
        museum.boardX = 210
        museum.boardY = 330

        ideas = [market, dinner, museum]
    }
}

extension JSONEncoder {
    static var prettyDateEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var dateDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
