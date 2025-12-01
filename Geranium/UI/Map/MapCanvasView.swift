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
        mapView.showsUserLocation = true  // 始终显示真实位置
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
        // 如果正在模拟定位，隐藏真实位置的蓝点
        // 如果不在模拟，显示真实位置
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
            
            // 如果是模拟位置，使用自定义视图模拟系统的用户位置蓝点
            if annotation.title??.contains("模拟位置") == true {
                let identifier = "SimulatedUserLocation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = false
                    
                    // 创建蓝色圆点 + 白色边框（模拟系统的用户位置样式）
                    let size: CGFloat = 20
                    let outerCircle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                    outerCircle.backgroundColor = .white
                    outerCircle.layer.cornerRadius = size / 2
                    outerCircle.layer.shadowColor = UIColor.black.cgColor
                    outerCircle.layer.shadowOpacity = 0.3
                    outerCircle.layer.shadowOffset = CGSize(width: 0, height: 1)
                    outerCircle.layer.shadowRadius = 2
                    
                    let innerSize: CGFloat = 14
                    let innerCircle = UIView(frame: CGRect(
                        x: (size - innerSize) / 2,
                        y: (size - innerSize) / 2,
                        width: innerSize,
                        height: innerSize
                    ))
                    innerCircle.backgroundColor = UIColor.systemBlue
                    innerCircle.layer.cornerRadius = innerSize / 2
                    
                    outerCircle.addSubview(innerCircle)
                    annotationView?.addSubview(outerCircle)
                    annotationView?.frame = CGRect(x: 0, y: 0, width: size, height: size)
                    annotationView?.centerOffset = CGPoint(x: 0, y: 0)
                } else {
                    annotationView?.annotation = annotation
                }
                
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
