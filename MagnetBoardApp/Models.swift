import Foundation
import CoreLocation
import MapKit

/// Codable wrapper because CLLocationCoordinate2D does not synthesize Codable cleanly.
public struct CodableCoordinate: Codable, Hashable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    public var clLocationCoordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}


/// App-level travel mode. This avoids relying on MapKit enum cases that may not exist
/// on every iOS SDK. In particular, Apple Maps may support bike directions in the app,
/// but MKDirectionsTransportType does not reliably expose a public `.cycling` case.
public enum TravelMode: String, Codable, CaseIterable, Identifiable {
    case driving
    case walking
    case cycling
    case transit

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .driving: return "Drive"
        case .walking: return "Walk"
        case .cycling: return "Bike"
        case .transit: return "Transit"
        }
    }

    public var systemImage: String {
        switch self {
        case .driving: return "car"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .transit: return "tram"
        }
    }

    /// The MapKit transport type actually used for route requests.
    /// Cycling intentionally falls back to walking for now instead of using a possibly
    /// unavailable MapKit `.cycling` case. This keeps the app compiling and honest.
    public var mapKitTransportType: MKDirectionsTransportType {
        switch self {
        case .driving: return .automobile
        case .walking: return .walking
        case .cycling: return .walking
        case .transit: return .transit
        }
    }

    public var estimateNote: String? {
        switch self {
        case .cycling:
            return "Bike mode currently uses walking routes as a safe fallback until native bike ETA support is added."
        default:
            return nil
        }
    }
}


/// Explicit state for the travel leg after a scheduled event.
/// A leg may be calculated with Maps, manually estimated by the user,
/// impossible to calculate because information is missing, or failed.
///
/// The important modeling choice is that manual estimates are first-class,
/// not a fake MapKit result. This lets users plan quickly even when they do
/// not want to share/use exact coordinates or when they simply know the route.
public enum TravelLegStatus: Codable, Equatable {
    case notCalculated
    case calculating
    case missingCoordinates
    case mapEstimate(seconds: TimeInterval, mode: TravelMode, note: String?)
    case manualEstimate(seconds: TimeInterval, note: String?)
    case failed(message: String)

    public var seconds: TimeInterval? {
        switch self {
        case .mapEstimate(let seconds, _, _), .manualEstimate(let seconds, _):
            return seconds
        default:
            return nil
        }
    }

    public var label: String {
        switch self {
        case .notCalculated:
            return "Travel not calculated"
        case .calculating:
            return "Calculating travel…"
        case .missingCoordinates:
            return "Travel unknown — add exact coordinates or use a manual estimate."
        case .mapEstimate(let seconds, let mode, let note):
            let minutes = Int(round(seconds / 60))
            if let note, !note.isEmpty {
                return "Travel to next: \(minutes) min by \(mode.label.lowercased()) (\(note))"
            }
            return "Travel to next: \(minutes) min by \(mode.label.lowercased())"
        case .manualEstimate(let seconds, let note):
            let minutes = Int(round(seconds / 60))
            if let note, !note.isEmpty {
                return "Manual travel estimate: \(minutes) min — \(note)"
            }
            return "Manual travel estimate: \(minutes) min"
        case .failed(let message):
            return "Travel lookup failed — \(message)"
        }
    }

    public var systemImage: String {
        switch self {
        case .notCalculated: return "clock"
        case .calculating: return "hourglass"
        case .missingCoordinates: return "location.slash"
        case .mapEstimate(_, let mode, _): return mode.systemImage
        case .manualEstimate: return "pencil.and.list.clipboard"
        case .failed: return "exclamationmark.triangle"
        }
    }
}

/// How committed/concrete a card is. This is the core product idea:
/// cards can start vague and become more structured only when the user is ready.
public enum CardCommitment: String, Codable, CaseIterable, Identifiable {
    case loose
    case detailed
    case scheduled
    case locked

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .loose: return "Loose"
        case .detailed: return "Detailed"
        case .scheduled: return "In the plan"
        case .locked: return "Locked in"
        }
    }

    public var helpText: String {
        switch self {
        case .loose: return "Just an idea. No pressure to know time, place, or details."
        case .detailed: return "Enough info to help group, compare, or roughly plan."
        case .scheduled: return "Already placed into a plan, but still editable."
        case .locked: return "A fixed commitment the rest of the day should flow around."
        }
    }
}

public enum BoardGroup: String, Codable, CaseIterable, Identifiable {
    case ideas
    case mustDo
    case maybe
    case needsInfo
    case scheduledSoon

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ideas: return "Ideas"
        case .mustDo: return "Must do"
        case .maybe: return "Maybe"
        case .needsInfo: return "Needs info"
        case .scheduledSoon: return "In the plan"
        }
    }
}


/// What kind of activity a card represents. Categories are deliberately broad:
/// they are used for soft planning advice, not for forcing a rigid itinerary.
public enum ActivityCategory: String, Codable, CaseIterable, Identifiable {
    case unspecified
    case fullMeal
    case snackCoffee
    case bar
    case shopping
    case exercise
    case hike
    case cultureMuseum
    case outdoorSightseeing
    case errand
    case appointment
    case restDowntime
    case nightlife

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .unspecified: return "Unspecified"
        case .fullMeal: return "Full meal"
        case .snackCoffee: return "Snack / coffee"
        case .bar: return "Bar"
        case .shopping: return "Shopping"
        case .exercise: return "Exercise"
        case .hike: return "Hike"
        case .cultureMuseum: return "Culture / museum"
        case .outdoorSightseeing: return "Outdoor sightseeing"
        case .errand: return "Errand"
        case .appointment: return "Appointment"
        case .restDowntime: return "Rest / downtime"
        case .nightlife: return "Nightlife"
        }
    }

    public var systemImage: String {
        switch self {
        case .unspecified: return "questionmark.circle"
        case .fullMeal: return "fork.knife"
        case .snackCoffee: return "cup.and.saucer"
        case .bar: return "wineglass"
        case .shopping: return "bag"
        case .exercise: return "figure.run"
        case .hike: return "figure.hiking"
        case .cultureMuseum: return "building.columns"
        case .outdoorSightseeing: return "sun.max"
        case .errand: return "checklist"
        case .appointment: return "calendar.badge.clock"
        case .restDowntime: return "bed.double"
        case .nightlife: return "moon.stars"
        }
    }

    public var isHighEnergy: Bool {
        switch self {
        case .exercise, .hike:
            return true
        default:
            return false
        }
    }

    public var isRepeatFriendlyByDefault: Bool {
        switch self {
        case .bar, .shopping, .snackCoffee, .cultureMuseum, .outdoorSightseeing:
            return true
        default:
            return false
        }
    }
}

/// User-facing, soft sequence rules. These are warnings and suggestions only;
/// they should never silently prevent someone from building the plan they want.
public struct SequenceRuleSettings: Codable, Equatable {
    public var avoidBackToBackFullMeals: Bool = true
    public var avoidBackToBackHighEnergy: Bool = true
    public var allowBarCrawl: Bool = true
    public var allowShoppingRun: Bool = true
    public var snackCoffeeCanBuffer: Bool = true

    public init(avoidBackToBackFullMeals: Bool = true,
                avoidBackToBackHighEnergy: Bool = true,
                allowBarCrawl: Bool = true,
                allowShoppingRun: Bool = true,
                snackCoffeeCanBuffer: Bool = true) {
        self.avoidBackToBackFullMeals = avoidBackToBackFullMeals
        self.avoidBackToBackHighEnergy = avoidBackToBackHighEnergy
        self.allowBarCrawl = allowBarCrawl
        self.allowShoppingRun = allowShoppingRun
        self.snackCoffeeCanBuffer = snackCoffeeCanBuffer
    }
}

/// Represents a draggable activity card on the magnet board.
public struct IdeaItem: Identifiable, Hashable, Codable {
    public var id: UUID = UUID()
    public var title: String

    /// Optional details. Missing values are allowed and expected.
    public var duration: TimeInterval? = nil       // seconds
    public var cost: Double? = nil                 // currency unit, e.g. EUR
    public var locationName: String = ""           // human-readable place/neighborhood
    public var coordinate: CodableCoordinate? = nil // optional map coordinate
    public var notes: String = ""
    public var tags: [String] = []
    public var people: [String] = []
    public var category: ActivityCategory = .unspecified

    /// Whether this card can intentionally create more than one scheduled item.
    /// Leave this off for specific commitments such as reservations, appointments,
    /// one-off museum visits, etc. Turn it on for reusable/generic ideas like
    /// “coffee stop”, “bar stop”, or “shopping”.
    public var allowsMultipleScheduledInstances: Bool = false

    /// Visual/planning metadata.
    public var commitment: CardCommitment = .loose
    public var group: BoardGroup = .ideas
    public var priority: Int = 2                   // 1 high, 2 normal, 3 low
    public var boardX: Double = 180                // free-board canvas position
    public var boardY: Double = 160

    public init(title: String) {
        self.title = title
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, duration, cost, locationName, coordinate, notes, tags, people
        case category, allowsMultipleScheduledInstances, commitment, group, priority, boardX, boardY
    }

    /// Custom decoding preserves compatibility with JSON saved before categories existed.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        cost = try container.decodeIfPresent(Double.self, forKey: .cost)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName) ?? ""
        coordinate = try container.decodeIfPresent(CodableCoordinate.self, forKey: .coordinate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        people = try container.decodeIfPresent([String].self, forKey: .people) ?? []
        category = try container.decodeIfPresent(ActivityCategory.self, forKey: .category) ?? .unspecified
        allowsMultipleScheduledInstances = try container.decodeIfPresent(Bool.self, forKey: .allowsMultipleScheduledInstances) ?? category.isRepeatFriendlyByDefault
        commitment = try container.decodeIfPresent(CardCommitment.self, forKey: .commitment) ?? .loose
        group = try container.decodeIfPresent(BoardGroup.self, forKey: .group) ?? .ideas
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 2
        boardX = try container.decodeIfPresent(Double.self, forKey: .boardX) ?? 180
        boardY = try container.decodeIfPresent(Double.self, forKey: .boardY) ?? 160
    }

    public var hasUsableLocation: Bool {
        coordinate != nil || !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var missingInfoHints: [String] {
        var missing: [String] = []
        if duration == nil { missing.append("duration") }
        if !hasUsableLocation { missing.append("location") }
        if tags.isEmpty { missing.append("tags") }
        return missing
    }
}

/// How precise a scheduled placement is. The app should allow sticky-note style
/// planning before forcing exact calendar times. `startDate` / `endDate` still
/// store a proxy time for sorting, travel ordering, and future promotion.
public enum SchedulePrecision: String, Codable, CaseIterable, Identifiable {
    case dayOnly
    case dayPart
    case exactTime

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .dayOnly: return "Day only"
        case .dayPart: return "Part of day"
        case .exactTime: return "Exact time"
        }
    }

    public var helpText: String {
        switch self {
        case .dayOnly: return "On this day, but not placed into a time yet."
        case .dayPart: return "Roughly morning, afternoon, or evening."
        case .exactTime: return "Specific start/end time. Ready for conflict checks and calendar export."
        }
    }
}

/// Rough planning buckets used when a card is more concrete than 'sometime this day'
/// but not yet a real clock-time calendar event.
public enum DayPart: String, Codable, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }

    public var proxyHour: Int {
        switch self {
        case .morning: return 9
        case .afternoon: return 13
        case .evening: return 18
        }
    }

    public var systemImage: String {
        switch self {
        case .morning: return "sunrise"
        case .afternoon: return "sun.max"
        case .evening: return "moon"
        }
    }
}


/// Result of trying to export an in-app plan to Apple Calendar.
/// Keeping this explicit lets the UI distinguish permission problems from
/// calendar setup problems or ordinary save failures.
public enum CalendarExportResult: Equatable {
    case success
    case notExactTime
    case permissionDenied
    case noDefaultCalendar
    case failed(String)
}

/// Result of trying to schedule a loose card into the plan. This prevents
/// accidental duplicate scheduling while still allowing intentionally repeatable
/// cards such as bar stops, snack breaks, or shopping stops.
public enum SchedulingResult: Equatable {
    case scheduled(EventItem)
    case duplicateNotAllowed(existing: EventItem)
}

/// Represents a concrete scheduled placement derived from an idea card.
/// Calendar export is optional and happens only when the user asks for it.
public struct EventItem: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var ideaID: UUID
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var isLocked: Bool = false
    public var coordinate: CodableCoordinate? = nil
    public var locationName: String = ""
    public var notes: String = ""
    public var eventKitID: String? = nil
    public var invitees: [String] = []
    public var category: ActivityCategory = .unspecified

    /// Marks this planned item as something that should happen on the chosen day.
    /// It may still be rough (day-only/day-part), but Make it flow and summaries
    /// should treat it as important rather than optional.
    public var isMustDo: Bool = false

    /// Precision of this scheduled placement. Day-only and day-part items are still
    /// in-app planning notes, not calendar-ready commitments.
    public var schedulePrecision: SchedulePrecision = .exactTime
    public var dayPart: DayPart? = nil

    /// Optional user-entered estimate for the leg from this scheduled item to
    /// the next scheduled item in the same day. This is intentionally stored on
    /// the preceding event because the leg starts after this event ends.
    public var manualTravelToNextSeconds: TimeInterval? = nil
    public var manualTravelToNextNote: String? = nil

    public init(id: UUID = UUID(),
                ideaID: UUID,
                title: String,
                startDate: Date,
                endDate: Date,
                isLocked: Bool = false,
                coordinate: CodableCoordinate? = nil,
                locationName: String = "",
                notes: String = "",
                eventKitID: String? = nil,
                invitees: [String] = [],
                category: ActivityCategory = .unspecified,
                isMustDo: Bool = false,
                schedulePrecision: SchedulePrecision = .exactTime,
                dayPart: DayPart? = nil,
                manualTravelToNextSeconds: TimeInterval? = nil,
                manualTravelToNextNote: String? = nil) {
        self.id = id
        self.ideaID = ideaID
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isLocked = isLocked
        self.coordinate = coordinate
        self.locationName = locationName
        self.notes = notes
        self.eventKitID = eventKitID
        self.invitees = invitees
        self.category = category
        self.isMustDo = isMustDo
        self.schedulePrecision = schedulePrecision
        self.dayPart = dayPart
        self.manualTravelToNextSeconds = manualTravelToNextSeconds
        self.manualTravelToNextNote = manualTravelToNextNote
    }

    private enum CodingKeys: String, CodingKey {
        case id, ideaID, title, startDate, endDate, isLocked, coordinate, locationName
        case notes, eventKitID, invitees, category, isMustDo, schedulePrecision, dayPart, manualTravelToNextSeconds, manualTravelToNextNote
    }

    /// Custom decoding preserves compatibility with JSON saved before categories
    /// and manual travel estimates existed.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        ideaID = try container.decode(UUID.self, forKey: .ideaID)
        title = try container.decode(String.self, forKey: .title)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        coordinate = try container.decodeIfPresent(CodableCoordinate.self, forKey: .coordinate)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        eventKitID = try container.decodeIfPresent(String.self, forKey: .eventKitID)
        invitees = try container.decodeIfPresent([String].self, forKey: .invitees) ?? []
        category = try container.decodeIfPresent(ActivityCategory.self, forKey: .category) ?? .unspecified
        isMustDo = try container.decodeIfPresent(Bool.self, forKey: .isMustDo) ?? false
        schedulePrecision = try container.decodeIfPresent(SchedulePrecision.self, forKey: .schedulePrecision) ?? .exactTime
        dayPart = try container.decodeIfPresent(DayPart.self, forKey: .dayPart)
        manualTravelToNextSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .manualTravelToNextSeconds)
        manualTravelToNextNote = try container.decodeIfPresent(String.self, forKey: .manualTravelToNextNote)
    }
}
