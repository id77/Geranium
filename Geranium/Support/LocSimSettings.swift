//
//  LocSimSettings.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import Foundation

@MainActor
final class LocSimSettings: ObservableObject {
    @Published var autoStartFromBookmarks: Bool {
        didSet { defaults.set(autoStartFromBookmarks, forKey: Keys.autoStartFromBookmarks) }
    }

    @Published var defaultZoomLevel: Double {
        didSet { defaults.set(defaultZoomLevel, forKey: Keys.defaultZoomLevel) }
    }

    let autoCenterOnSelection: Bool = true
    let dampedAnimations: Bool = true

    private enum Keys {
        static let autoStartFromBookmarks = "settings.autoStartFromBookmarks"
        static let defaultZoomLevel = "settings.defaultZoomLevel"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.autoStartFromBookmarks = defaults.object(forKey: Keys.autoStartFromBookmarks) as? Bool ?? true
        self.defaultZoomLevel = defaults.object(forKey: Keys.defaultZoomLevel) as? Double ?? 0
    }

    var mapSpanDegrees: Double {
        max(0.01, min(defaultZoomLevel / 1000, 5))
    }
}
