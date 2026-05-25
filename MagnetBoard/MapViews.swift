import SwiftUI
import MapKit

// MARK: - UIKit route map bridge

struct RouteMapView: UIViewRepresentable {
    let polylines: [MKPolyline]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.addOverlays(polylines)
        guard let first = polylines.first else { return }
        var rect = first.boundingMapRect
        for polyline in polylines.dropFirst() {
            rect = rect.union(polyline.boundingMapRect)
        }
        mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24), animated: true)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.lineWidth = 5
                renderer.strokeColor = UIColor.systemBlue
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
