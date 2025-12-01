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

    private let storageKey = "bookmarks"
    private let lastUsedKey = "bookmarks.lastUsed"

    private let defaults: UserDefaults
    private var defaultsObserver: NSObjectProtocol?

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: BookmarkStore.sharedSuiteName)) {
        self.defaults = userDefaults ?? .standard
        loadBookmarksFromDefaults()
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

    func reload() {
        loadBookmarksFromDefaults()
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
    }

    private func persist() {
        let payload = bookmarks.map(\.dictionaryRepresentation)
        defaults.set(payload, forKey: storageKey)
    }
}
