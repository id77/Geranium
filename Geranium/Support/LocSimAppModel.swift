//
//  LocSimAppModel.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import Foundation

@MainActor
final class LocSimAppModel: ObservableObject {
    let settings: LocSimSettings
    let bookmarkStore: BookmarkStore
    let mapViewModel: MapViewModel
    let bookmarksViewModel: BookmarksViewModel
    let settingsViewModel: SettingsViewModel

    init() {
        let settings = LocSimSettings()
        let store = BookmarkStore()
        let engine = LocationSpoofingEngine()
        let mapViewModel = MapViewModel(engine: engine, settings: settings, bookmarkStore: store)
        let bookmarksViewModel = BookmarksViewModel(store: store, mapViewModel: mapViewModel, settings: settings)
        let settingsViewModel = SettingsViewModel(settings: settings)

        self.settings = settings
        self.bookmarkStore = store
        self.mapViewModel = mapViewModel
        self.bookmarksViewModel = bookmarksViewModel
        self.settingsViewModel = settingsViewModel
    }
}
