import Foundation

struct TripCalendar: Decodable {
    let firstYear: Int
    let lastYear: Int
    let calendars: [String: [String: String]]

    static let bundled: TripCalendar? = {
        guard let url = Bundle.main.url(forResource: "TravelHolidays", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }()

    static func dateKey(_ day: Date, zone: TimeZone = .current) -> String {
        // The picker represents a civil day (not a UTC instant or a week-year).
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let parts = cal.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    static func destinations(_ stops: [EventItem], fallback: String) -> [String] {
        let countries = Set(stops.compactMap { $0.coordinate?.countryCode?.uppercased() })
        if countries.isEmpty { return fallback.isEmpty ? [] : [fallback] }
        return countries.map { fallback.hasPrefix($0 + "-") ? fallback : $0 }.sorted()
    }

    static let regions = ["BB":"Brandenburg", "BE":"Berlin", "BW":"Baden-Württemberg", "BY":"Bavaria",
                          "HB":"Bremen", "HE":"Hesse", "HH":"Hamburg", "MV":"Mecklenburg-Western Pomerania",
                          "NI":"Lower Saxony", "NW":"North Rhine-Westphalia", "RP":"Rhineland-Palatinate",
                          "SH":"Schleswig-Holstein", "SL":"Saarland", "SN":"Saxony", "ST":"Saxony-Anhalt",
                          "TH":"Thuringia", "ENG":"England", "NIR":"Northern Ireland", "SCT":"Scotland", "WLS":"Wales"]
    static func name(_ code: String) -> String {
        let parts = code.split(separator: "-", maxSplits: 1).map(String.init)
        guard let country = parts.first else { return "Choose a destination" }
        let name = Locale.current.localizedString(forRegionCode: country) ?? country
        return parts.count == 1 ? name : "\(name) · \(regions[parts[1]] ?? parts[1])"
    }

    func notices(day: Date, codes: [String], zone: TimeZone = .current) -> [String] {
        let key = Self.dateKey(day, zone: zone)
        return codes.compactMap { code in calendars[code]?[key].map { "\($0) · \(Self.name(code))" } }
    }
}

struct OpeningTip: Identifiable {
    let country: String
    let title: String
    let body: String
    let keywords: String
    let url: String
    var id: String { url }

    static let all = [
        OpeningTip(country: "DE", title: "Sunday groceries in Germany",
                   body: "Plan your supermarket run for Saturday. Most ordinary shops close on Sundays and public holidays. Some station and airport shops are exceptions; check the individual branch.",
                   keywords: "food shopping grocery groceries supermarket opening hours Sunday Germany Deutschland",
                   url: "https://www.germany.travel/media/redaktion/trade_relaunch/news_services/Germany_Resource_Guide_2022_2023.pdf"),
        OpeningTip(country: "DE-HH", title: "Hamburg shopping Sundays",
                   body: "An advertised shopping Sunday can apply only near a particular event. Don't assume all districts or supermarkets will open.",
                   keywords: "Hamburg Sunday groceries Germany opening shops exceptions verkaufsoffen",
                   url: "https://www.hamburg.de/freizeit/shopping/verkaufsoffener-sonntag-hamburg-321768"),
        OpeningTip(country: "GB", title: "Sunday shopping in England and Wales",
                   body: "Large shops usually have shorter Sunday hours. Small shops can open longer. Scotland has different rules, so don't apply this tip across the UK.",
                   keywords: "groceries supermarket England Wales London United Kingdom UK Britain trading hours",
                   url: "https://www.gov.uk/trading-hours-for-retailers-the-law"),
        OpeningTip(country: "FR", title: "Sunday groceries in France",
                   body: "A morning shop is a safer bet than a late one. Food retailers can generally open until 1 pm on Sunday; exceptions and local rules can change the hours.",
                   keywords: "supermarket groceries food Paris France Sunday lunch shops",
                   url: "https://entreprendre.service-public.gouv.fr/vosdroits/F22606"),
        OpeningTip(country: "CH", title: "Sunday shops in Switzerland",
                   body: "Many stores close on Sundays. Shops at major train stations, airports and petrol stations are useful alternatives; check the branch before travelling.",
                   keywords: "groceries weekend supermarket Sunday Zurich Geneva Swiss shopping",
                   url: "https://www.myswitzerland.com/en-us/planning/about-switzerland/general-facts/money-and-shopping/shopping/")
    ]

    static func search(_ query: String, destinations: [String]) -> [OpeningTip] {
        let terms = query.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if terms.isEmpty {
            return all.filter { tip in destinations.contains { $0 == tip.country || $0.hasPrefix(tip.country + "-") } }
        }
        return all.filter { tip in
            let text = "\(TripCalendar.name(tip.country)) \(tip.title) \(tip.body) \(tip.keywords)"
            return terms.allSatisfy { text.localizedStandardContains($0) }
        }
    }
}
