//
//  ContentView.swift
//  Geranium
//
//  Created by Constantin Clerc on 10/12/2023.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appModel = LocSimAppModel()

    var body: some View {
        MainTabView(mapViewModel: appModel.mapViewModel,
                    bookmarksViewModel: appModel.bookmarksViewModel,
                    settingsViewModel: appModel.settingsViewModel)
        .environmentObject(appModel.bookmarkStore)
        .environmentObject(appModel.settings)
    }
}
