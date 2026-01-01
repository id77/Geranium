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
        .onAppear {
            NotificationCenter.default.addObserver(forName: NSNotification.Name("GeraniumAutoSpoof"), object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo,
                   let lat = userInfo["lat"] as? Double,
                   let lon = userInfo["lon"] as? Double,
                   let name = userInfo["name"] as? String {
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    // 从通知来的坐标是WGS-84格式，不需要坐标转换
                    let locationPoint = LocationPoint(coordinate: coordinate, label: name, needsCoordinateTransform: false)
                    selectedTab = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        appModel.mapViewModel.selectedLocation = locationPoint
                        appModel.mapViewModel.mapRegion = MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: appModel.settings.mapSpanDegrees,
                                                  longitudeDelta: appModel.settings.mapSpanDegrees)
                        )
                        appModel.mapViewModel.startSpoofingSelected()
                    }
                }
            }
        }
    }

    private func handleURL(_ url: URL) {
        NSLog("### [MainApp] handleURL called with: \(url.absoluteString)")
        NSLog("### [MainApp] URL scheme: \(url.scheme ?? "nil"), host: \(url.host ?? "nil")")
        
        guard url.scheme == "geranium" else { 
            NSLog("### [MainApp] URL scheme 不是 geranium，忽略")
            return 
        }

        if url.host == "bookmarks" {
            // 强制刷新收藏列表
            appModel.bookmarkStore.reload()

            // 切换到收藏 tab (index 1)
            selectedTab = 1
        } else if url.host == "spoof" || url.host == "spoof-and-bookmark" {
            // 处理虚拟定位请求（包括定位并收藏）
            handleSpoofRequest(url)
        } else if url.host == "process-map-url" {
            // 处理扩展传来的地图URL
            handleMapURL(url)
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
            // 创建位置点并开始模拟（URL scheme来的坐标是WGS-84格式，不需要坐标转换）
            let locationPoint = LocationPoint(coordinate: coordinate, label: "分享的位置", needsCoordinateTransform: false)

            // 设置选中的位置
            appModel.mapViewModel.selectedLocation = locationPoint

            // 将地图居中到该位置，使用默认缩放级别
            appModel.mapViewModel.mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: appModel.settings.mapSpanDegrees,
                                      longitudeDelta: appModel.settings.mapSpanDegrees)
            )

            // 自动开始模拟定位
            appModel.mapViewModel.startSpoofingSelected()
        }
    }

    private func handleMapURL(_ url: URL) {
        NSLog("### [MainApp] handleMapURL called with: \(url.absoluteString)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            NSLog("### [MainApp] 错误: 无法解析URL components 或查询参数")
            return
        }
        
        NSLog("### [MainApp] 查询参数: \(queryItems.map { "\($0.name)=\($0.value ?? "nil")" }.joined(separator: ", "))")

        guard let encodedURLString = queryItems.first(where: { $0.name == "url" })?.value else {
            NSLog("### [MainApp] 错误: 找不到 url 参数")
            return
        }
        
        NSLog("### [MainApp] 编码的URL字符串: \(encodedURLString)")

        guard let mapURLString = encodedURLString.removingPercentEncoding else {
            NSLog("### [MainApp] 错误: URL解码失败")
            return
        }
        
        NSLog("### [MainApp] 解码后的URL字符串: \(mapURLString)")

        guard let safeURLString = mapURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let mapURL = URL(string: safeURLString) else {
            NSLog("### [MainApp] 错误: 无法创建URL对象（已编码）")
            return
        }
        
        NSLog("### [MainApp] 地图URL: \(mapURL.absoluteString)")

        // 从地图URL提取坐标
        guard let coordinate = extractCoordinate(from: mapURL) else {
            NSLog("### [MainApp] 错误: 无法从URL提取坐标")
            return
        }
        
        NSLog("### [MainApp] 成功提取坐标: \(coordinate.latitude), \(coordinate.longitude)")

        // 切换到地图tab
        selectedTab = 0

        // 延迟执行，确保tab切换完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 先设置初始点并立即开始模拟（使用坐标字符串作为临时地址）
            let coordString = String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
            let locationPoint = LocationPoint(
                coordinate: coordinate, 
                label: "分享的位置", 
                note: coordString, 
                needsCoordinateTransform: false
            )
            self.appModel.mapViewModel.selectedLocation = locationPoint
            self.appModel.mapViewModel.mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: self.appModel.settings.mapSpanDegrees,
                                      longitudeDelta: self.appModel.settings.mapSpanDegrees)
            )
            
            // 立即开始模拟，不等待地理编码
            self.appModel.mapViewModel.startSpoofingSelected()
            
            // 在后台异步获取详细地址并更新
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                var placeName = "分享的位置"
                var detailedAddress = coordString // 默认使用坐标
                
                if let placemark = placemarks?.first {
                    placeName = placemark.name ?? placemark.locality ?? "分享的位置"
                    var addressComponents: [String] = []
                    if let country = placemark.country { addressComponents.append(country) }
                    if let administrativeArea = placemark.administrativeArea { addressComponents.append(administrativeArea) }
                    if let locality = placemark.locality { addressComponents.append(locality) }
                    if let subLocality = placemark.subLocality { addressComponents.append(subLocality) }
                    if let thoroughfare = placemark.thoroughfare { addressComponents.append(thoroughfare) }
                    if let subThoroughfare = placemark.subThoroughfare { addressComponents.append(subThoroughfare) }
                    let fullAddress = addressComponents.joined(separator: " ")
                    if !fullAddress.isEmpty {
                        detailedAddress = fullAddress
                    }
                }
                
                DispatchQueue.main.async {
                    // 更新详细地址
                    let updatedPoint = LocationPoint(
                        coordinate: coordinate, 
                        label: placeName, 
                        note: detailedAddress, 
                        needsCoordinateTransform: false
                    )
                    self.appModel.mapViewModel.selectedLocation = updatedPoint
                    
                    // 自动收藏
                    self.appModel.bookmarkStore.addBookmark(
                        name: placeName,
                        coordinate: coordinate,
                        note: detailedAddress
                    )
                    
                    // 更新持久化的地址信息（如果正在模拟）
                    if self.appModel.mapViewModel.activeLocation != nil {
                        UserDefaults.standard.set(placeName, forKey: "spoofingLabel")
                        UserDefaults.standard.set(detailedAddress, forKey: "spoofingNote")
                    }
                }
            }
        }
    }

    private func extractCoordinate(from url: URL) -> CLLocationCoordinate2D? {
        NSLog("### [MainApp] extractCoordinate from: \(url.absoluteString)")
        
        // 尝试从查询参数提取坐标
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems {
            
            NSLog("### [MainApp] 地图URL查询参数: \(queryItems.map { "\($0.name)=\($0.value ?? "nil")" }.joined(separator: ", "))")

            // 方法1: ll参数 (Google Maps)
            if let llParam = queryItems.first(where: { $0.name == "ll" })?.value {
                NSLog("### [MainApp] 尝试方法1 (ll参数): \(llParam)")
                let parts = llParam.components(separatedBy: ",")
                if parts.count == 2,
                   let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                   let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                    NSLog("### [MainApp] ✓ 方法1成功: \(lat), \(lon)")
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                NSLog("### [MainApp] ✗ 方法1失败")
            }

            // 方法2: q参数
            if let qParam = queryItems.first(where: { $0.name == "q" })?.value {
                NSLog("### [MainApp] 尝试方法2 (q参数): \(qParam)")
                let parts = qParam.components(separatedBy: ",")
                if parts.count >= 2,
                   let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                   let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                    NSLog("### [MainApp] ✓ 方法2成功: \(lat), \(lon)")
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                NSLog("### [MainApp] ✗ 方法2失败")
            }

            // 方法3: center参数
            if let centerParam = queryItems.first(where: { $0.name == "center" })?.value {
                NSLog("### [MainApp] 尝试方法3 (center参数): \(centerParam)")
                let parts = centerParam.components(separatedBy: ",")
                if parts.count == 2,
                   let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                   let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                    NSLog("### [MainApp] ✓ 方法3成功: \(lat), \(lon)")
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                NSLog("### [MainApp] ✗ 方法3失败")
            }
        }

        // 方法4: 从路径提取 (Apple Maps格式: /@lat,lon)
        NSLog("### [MainApp] 尝试方法4 (路径解析)")
        let pathString = url.absoluteString
        if let range = pathString.range(of: "/@([0-9.-]+),([0-9.-]+)", options: .regularExpression) {
            let coordString = String(pathString[range])
            NSLog("### [MainApp] 找到坐标字符串: \(coordString)")
            let parts = coordString.replacingOccurrences(of: "/@", with: "").components(separatedBy: ",")
            if parts.count >= 2,
               let lat = Double(parts[0]),
               let lon = Double(parts[1]) {
                NSLog("### [MainApp] ✓ 方法4成功: \(lat), \(lon)")
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            NSLog("### [MainApp] ✗ 方法4失败")
        }

        NSLog("### [MainApp] ✗ 所有方法都失败，无法提取坐标")
        return nil
    }
}
