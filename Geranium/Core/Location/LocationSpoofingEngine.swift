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
        let correctedCoordinate = CoordTransform.gcj02ToWgs84(point.coordinate)
        let correctedPoint = LocationPoint(coordinate: correctedCoordinate, altitude: point.altitude, label: point.label, note: point.note)

        let location = CLLocation(coordinate: correctedPoint.coordinate,
                                  altitude: correctedPoint.altitude,
                                  horizontalAccuracy: 5,
                                  verticalAccuracy: 5,
                                  timestamp: Date())

        LocSimManager.startLocSim(location: location)
        session.state = .running(correctedPoint)
        session.lastError = nil
    }

    func stopSpoofing() {
        LocSimManager.stopLocSim()
        session.state = .idle
    }

    func recordError(_ error: LocationSpoofingError) {
        session.lastError = error
    }
}
