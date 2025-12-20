//
//  Bookmark.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import Foundation
import CoreLocation

struct Bookmark: Identifiable, Equatable {
    let id: UUID
    var name: String
    var coordinate: CLLocationCoordinate2D
    var note: String?
    var createdAt: Date
    var lastUsedAt: Date?

    init(id: UUID = UUID(),
         name: String,
         coordinate: CLLocationCoordinate2D,
         note: String? = nil,
         createdAt: Date = Date(),
         lastUsedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.note = note
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    init?(dictionary: [String: Any]) {
        guard
            let lat = Bookmark.doubleValue(from: dictionary["lat"]),
            let long = Bookmark.doubleValue(from: dictionary["long"]),
            let name = dictionary["name"] as? String
        else {
            return nil
        }

        if let idString = dictionary["id"] as? String, let uuid = UUID(uuidString: idString) {
            self.id = uuid
        } else {
            self.id = UUID()
        }

        self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
        self.name = name
        self.note = dictionary["note"] as? String

        if let createdTimestamp = dictionary["createdAt"] as? Double {
            self.createdAt = Date(timeIntervalSince1970: createdTimestamp)
        } else {
            self.createdAt = Date()
        }

        if let usedTimestamp = dictionary["lastUsedAt"] as? Double {
            self.lastUsedAt = Date(timeIntervalSince1970: usedTimestamp)
        } else {
            self.lastUsedAt = nil
        }
    }

    var dictionaryRepresentation: [String: Any] {
        var representation: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "lat": coordinate.latitude,
            "long": coordinate.longitude,
            "createdAt": createdAt.timeIntervalSince1970
        ]

        if let note {
            representation["note"] = note
        }

        if let lastUsedAt {
            representation["lastUsedAt"] = lastUsedAt.timeIntervalSince1970
        }

        return representation
    }

    var coordinateDescription: String {
        "\(coordinate.latitude), \(coordinate.longitude)"
    }

    var locationPoint: LocationPoint {
        LocationPoint(coordinate: coordinate, label: name, note: note)
    }

    static func == (lhs: Bookmark, rhs: Bookmark) -> Bool {
        lhs.id == rhs.id
    }

    private static func doubleValue(from value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? NSString {
            return string.doubleValue
        }
        return nil
    }
}
