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

        // 检查是否需要收藏
        let shouldCollect = queryItems.first(where: { $0.name == "not_collect" })?.value != "1"
        NSLog("### [MainApp] 是否收藏: \(shouldCollect)")

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

        // 从地图URL提取坐标和地点名称
        let urlInfo = extractCoordinateAndName(from: mapURL)
        
        guard let coordinate = urlInfo.coordinate else {
            NSLog("### [MainApp] 错误: 无法从URL提取坐标")
            return
        }
        
        NSLog("### [MainApp] 成功提取坐标: \(coordinate.latitude), \(coordinate.longitude)")
        if let placeName = urlInfo.placeName {
            NSLog("### [MainApp] 成功提取地点名称: \(placeName)")
        }

        // 切换到地图tab
        selectedTab = 0

        // 延迟执行，确保tab切换完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 如果有地点名称，尝试在坐标附近搜索获取更精确的位置
            if let placeName = urlInfo.placeName, !placeName.isEmpty {
                self.searchAndSpoof(placeName: placeName, nearCoordinate: coordinate, shouldCollect: shouldCollect)
            } else {
                // 没有地点名称，直接使用坐标
                self.spoofWithCoordinate(coordinate: coordinate, shouldCollect: shouldCollect)
            }
        }
    }
    
    /// 在指定坐标附近搜索地点名称，获取更精确的位置
    private func searchAndSpoof(placeName: String, nearCoordinate: CLLocationCoordinate2D, shouldCollect: Bool) {
        NSLog("### [MainApp] 在坐标 \(nearCoordinate.latitude), \(nearCoordinate.longitude) 附近搜索: \(placeName)")
        
        // 先使用原始坐标开始模拟（避免等待搜索）
        let coordString = String(format: "%.6f, %.6f", nearCoordinate.latitude, nearCoordinate.longitude)
        let initialPoint = LocationPoint(
            coordinate: nearCoordinate,
            label: placeName,
            note: "正在搜索精确位置...",
            needsCoordinateTransform: false
        )
        self.appModel.mapViewModel.selectedLocation = initialPoint
        self.appModel.mapViewModel.mapRegion = MKCoordinateRegion(
            center: nearCoordinate,
            span: MKCoordinateSpan(latitudeDelta: self.appModel.settings.mapSpanDegrees,
                                  longitudeDelta: self.appModel.settings.mapSpanDegrees)
        )
        self.appModel.mapViewModel.startSpoofingSelected()
        
        // 在坐标附近搜索地点
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = placeName
        // 设置搜索范围为坐标周围 2km
        searchRequest.region = MKCoordinateRegion(
            center: nearCoordinate,
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            if let error = error {
                NSLog("### [MainApp] 搜索失败: \(error.localizedDescription)")
                // 搜索失败，使用反向地理编码获取地址
                self.updateWithReverseGeocode(coordinate: nearCoordinate, placeName: placeName, shouldCollect: shouldCollect)
                return
            }
            
            guard let response = response, !response.mapItems.isEmpty else {
                NSLog("### [MainApp] 搜索无结果，使用原始坐标")
                self.updateWithReverseGeocode(coordinate: nearCoordinate, placeName: placeName, shouldCollect: shouldCollect)
                return
            }
            
            // 找到最近的搜索结果
            let sortedItems = response.mapItems.sorted { item1, item2 in
                let loc1 = CLLocation(latitude: item1.placemark.coordinate.latitude, longitude: item1.placemark.coordinate.longitude)
                let loc2 = CLLocation(latitude: item2.placemark.coordinate.latitude, longitude: item2.placemark.coordinate.longitude)
                let target = CLLocation(latitude: nearCoordinate.latitude, longitude: nearCoordinate.longitude)
                return loc1.distance(from: target) < loc2.distance(from: target)
            }
            
            if let bestMatch = sortedItems.first {
                let preciseCoordinate = bestMatch.placemark.coordinate
                let distance = CLLocation(latitude: preciseCoordinate.latitude, longitude: preciseCoordinate.longitude)
                    .distance(from: CLLocation(latitude: nearCoordinate.latitude, longitude: nearCoordinate.longitude))
                
                NSLog("### [MainApp] ✓ 找到精确位置: \(bestMatch.name ?? placeName)")
                NSLog("### [MainApp]   坐标: \(preciseCoordinate.latitude), \(preciseCoordinate.longitude)")
                NSLog("### [MainApp]   距离原坐标: \(String(format: "%.0f", distance)) 米")
                
                // 如果搜索结果距离原坐标超过 5km，可能不是同一个地点，使用原坐标
                if distance > 5000 {
                    NSLog("### [MainApp] ⚠️ 搜索结果距离过远，使用原始坐标")
                    self.updateWithReverseGeocode(coordinate: nearCoordinate, placeName: placeName, shouldCollect: shouldCollect)
                    return
                }
                
                // 使用精确坐标更新位置
                DispatchQueue.main.async {
                    let finalName = bestMatch.name ?? placeName
                    
                    // 构建详细地址
                    var addressComponents: [String] = []
                    let pm = bestMatch.placemark
                    if let country = pm.country { addressComponents.append(country) }
                    if let administrativeArea = pm.administrativeArea { addressComponents.append(administrativeArea) }
                    if let locality = pm.locality { addressComponents.append(locality) }
                    if let subLocality = pm.subLocality { addressComponents.append(subLocality) }
                    if let thoroughfare = pm.thoroughfare { addressComponents.append(thoroughfare) }
                    if let subThoroughfare = pm.subThoroughfare { addressComponents.append(subThoroughfare) }
                    let detailedAddress = addressComponents.isEmpty ? coordString : addressComponents.joined(separator: " ")
                    
                    let precisePoint = LocationPoint(
                        coordinate: preciseCoordinate,
                        label: finalName,
                        note: detailedAddress,
                        needsCoordinateTransform: false
                    )
                    
                    // 更新位置并重新开始模拟
                    self.appModel.mapViewModel.selectedLocation = precisePoint
                    self.appModel.mapViewModel.mapRegion = MKCoordinateRegion(
                        center: preciseCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: self.appModel.settings.mapSpanDegrees,
                                              longitudeDelta: self.appModel.settings.mapSpanDegrees)
                    )
                    
                    // 用精确坐标重新模拟
                    self.appModel.mapViewModel.startSpoofingSelected()
                    
                    // 收藏
                    if shouldCollect {
                        NSLog("### [MainApp] 自动收藏精确位置: \(finalName)")
                        self.appModel.bookmarkStore.addBookmark(
                            name: finalName,
                            coordinate: preciseCoordinate,
                            note: detailedAddress
                        )
                    }
                    
                    // 更新持久化信息
                    if self.appModel.mapViewModel.activeLocation != nil {
                        UserDefaults.standard.set(finalName, forKey: "spoofingLabel")
                        UserDefaults.standard.set(detailedAddress, forKey: "spoofingNote")
                    }
                }
            } else {
                self.updateWithReverseGeocode(coordinate: nearCoordinate, placeName: placeName, shouldCollect: shouldCollect)
            }
        }
    }
    
    /// 使用反向地理编码更新位置信息（作为搜索失败的后备方案）
    private func updateWithReverseGeocode(coordinate: CLLocationCoordinate2D, placeName: String, shouldCollect: Bool) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let coordString = String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            var finalName = placeName
            var detailedAddress = coordString
            
            if let placemark = placemarks?.first {
                if placeName.isEmpty {
                    finalName = placemark.name ?? placemark.locality ?? "分享的位置"
                }
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
                let updatedPoint = LocationPoint(
                    coordinate: coordinate,
                    label: finalName,
                    note: detailedAddress,
                    needsCoordinateTransform: false
                )
                self.appModel.mapViewModel.selectedLocation = updatedPoint
                
                if shouldCollect {
                    NSLog("### [MainApp] 自动收藏位置: \(finalName)")
                    self.appModel.bookmarkStore.addBookmark(
                        name: finalName,
                        coordinate: coordinate,
                        note: detailedAddress
                    )
                }
                
                if self.appModel.mapViewModel.activeLocation != nil {
                    UserDefaults.standard.set(finalName, forKey: "spoofingLabel")
                    UserDefaults.standard.set(detailedAddress, forKey: "spoofingNote")
                }
            }
        }
    }
    
    /// 直接使用坐标进行模拟（无地点名称时）
    private func spoofWithCoordinate(coordinate: CLLocationCoordinate2D, shouldCollect: Bool) {
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
        
        self.appModel.mapViewModel.startSpoofingSelected()
        
        // 反向地理编码获取地址
        updateWithReverseGeocode(coordinate: coordinate, placeName: "", shouldCollect: shouldCollect)
    }

    /// 从地图 URL 提取坐标和地点名称
    private func extractCoordinateAndName(from url: URL) -> (coordinate: CLLocationCoordinate2D?, placeName: String?) {
        NSLog("### [MainApp] extractCoordinateAndName from: \(url.absoluteString)")
        
        var coordinate: CLLocationCoordinate2D?
        var placeName: String?
        
        // 尝试从查询参数提取坐标和名称
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems {
            
            NSLog("### [MainApp] 地图URL查询参数: \(queryItems.map { "\($0.name)=\($0.value ?? "nil")" }.joined(separator: ", "))")

            // 提取 ll 参数（坐标）
            if let llParam = queryItems.first(where: { $0.name == "ll" })?.value {
                NSLog("### [MainApp] 尝试提取ll参数: \(llParam)")
                let parts = llParam.components(separatedBy: ",")
                if parts.count == 2,
                   let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                   let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                    NSLog("### [MainApp] ✓ ll参数解析成功: \(lat), \(lon)")
                    coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            }
            
            // 提取 q 参数（可能是坐标或地点名称）
            if let qParam = queryItems.first(where: { $0.name == "q" })?.value {
                NSLog("### [MainApp] 尝试解析q参数: \(qParam)")
                let parts = qParam.components(separatedBy: ",")
                // 检查是否是坐标格式
                if parts.count >= 2,
                   let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                   let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                    // q 参数是坐标
                    if coordinate == nil {
                        NSLog("### [MainApp] ✓ q参数是坐标: \(lat), \(lon)")
                        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    }
                } else {
                    // q 参数是地点名称
                    placeName = qParam.removingPercentEncoding ?? qParam
                    NSLog("### [MainApp] ✓ q参数是地点名称: \(placeName ?? "")")
                }
            }

            // 提取 center 参数（坐标）
            if coordinate == nil, let centerParam = queryItems.first(where: { $0.name == "center" })?.value {
                NSLog("### [MainApp] 尝试提取center参数: \(centerParam)")
                let parts = centerParam.components(separatedBy: ",")
                if parts.count == 2,
                   let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                   let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                    NSLog("### [MainApp] ✓ center参数解析成功: \(lat), \(lon)")
                    coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            }
        }

        // 从路径提取坐标 (Apple Maps格式: /@lat,lon)
        if coordinate == nil {
            NSLog("### [MainApp] 尝试从路径提取坐标")
            let pathString = url.absoluteString
            if let range = pathString.range(of: "/@([0-9.-]+),([0-9.-]+)", options: .regularExpression) {
                let coordString = String(pathString[range])
                NSLog("### [MainApp] 找到坐标字符串: \(coordString)")
                let parts = coordString.replacingOccurrences(of: "/@", with: "").components(separatedBy: ",")
                if parts.count >= 2,
                   let lat = Double(parts[0]),
                   let lon = Double(parts[1]) {
                    NSLog("### [MainApp] ✓ 路径解析成功: \(lat), \(lon)")
                    coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            }
        }

        if coordinate == nil {
            NSLog("### [MainApp] ✗ 无法提取坐标")
        }
        
        return (coordinate, placeName)
    }
}
