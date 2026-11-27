import Foundation
import CoreLocation

struct NearbyBackup: Identifiable {
    let idea: IdeaItem
    let meters: Double
    var id: UUID { idea.id }
}

extension EventItem {
    var canChangeForBackup: Bool { !isLocked && eventKitID == nil && schedulePrecision != .exactTime }
}

extension ScheduleViewModel {
    func backupOrigin(for stop: EventItem, board: [IdeaItem]) -> CLLocation? {
        for pin in [stop.coordinate, board.first(where: { $0.id == stop.ideaID })?.coordinate].compactMap({ $0 }) {
            if CLLocationCoordinate2DIsValid(pin.clLocationCoordinate2D) {
                return CLLocation(latitude: pin.latitude, longitude: pin.longitude)
            }
        }
        return nil
    }

    func nearbyBackups(for stop: EventItem, board: [IdeaItem], rainyOnly: Bool) -> [NearbyBackup] {
        guard stop.canChangeForBackup, let origin = backupOrigin(for: stop, board: board) else { return [] }
        let placed = Set(events.map(\.ideaID))
        let sameDay = Set(events(on: stop.startDate).map(\.ideaID))
        let fixed = events.filter { $0.id != stop.id && ($0.isLocked || $0.schedulePrecision == .exactTime) }
        let slot = stop.endDate.timeIntervalSince(stop.startDate)
        return board.compactMap { idea -> NearbyBackup? in
            guard idea.id != stop.ideaID, idea.commitment != .locked, !sameDay.contains(idea.id),
                  idea.allowsMultipleScheduledInstances || !placed.contains(idea.id),
                  let pin = idea.coordinate, CLLocationCoordinate2DIsValid(pin.clLocationCoordinate2D) else { return nil }
            if rainyOnly && !idea.tags.contains(where: {
                ["indoor", "indoors", "rainy day", "rainy-day"].contains($0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            }) { return nil }
            let duration = idea.duration ?? slot
            let end = stop.startDate.addingTimeInterval(duration)
            guard duration.isFinite, duration > 0, duration <= slot,
                  !fixed.contains(where: { $0.startDate < end && stop.startDate < $0.endDate }) else { return nil }
            let meters = origin.distance(from: CLLocation(latitude: pin.latitude, longitude: pin.longitude))
            return meters <= 2_000 ? NearbyBackup(idea: idea, meters: meters) : nil
        }.sorted {
            if $0.meters != $1.meters { return $0.meters < $1.meters }
            let order = $0.idea.title.localizedStandardCompare($1.idea.title)
            return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
        }
    }

    /// Recheck the live board and plan before replacing one rough placement.
    /// A new placement ID prevents old travel estimates following a different destination.
    func useBackup(_ id: UUID, insteadOf stop: EventItem, board: [IdeaItem], rainyOnly: Bool) -> EventItem? {
        guard let index = events.firstIndex(of: stop),
              let idea = nearbyBackups(for: stop, board: board, rainyOnly: rainyOnly).first(where: { $0.id == id })?.idea else { return nil }
        let duration = idea.duration ?? stop.endDate.timeIntervalSince(stop.startDate)
        let new = EventItem(ideaID: idea.id, title: idea.title, startDate: stop.startDate,
                            endDate: stop.startDate.addingTimeInterval(duration), coordinate: idea.coordinate,
                            locationName: idea.locationName, notes: idea.notes, category: idea.category,
                            isMustDo: idea.group == .mustDo || idea.priority == 1,
                            schedulePrecision: stop.schedulePrecision, dayPart: stop.dayPart)
        events[index] = new
        return new
    }

    func undoBackup(_ replacement: EventItem, restoring stop: EventItem, originalIdea: IdeaItem) -> Bool {
        guard originalIdea.id == stop.ideaID, !events.contains(where: { $0.id == stop.id }),
              originalIdea.allowsMultipleScheduledInstances || !hasScheduledInstance(for: stop.ideaID),
              let index = events.firstIndex(of: replacement) else { return false }
        events[index] = stop
        return true
    }
}
