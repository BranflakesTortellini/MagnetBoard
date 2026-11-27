import MapKit

@MainActor
enum TripMaps {
    private static func item(_ pin: CodableCoordinate) -> MKMapItem {
        MKMapItem(placemark: MKPlacemark(coordinate: pin.clLocationCoordinate2D))
    }

    static func place(_ idea: IdeaItem) {
        guard let pin = idea.coordinate else { return }
        let place = item(pin)
        place.name = idea.title
        place.openInMaps()
    }

    static func directions(from: CodableCoordinate, to: CodableCoordinate, mode: TravelMode) {
        let mapped: String
        switch mode {
        case .transit: mapped = MKLaunchOptionsDirectionsModeTransit
        case .walking, .cycling: mapped = MKLaunchOptionsDirectionsModeWalking
        case .driving: mapped = MKLaunchOptionsDirectionsModeDriving
        }
        MKMapItem.openMaps(with: [item(from), item(to)], launchOptions: [MKLaunchOptionsDirectionsModeKey: mapped])
    }
}
