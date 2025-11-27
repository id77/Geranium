//
//  MainTabView.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import SwiftUI
import UIKit

struct MainTabView: View {
    @ObservedObject var mapViewModel: MapViewModel
    @ObservedObject var bookmarksViewModel: BookmarksViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel

    init(mapViewModel: MapViewModel, bookmarksViewModel: BookmarksViewModel, settingsViewModel: SettingsViewModel) {
        self.mapViewModel = mapViewModel
        self.bookmarksViewModel = bookmarksViewModel
        self.settingsViewModel = settingsViewModel

        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.35)
        appearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            tabView
                .toolbar(.visible, for: .tabBar)
                .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        } else {
            tabView
        }
    }

    @ViewBuilder
    private var tabView: some View {
        TabView {
            MapScreen(viewModel: mapViewModel)
                .tabItem {
                    Label("地图", systemImage: "map")
                }

            BookmarksScreen(viewModel: bookmarksViewModel)
                .tabItem {
                    Label("收藏", systemImage: "bookmark")
                }

            SettingsScreen(viewModel: settingsViewModel)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
    }
}
