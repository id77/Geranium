//
//  ContentView.swift
//  Geranium
//
//  Created by Constantin Clerc on 10/12/2023.
//

import SwiftUI
import CoreLocation
import MapKit

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
        } else if url.host == "spoof" {
            // 处理虚拟定位请求
            handleSpoofRequest(url)
        }
    }

    private func handleSpoofRequest(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else { return }

        // 提取经纬度参数
        guard let latString = queryItems.first(where: { $0.name == "lat" })?.value,
              let lonString = queryItems.first(where: { $0.name == "lon" })?.value,
              let latitude = Double(latString),
              let longitude = Double(lonString) else { return }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        // 切换到地图 tab (index 0)
        selectedTab = 0

        // 稍微延迟以确保 tab 切换完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 创建位置点并开始模拟
            let locationPoint = LocationPoint(coordinate: coordinate, label: "分享的位置")

            // 设置选中的位置
            appModel.mapViewModel.selectedLocation = locationPoint

            // 将地图居中到该位置
            appModel.mapViewModel.mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )

            // 自动开始模拟定位
            appModel.mapViewModel.startSpoofingSelected()
        }
    }
}
