//
//  BookmarksViewModel.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import Foundation
import CoreLocation

@MainActor
final class BookmarksViewModel: ObservableObject {
    @Published var editorMode: BookmarkEditorMode?

    private let store: BookmarkStore
    private unowned let mapViewModel: MapViewModel
    private let settings: LocSimSettings

    init(store: BookmarkStore, mapViewModel: MapViewModel, settings: LocSimSettings) {
        self.store = store
        self.mapViewModel = mapViewModel
        self.settings = settings
    }

    func select(_ bookmark: Bookmark) {
        // 如果点击的是当前正在使用的收藏，则停止模拟
        if bookmark.id == store.lastUsedBookmarkID {
            mapViewModel.stopSpoofing()
        } else {
            mapViewModel.focus(on: bookmark, autoStartOverride: settings.autoStartFromBookmarks)
        }
    }

    func deleteBookmarks(at offsets: IndexSet) {
        store.deleteBookmarks(at: offsets)
    }

    func delete(_ bookmark: Bookmark) {
        if let index = store.bookmarks.firstIndex(of: bookmark) {
            store.deleteBookmarks(at: IndexSet(integer: index))
        }
    }

    func moveBookmarks(from source: IndexSet, to destination: Int) {
        store.moveBookmarks(from: source, to: destination)
    }

    func addBookmark() {
        editorMode = .create(nil)
    }

    func edit(_ bookmark: Bookmark) {
        editorMode = .edit(bookmark)
    }

    func dismissEditor() {
        editorMode = nil
    }

    func saveBookmark(name: String, coordinate: CLLocationCoordinate2D, note: String?) {
        guard let editorMode else { return }
        switch editorMode {
        case .create:
            store.addBookmark(name: name, coordinate: coordinate, note: note)
        case .edit(let bookmark):
            var updated = bookmark
            updated.name = name
            updated.coordinate = coordinate
            updated.note = note
            store.updateBookmark(updated)
        }
        self.editorMode = nil
    }
}
