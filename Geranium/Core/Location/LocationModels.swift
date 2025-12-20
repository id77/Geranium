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
    var needsCoordinateTransform: Bool

    init(latitude: Double, longitude: Double, altitude: Double = 0, label: String? = nil, note: String? = nil, needsCoordinateTransform: Bool = true) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.label = label
        self.note = note
        self.needsCoordinateTransform = needsCoordinateTransform
    }

    init(coordinate: CLLocationCoordinate2D, altitude: Double = 0, label: String? = nil, note: String? = nil, needsCoordinateTransform: Bool = true) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude, altitude: altitude, label: label, note: note, needsCoordinateTransform: needsCoordinateTransform)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var coordinateDescription: String {
        // 动态显示所有有效小数位，不做截断
        "\(latitude), \(longitude)"
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
