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
    var onLongPress: ((CLLocationCoordinate2D) -> Void)?
    var onRegionChange: (CLLocationCoordinate2D) -> Void
    var onUserLocationUpdate: ((CLLocationCoordinate2D) -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .includingAll
        mapView.setRegion(region, animated: false)

        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapRecognizer)

        let longPressRecognizer = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPressRecognizer.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPressRecognizer)

        context.coordinator.mapView = mapView
        context.coordinator.syncAnnotations(selected: selectedCoordinate, active: activeCoordinate)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 根据是否有激活的模拟位置来决定是否显示真实用户位置
        // 如果正在模拟定位，隐藏真实位置的蓝点
        uiView.showsUserLocation = (activeCoordinate == nil)
        
        // 每次外部 region 变化都强制重置 isUserInteracting，确保 setRegion 总能执行
        context.coordinator.isUserInteracting = false
        uiView.setRegion(region, animated: true)
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

            // 如果有激活的模拟位置，显示为"当前位置"样式的蓝色圆点
            if let active {
                let annotation = MKPointAnnotation()
                annotation.title = "模拟位置"
                annotation.coordinate = active
                mapView.addAnnotation(annotation)
            }

            // 如果有选中但未激活的位置，显示为普通标记
            if let selected, selected.latitude != active?.latitude || selected.longitude != active?.longitude {
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

        @objc
        func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            // 只在长按开始时触发，避免重复调用
            guard gesture.state == .began,
                  let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onLongPress?(coordinate)
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
            
            // 如果是模拟位置，使用蓝色圆点样式（类似系统用户位置）
            if annotation.title??.contains("模拟位置") == true {
                let identifier = "SimulatedLocationAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                }
                annotationView?.annotation = annotation
                annotationView?.markerTintColor = UIColor.systemBlue
                annotationView?.glyphImage = UIImage(systemName: "location.fill")
                annotationView?.displayPriority = .required
                return annotationView
            }
            
            // 普通标记（已选择但未激活）
            let identifier = "MapAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            }
            annotationView?.annotation = annotation
            annotationView?.glyphImage = UIImage(systemName: "mappin")
            annotationView?.markerTintColor = UIColor.systemGray
            return annotationView
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            if let coordinate = userLocation.location?.coordinate,
               CLLocationCoordinate2DIsValid(coordinate) {
                parent.onUserLocationUpdate?(coordinate)
            }
        }
    }
}
