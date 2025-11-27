//
//  MapCanvasView.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import SwiftUI
import MapKit
import UIKit

struct MapCanvasView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var selectedCoordinate: CLLocationCoordinate2D?
    var activeCoordinate: CLLocationCoordinate2D?
    var onTap: (CLLocationCoordinate2D) -> Void
    var onRegionChange: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .includingAll
        mapView.setRegion(region, animated: false)

        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapRecognizer)
        context.coordinator.mapView = mapView
        context.coordinator.syncAnnotations(selected: selectedCoordinate, active: activeCoordinate)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        if !context.coordinator.isUserInteracting {
            uiView.setRegion(region, animated: true)
        }
        context.coordinator.syncAnnotations(selected: selectedCoordinate, active: activeCoordinate)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapCanvasView
        weak var mapView: MKMapView?
        var isUserInteracting = false

        init(parent: MapCanvasView) {
            self.parent = parent
        }

        func syncAnnotations(selected: CLLocationCoordinate2D?, active: CLLocationCoordinate2D?) {
            guard let mapView else { return }
            mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })

            if let active {
                let annotation = MKPointAnnotation()
                annotation.title = "正在模拟"
                annotation.coordinate = active
                mapView.addAnnotation(annotation)
            }

            if let selected {
                let annotation = MKPointAnnotation()
                annotation.title = "已选择"
                annotation.coordinate = selected
                mapView.addAnnotation(annotation)
            }
        }

        @objc
        func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onTap(coordinate)
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            isUserInteracting = true
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            isUserInteracting = false
            parent.region = mapView.region
            parent.onRegionChange(mapView.centerCoordinate)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let identifier = "MapAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            }
            annotationView?.annotation = annotation
            annotationView?.glyphImage = UIImage(systemName: "mappin")
            if annotation.title??.contains("正在模拟") == true {
                annotationView?.markerTintColor = UIColor.systemGreen
            } else {
                annotationView?.markerTintColor = UIColor.systemBlue
            }
            return annotationView
        }
    }
}
