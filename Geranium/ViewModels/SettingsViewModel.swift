//
//  SettingsViewModel.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    let settings: LocSimSettings
    private var cancellables = Set<AnyCancellable>()

    init(settings: LocSimSettings) {
        self.settings = settings
        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
