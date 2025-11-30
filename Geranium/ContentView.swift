//
//  ContentView.swift
//  Geranium
//
//  Created by Constantin Clerc on 10/12/2023.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appModel = LocSimAppModel()
    @State private var selectedTab = 0

    var body: some View {
        MainTabView(mapViewModel: appModel.mapViewModel,
                    bookmarksViewModel: appModel.bookmarksViewModel,
                    settingsViewModel: appModel.settingsViewModel,
                    selectedTab: $selectedTab)
        .environmentObject(appModel.bookmarkStore)
        .environmentObject(appModel.settings)
        .onOpenURL { url in
            handleURL(url)
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "geranium" else { return }

        if url.host == "bookmarks" {
            // 强制刷新收藏列表
            appModel.bookmarkStore.reload()

            // 切换到收藏 tab (index 1)
            selectedTab = 1
        }
    }
}
