//
//  LocationModels.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import Foundation
import CoreLocation

struct LocationPoint: Equatable {
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var label: String?
    var note: String?

    init(latitude: Double, longitude: Double, altitude: Double = 0, label: String? = nil, note: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.label = label
        self.note = note
    }

    init(coordinate: CLLocationCoordinate2D, altitude: Double = 0, label: String? = nil, note: String? = nil) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude, altitude: altitude, label: label, note: note)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var coordinateDescription: String {
        String(format: "%.5f, %.5f", latitude, longitude)
    }
}

struct LocationSpoofingSession {
    enum State: Equatable {
        case idle
        case running(LocationPoint)
    }

    var state: State = .idle
    var lastError: LocationSpoofingError?

    var isActive: Bool {
        if case .running = state { return true }
        return false
    }

    var activePoint: LocationPoint? {
        if case let .running(point) = state { return point }
        return nil
    }
}

enum LocationSpoofingError: LocalizedError, Equatable {
    case unableToStart
    case invalidCoordinate

    var errorDescription: String? {
        switch self {
        case .unableToStart:
            return "无法开始模拟，请稍后再试。"
        case .invalidCoordinate:
            return "请先选择一个有效的定位点。"
        }
    }
}
