import Foundation

/// Dates in the schedule remain absolute instants. Only the trip clock turns
/// them into calendar days or local times; a phone zone change must not do so.
struct TripClock: Equatable {
    let zone: TimeZone

    var calendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = zone
        return cal
    }

    var name: String {
        (zone.identifier.split(separator: "/").last.map(String.init) ?? zone.identifier)
            .replacingOccurrences(of: "_", with: " ")
    }

    func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, calendar: calendar, timeZone: zone))
    }

    func date(_ day: Date, complete: Bool = false) -> String {
        day.formatted(Date.FormatStyle(date: complete ? .complete : .abbreviated, time: .omitted, calendar: calendar, timeZone: zone))
    }

    /// The trip date selector represents a civil day, unlike a booked stop.
    func keepingDay(_ date: Date, from old: TripClock) -> Date {
        var day = old.calendar.dateComponents([.era, .year, .month, .day], from: date)
        day.hour = 12
        return calendar.date(from: day) ?? date
    }
}
