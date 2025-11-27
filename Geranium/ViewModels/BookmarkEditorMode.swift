//
//  BookmarkEditorMode.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import Foundation

enum BookmarkEditorMode: Equatable {
    case create(LocationPoint?)
    case edit(Bookmark)

    var seedLocation: LocationPoint? {
        switch self {
        case .create(let location):
            return location
        case .edit(let bookmark):
            return bookmark.locationPoint
        }
    }

    var existingBookmark: Bookmark? {
        if case let .edit(bookmark) = self {
            return bookmark
        }
        return nil
    }
}

extension BookmarkEditorMode: Identifiable {
    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let bookmark):
            return "edit-\(bookmark.id.uuidString)"
        }
    }
}
