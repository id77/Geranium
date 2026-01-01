//
//  LocationSpoofingEngine.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import Foundation
import CoreLocation

@MainActor
final class LocationSpoofingEngine: ObservableObject {
    @Published private(set) var session = LocationSpoofingSession()

    func startSpoofing(point: LocationPoint) {
        // 转换坐标用于GPS模拟（如果需要）
        // Only apply coordinate transformation if the point needs it (e.g., from Chinese maps in GCJ-02 format)
        // Skip transformation for coordinates from international maps (Apple Maps, Google Maps) which are already in WGS-84
        let simulationCoordinate = point.needsCoordinateTransform ? CoordTransform.gcj02ToWgs84(point.coordinate) : point.coordinate

        // 使用转换后的坐标进行GPS模拟
        let location = CLLocation(coordinate: simulationCoordinate,
                                  altitude: point.altitude,
                                  horizontalAccuracy: 5,
                                  verticalAccuracy: 5,
                                  timestamp: Date())

        LocSimManager.startLocSim(location: location, point: point)

        // 但在session中保存原始坐标（用于地图显示标记）
        // 这样地图标记会显示在用户点击的位置，而不是转换后的位置
        session.state = .running(point)
        session.lastError = nil
    }

    func stopSpoofing(locationModel: LocationModel? = nil) {
        LocSimManager.stopLocSim(locationModel: locationModel)
        session.state = .idle
    }
    
    /// 恢复持久化的模拟状态
    func restoreSpoofingState(_ point: LocationPoint?) {
        if let point = point {
            session.state = .running(point)
        } else {
            session.state = .idle
        }
    }

    func recordError(_ error: LocationSpoofingError) {
        session.lastError = error
    }
}
