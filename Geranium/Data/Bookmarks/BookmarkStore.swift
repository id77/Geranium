//
//  BookmarkStore.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import Foundation
import Combine
import CoreLocation

@MainActor
final class BookmarkStore: ObservableObject {
    static let sharedSuiteName = "group.live.cclerc.geraniumBookmarks"

    @Published private(set) var bookmarks: [Bookmark] = []
    @Published private(set) var lastUsedBookmarkID: UUID?
    @Published private(set) var canImportLegacyRecords: Bool = false

    private let storageKey = "bookmarks"
    private let lastUsedKey = "bookmarks.lastUsed"
    private let legacyImportKey = "bookmarks.importedMika"

    private let defaults: UserDefaults
    private var defaultsObserver: NSObjectProtocol?

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: BookmarkStore.sharedSuiteName)) {
        self.defaults = userDefaults ?? .standard
        loadBookmarksFromDefaults()
        refreshLegacyImportFlag()
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.loadBookmarksFromDefaults()
        }
    }

    deinit {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    func addBookmark(name: String, coordinate: CLLocationCoordinate2D, note: String? = nil) -> Bookmark {
        let bookmark = Bookmark(name: name, coordinate: coordinate, note: note)
        bookmarks.append(bookmark)
        persist()
        return bookmark
    }

    func updateBookmark(_ bookmark: Bookmark) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[index] = bookmark
        persist()
    }

    func deleteBookmarks(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        persist()
    }

    func moveBookmarks(from source: IndexSet, to destination: Int) {
        bookmarks.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func bookmark(for id: UUID?) -> Bookmark? {
        guard let id else { return nil }
        return bookmarks.first(where: { $0.id == id })
    }

    func markAsLastUsed(_ bookmark: Bookmark?) {
        lastUsedBookmarkID = bookmark?.id
        if let id = bookmark?.id {
            defaults.set(id.uuidString, forKey: lastUsedKey)
        } else {
            defaults.removeObject(forKey: lastUsedKey)
        }

        if let bookmark, let index = bookmarks.firstIndex(of: bookmark) {
            var updated = bookmark
            updated.lastUsedAt = Date()
            bookmarks[index] = updated
        }

        persist()
    }

    @discardableResult
    func importLegacyBookmarks() throws -> Int {
        guard canImportLegacyRecords else { return 0 }
        let imported = try LegacyMikaImporter.loadRecords()
        guard !imported.isEmpty else { return 0 }

        var addedCount = 0
        for record in imported {
            let duplicate = bookmarks.contains(where: { existing in
                abs(existing.coordinate.latitude - record.coordinate.latitude) < 0.00001 &&
                abs(existing.coordinate.longitude - record.coordinate.longitude) < 0.00001 &&
                existing.name == record.name
            })
            if !duplicate {
                bookmarks.append(record)
                addedCount += 1
            }
        }

        defaults.set(true, forKey: legacyImportKey)
        canImportLegacyRecords = false
        persist()
        return addedCount
    }

    private func loadBookmarksFromDefaults() {
        guard let serialized = defaults.array(forKey: storageKey) as? [[String: Any]] else {
            bookmarks = []
            lastUsedBookmarkID = nil
            return
        }

        let mapped = serialized.compactMap(Bookmark.init)
        if mapped != bookmarks {
            bookmarks = mapped
        }

        if
            let identifier = defaults.string(forKey: lastUsedKey),
            let uuid = UUID(uuidString: identifier)
        {
            lastUsedBookmarkID = uuid
        } else {
            lastUsedBookmarkID = nil
        }

        refreshLegacyImportFlag()
    }

    private func persist() {
        let payload = bookmarks.map(\.dictionaryRepresentation)
        defaults.set(payload, forKey: storageKey)
    }

    private func refreshLegacyImportFlag() {
        let alreadyImported = defaults.bool(forKey: legacyImportKey)
        canImportLegacyRecords = !alreadyImported && LegacyMikaImporter.hasRecords
    }
}

private enum LegacyMikaImporter {
    private static let plistPath = "/var/mobile/Library/Preferences/com.mika.LocationSimulation.plist"

    static var hasRecords: Bool {
        guard FileManager.default.fileExists(atPath: plistPath) else { return false }
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dict = plist as? [String: Any],
            let datas = dict["datas"] as? [[String: Any]]
        else {
            return false
        }
        return !datas.isEmpty
    }

    static func loadRecords() throws -> [Bookmark] {
        let url = URL(fileURLWithPath: plistPath)
        let data = try Data(contentsOf: url)
        var format = PropertyListSerialization.PropertyListFormat.xml
        let plist = try PropertyListSerialization.propertyList(from: data, options: [.mutableContainersAndLeaves], format: &format)
        guard let dict = plist as? [String: Any] else { return [] }
        guard let datas = dict["datas"] as? [[String: Any]] else { return [] }

        let bookmarks = datas.compactMap { entry -> Bookmark? in
            guard
                let lat = entry["la"] as? Double,
                let long = entry["lo"] as? Double,
                let name = entry["remark"] as? String
            else { return nil }
            return Bookmark(name: name, coordinate: .init(latitude: lat, longitude: long))
        }
        return bookmarks
    }
}
