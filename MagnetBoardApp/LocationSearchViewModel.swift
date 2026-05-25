import Foundation
import MapKit
import CoreLocation
import Combine

/// One MapKit place result the user can attach to a magnet card.
public struct LocationSearchResult: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let subtitle: String
    public let coordinate: CodableCoordinate

    public var displayName: String {
        subtitle.isEmpty ? name : "\(name) — \(subtitle)"
    }
}

/// Lightweight MapKit search helper for turning plain text place names into coordinates.
/// This keeps exact coordinates optional: users can still type a loose neighborhood or
/// use a manual travel estimate, but search makes the map/ETA path easy when they want it.
@MainActor
public final class LocationSearchViewModel: ObservableObject {
    public let objectWillChange = ObservableObjectPublisher()

    @Published public var query: String = ""
    @Published public var results: [LocationSearchResult] = []
    @Published public var isSearching: Bool = false
    @Published public var message: String?
    @Published public var useSearchBias: Bool
    @Published public var searchBiasName: String
    @Published public var searchRadiusKm: Double

    private var searchBiasCoordinate: CodableCoordinate
    private var activeSearch: MKLocalSearch?

    public init(initialQuery: String = "") {
        self.query = initialQuery
        let defaults = UserDefaults.standard
        self.useSearchBias = defaults.object(forKey: PlanningSettingsKeys.useSearchBias) as? Bool ?? true
        self.searchBiasName = defaults.string(forKey: PlanningSettingsKeys.searchBiasName) ?? PlanningSettingsDefaults.searchBiasName
        let latitude = defaults.object(forKey: PlanningSettingsKeys.searchBiasLatitude) as? Double ?? PlanningSettingsDefaults.latitude
        let longitude = defaults.object(forKey: PlanningSettingsKeys.searchBiasLongitude) as? Double ?? PlanningSettingsDefaults.longitude
        self.searchRadiusKm = defaults.object(forKey: PlanningSettingsKeys.searchRadiusKm) as? Double ?? PlanningSettingsDefaults.searchRadiusKm
        self.searchBiasCoordinate = CodableCoordinate(latitude: latitude, longitude: longitude)
    }

    public func search() {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            results = []
            message = "Type a place, address, or neighborhood first."
            return
        }

        activeSearch?.cancel()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = cleaned
        if useSearchBias {
            // No location permission needed. This simply biases results toward the
            // user's chosen home/trip area so common place names resolve usefully.
            request.region = MKCoordinateRegion(
                center: searchBiasCoordinate.clLocationCoordinate2D,
                latitudinalMeters: searchRadiusKm * 1000,
                longitudinalMeters: searchRadiusKm * 1000
            )
        }
        let search = MKLocalSearch(request: request)
        activeSearch = search
        isSearching = true
        message = nil

        search.start { [weak self] response, error in
            Task { @MainActor in
                guard let self else { return }
                self.isSearching = false

                if let error {
                    self.results = []
                    self.message = "Location search failed: \(error.localizedDescription)"
                    return
                }

                let mapItems = response?.mapItems ?? []
                self.results = mapItems.prefix(12).map { item in
                    let name = item.name ?? cleaned
                    let subtitleParts = [
                        item.placemark.thoroughfare,
                        item.placemark.locality,
                        item.placemark.country
                    ].compactMap { $0 }.filter { !$0.isEmpty }
                    let subtitle = subtitleParts.joined(separator: ", ")
                    return LocationSearchResult(
                        name: name,
                        subtitle: subtitle,
                        coordinate: CodableCoordinate(item.placemark.coordinate)
                    )
                }
                self.message = self.results.isEmpty ? "No matching places found. You can still keep a loose location name or use a manual travel estimate." : nil
            }
        }
    }
}
