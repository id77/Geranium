//
//  MapViewModel.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import Foundation
import MapKit
import Combine
import SwiftUI

@MainActor
final class MapViewModel: ObservableObject {
    @Published var selectedLocation: LocationPoint?
    @Published var mapRegion: MKCoordinateRegion
    @Published var editorMode: BookmarkEditorMode?
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false
    @Published var lastMapCenter: CLLocationCoordinate2D?
    @Published var searchText: String = ""
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching: Bool = false
    @Published var showSearchResults: Bool = false

    // 地图上显示的用户位置(蓝色圆点的实际位置)
    @Published private var mapUserLocation: CLLocationCoordinate2D?
    
    // 最近搜索记录，最多保存 6 个
    @Published var recentSearches: [String] = []
    
    // 搜索防抖
    private let searchSubject = PassthroughSubject<String, Never>()

    var statusInfo: MapStatus {
        if let active = engine.session.activePoint {
            return MapStatus(
                title: "定位模拟已开启",
                detail: active.label ?? active.coordinateDescription,
                isActive: true
            )
        }

        return MapStatus(
            title: "定位模拟已关闭",
            detail: "点击地图即可放置定位点",
            isActive: false
        )
    }

    var primaryButtonTitle: String {
        engine.session.isActive ? "停止模拟" : "开始模拟"
    }

    var primaryButtonDisabled: Bool {
        if engine.session.isActive { return false }
        return selectedLocation == nil
    }

    var activeLocation: LocationPoint? {
        engine.session.activePoint
    }

    private let engine: LocationSpoofingEngine
    private let settings: LocSimSettings
    private unowned let bookmarkStore: BookmarkStore
    private var cancellables = Set<AnyCancellable>()
    private let locationAuthorizer = LocationModel()
    private var hasCenteredOnUser = false
    private var searchTask: Task<Void, Never>?

    init(engine: LocationSpoofingEngine, settings: LocSimSettings, bookmarkStore: BookmarkStore) {
        self.engine = engine
        self.settings = settings
        self.bookmarkStore = bookmarkStore

        let defaultCenter = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
        self.mapRegion = MKCoordinateRegion(center: defaultCenter,
                                            span: MKCoordinateSpan(latitudeDelta: settings.mapSpanDegrees,
                                                                   longitudeDelta: settings.mapSpanDegrees))
        
        // 加载最近搜索记录
        if let saved = UserDefaults.standard.stringArray(forKey: "recentSearches") {
            self.recentSearches = Array(saved.prefix(6))
        }

        engine.$session
            .receive(on: RunLoop.main)
            .sink { [weak self] session in
                guard let self else { return }
                if !session.isActive {
                    bookmarkStore.markAsLastUsed(nil)
                }
                objectWillChange.send()
            }
            .store(in: &cancellables)

        // 不再监听 locationAuthorizer.$currentLocation，统一使用地图的 userLocation
        // 这样可以避免重复居中和时序问题
        
        // 设置搜索防抖：用户停止输入 0.5 秒后才触发搜索
        searchSubject
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] query in
                guard let self else { return }
                if !query.isEmpty {
                    self.performSearch()
                }
            }
            .store(in: &cancellables)
    }

    func requestLocationPermission() {
        // 如果权限未确定，请求权限
        if locationAuthorizer.authorisationStatus == .notDetermined {
            locationAuthorizer.requestAuthorisation(always: false)
        }
        // 如果已经有权限但还没开始定位，启动定位
        else if locationAuthorizer.authorisationStatus == .authorizedWhenInUse || 
                locationAuthorizer.authorisationStatus == .authorizedAlways {
            // LocationModel 的 init 中已经会自动开始定位，这里不需要额外操作
        }
    }

    func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        // 先设置一个临时的位置点
        selectedLocation = LocationPoint(coordinate: coordinate, label: "正在获取地址...")
        // 点击地图时不自动居中，因为用户已经在看着点击的位置了
        // 只在点击收藏、开始模拟、当前位置等操作时才自动居中

        // 进行反向地理编码以获取地点名称和详细地址
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()

        Task { @MainActor in
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    // 获取地点名称
                    let name = placemark.name ?? placemark.thoroughfare ?? "选中位置"

                    // 构建详细地址（省市区街道）
                    var addressComponents: [String] = []
                    if let country = placemark.country {
                        addressComponents.append(country)
                    }
                    if let administrativeArea = placemark.administrativeArea {
                        addressComponents.append(administrativeArea)
                    }
                    if let locality = placemark.locality {
                        addressComponents.append(locality)
                    }
                    if let subLocality = placemark.subLocality {
                        addressComponents.append(subLocality)
                    }
                    if let thoroughfare = placemark.thoroughfare {
                        addressComponents.append(thoroughfare)
                    }
                    if let subThoroughfare = placemark.subThoroughfare {
                        addressComponents.append(subThoroughfare)
                    }

                    let detailedAddress = addressComponents.joined(separator: " ")

                    // 更新选中的位置点，包含地点名称和详细地址
                    selectedLocation = LocationPoint(
                        coordinate: coordinate,
                        label: name,
                        note: detailedAddress.isEmpty ? nil : detailedAddress
                    )
                } else {
                    // 如果没有获取到地址信息，使用默认名称
                    selectedLocation = LocationPoint(coordinate: coordinate, label: "选中位置")
                }
            } catch {
                // 地理编码失败，使用默认名称
                selectedLocation = LocationPoint(coordinate: coordinate, label: "选中位置")
            }
        }
    }

    func handleMapLongPress(_ coordinate: CLLocationCoordinate2D) {
        // 先设置一个临时的位置点
        selectedLocation = LocationPoint(coordinate: coordinate, label: "正在获取地址...")

        // 自动居中到长按的位置
        if settings.autoCenterOnSelection {
            centerMap(on: coordinate)
        }

        // 进行反向地理编码以获取地点名称和详细地址
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()

        Task { @MainActor in
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    // 获取地点名称
                    let name = placemark.name ?? placemark.thoroughfare ?? "选中位置"

                    // 构建详细地址（省市区街道）
                    var addressComponents: [String] = []
                    if let country = placemark.country {
                        addressComponents.append(country)
                    }
                    if let administrativeArea = placemark.administrativeArea {
                        addressComponents.append(administrativeArea)
                    }
                    if let locality = placemark.locality {
                        addressComponents.append(locality)
                    }
                    if let subLocality = placemark.subLocality {
                        addressComponents.append(subLocality)
                    }
                    if let thoroughfare = placemark.thoroughfare {
                        addressComponents.append(thoroughfare)
                    }
                    if let subThoroughfare = placemark.subThoroughfare {
                        addressComponents.append(subThoroughfare)
                    }

                    let detailedAddress = addressComponents.joined(separator: " ")

                    // 更新选中的位置点，包含地点名称和详细地址
                    let locationPoint = LocationPoint(
                        coordinate: coordinate,
                        label: name,
                        note: detailedAddress.isEmpty ? nil : detailedAddress
                    )
                    selectedLocation = locationPoint

                    // 直接开始模拟
                    startSpoofing(point: locationPoint, bookmark: nil)
                } else {
                    // 如果没有获取到地址信息，使用默认名称并开始模拟
                    let locationPoint = LocationPoint(coordinate: coordinate, label: "选中位置")
                    selectedLocation = locationPoint
                    startSpoofing(point: locationPoint, bookmark: nil)
                }
            } catch {
                // 地理编码失败，使用默认名称并开始模拟
                let locationPoint = LocationPoint(coordinate: coordinate, label: "选中位置")
                selectedLocation = locationPoint
                startSpoofing(point: locationPoint, bookmark: nil)
            }
        }
    }

    func updateMapCenter(_ coordinate: CLLocationCoordinate2D) {
        lastMapCenter = coordinate
    }

    func updateMapUserLocation(_ coordinate: CLLocationCoordinate2D) {
        mapUserLocation = coordinate
        // 首次获取到地图用户位置时自动居中
        if !hasCenteredOnUser {
            hasCenteredOnUser = true
            centerMap(on: coordinate)
        }
    }

    func openBookmarkCreator() {
        if let selectedLocation {
            editorMode = .create(selectedLocation)
        } else if let center = lastMapCenter {
            editorMode = .create(LocationPoint(coordinate: center))
        } else {
            errorMessage = "请先在地图上选择一个位置"
            showErrorAlert = true
        }
    }

    func completeEditorFlow() {
        editorMode = nil
    }

    func toggleSpoofing() {
        if engine.session.isActive {
            stopSpoofing()
        } else {
            startSpoofingSelected()
        }
    }

    func startSpoofingSelected() {
        guard let selectedLocation else {
            engine.recordError(.invalidCoordinate)
            errorMessage = "请先在地图上选择一个有效的位置"
            showErrorAlert = true
            return
        }
        // 开始模拟时自动居中到选中的位置
        if settings.autoCenterOnSelection {
            centerMap(on: selectedLocation.coordinate)
        }
        startSpoofing(point: selectedLocation, bookmark: nil)
    }

    func focus(on bookmark: Bookmark, autoStartOverride: Bool? = nil) {
        let point = bookmark.locationPoint
        selectedLocation = point
        centerMap(on: point.coordinate)

        let shouldAutoStart = autoStartOverride ?? settings.autoStartFromBookmarks
        if shouldAutoStart {
            startSpoofing(point: point, bookmark: bookmark)
        }
    }

    func stopSpoofing() {
        engine.stopSpoofing()
        // 主动刷新一次userLocation，提升体验
        locationAuthorizer.requestAuthorisation(always: false)
        bookmarkStore.markAsLastUsed(nil)
        // 不清空选中位置，保留用户选点体验
    }

    func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            searchResults = []
            showSearchResults = false
            return
        }

        // 尝试解析为坐标
        if let coordinate = parseCoordinate(from: query) {
            // 直接使用解析出的坐标
            let locationPoint = LocationPoint(
                coordinate: coordinate,
                label: "坐标位置",
                note: String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
            )
            selectedLocation = locationPoint
            centerMap(on: coordinate)

            // 创建一个虚拟搜索结果用于反向地理编码
            Task { [weak self] in
                guard let self else { return }
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let geocoder = CLGeocoder()
                do {
                    let placemarks = try await geocoder.reverseGeocodeLocation(location)
                    if let placemark = placemarks.first {
                        let name = placemark.name ?? "坐标位置"
                        let locality = placemark.locality ?? ""
                        await MainActor.run {
                            self.selectedLocation = LocationPoint(
                                coordinate: coordinate,
                                label: name,
                                note: locality
                            )
                            self.searchText = name
                            self.isSearching = false
                        }
                    } else {
                        await MainActor.run {
                            self.isSearching = false
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.isSearching = false
                    }
                }
            }
            return
        }

        // 如果不是坐标，执行正常的地点搜索
        isSearching = true
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            let search = MKLocalSearch(request: request)
            do {
                let response = try await search.start()
                let mapped = response.mapItems.map(SearchResult.init)
                await MainActor.run {
                    self.searchResults = mapped
                    self.showSearchResults = !mapped.isEmpty
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.isSearching = false
                }
            }
        }
    }

    private func parseCoordinate(from text: String) -> CLLocationCoordinate2D? {
        // 移除多余空格并分割
        let cleaned = text.replacingOccurrences(of: " ", with: "")
        let components = cleaned.split(separator: ",")

        guard components.count == 2,
              let first = Double(components[0]),
              let second = Double(components[1]) else {
            return nil
        }

        // 自动识别经纬度顺序
        // 纬度范围: -90 到 90
        // 经度范围: -180 到 180
        let latitude: Double
        let longitude: Double

        if abs(first) <= 90 && abs(second) <= 180 {
            // 第一个可能是纬度，第二个是经度
            if abs(second) <= 90 {
                // 两个都可能是纬度，需要判断哪个更像经度
                // 如果第二个的绝对值更大，它更可能是经度
                if abs(second) > abs(first) {
                    latitude = first
                    longitude = second
                } else {
                    // 默认：纬度在前
                    latitude = first
                    longitude = second
                }
            } else {
                // 第二个超过90，肯定是经度
                latitude = first
                longitude = second
            }
        } else if abs(second) <= 90 && abs(first) <= 180 {
            // 第二个可能是纬度，第一个是经度
            latitude = second
            longitude = first
        } else {
            // 无效坐标
            return nil
        }

        // 验证最终坐标的有效性
        guard abs(latitude) <= 90 && abs(longitude) <= 180 else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func selectSearchResult(_ result: SearchResult) {
        let coordinate = result.mapItem.placemark.coordinate
        selectedLocation = LocationPoint(coordinate: coordinate, label: result.title, note: result.subtitle)
        centerMap(on: coordinate)
        showSearchResults = false
        searchResults = []
        // 清空搜索文本，避免显示选中的结果名称导致再次搜索
        searchText = ""
        // 记录到最近搜索
        addToRecentSearches(result.title)
    }
    
    func selectAndStartSpoofing(_ result: SearchResult) {
        let coordinate = result.mapItem.placemark.coordinate
        let locationPoint = LocationPoint(coordinate: coordinate, label: result.title, note: result.subtitle)
        selectedLocation = locationPoint
        centerMap(on: coordinate)
        showSearchResults = false
        searchResults = []
        searchText = ""
        // 记录到最近搜索
        addToRecentSearches(result.title)
        // 直接开始模拟
        startSpoofing(point: locationPoint, bookmark: nil)
    }
    
    private func addToRecentSearches(_ query: String) {
        // 移除重复项
        recentSearches.removeAll { $0 == query }
        // 添加到最前面
        recentSearches.insert(query, at: 0)
        // 最多保存 6 个
        if recentSearches.count > 6 {
            recentSearches = Array(recentSearches.prefix(6))
        }
        // 保存到 UserDefaults
        UserDefaults.standard.set(recentSearches, forKey: "recentSearches")
    }

    func onSearchTextChanged(_ newValue: String) {
        if newValue.isEmpty {
            clearSearch()
        } else {
            searchSubject.send(newValue)
        }
    }

    func clearSearch() {
        searchText = ""
        searchResults = []
        showSearchResults = false
        isSearching = false
        searchTask?.cancel()
    }

    func centerOnCurrentLocation() {
        // 优先：如果正在模拟定位，居中到模拟位置
        if let activeLocation = engine.session.activePoint {
            centerMap(on: activeLocation.coordinate)
            return
        }
        // 否则优先使用地图的 userLocation（强制刷新一次）
        locationAuthorizer.requestAuthorisation(always: false)
        if let location = mapUserLocation {
            centerMap(on: location)
            return
        }
        // 如果没有地图的 userLocation，则使用 CLLocationManager 的位置
        let authStatus = locationAuthorizer.authorisationStatus
        if authStatus == .denied || authStatus == .restricted {
            errorMessage = "位置权限被拒绝。\n请前往：设置 → 隐私与安全 → 定位服务 → Geranium\n选择\"使用 App 期间\"以启用定位功能。"
            showErrorAlert = true
            return
        }
        if authStatus == .notDetermined {
            errorMessage = "TrollStore 应用需要手动授予位置权限。\n请前往：设置 → 隐私与安全 → 定位服务 → Geranium\n选择\"使用 App 期间\"。"
            showErrorAlert = true
            locationAuthorizer.requestAuthorisation(always: false)
            return
        }
        if let location = locationAuthorizer.currentLocation {
            centerMap(on: location.coordinate)
        }
        // 如果还没有位置数据，静默等待，不显示提示
    }

    private func startSpoofing(point: LocationPoint, bookmark: Bookmark?) {
        engine.startSpoofing(point: point)
        if let bookmark {
            bookmarkStore.markAsLastUsed(bookmark)
        } else {
            bookmarkStore.markAsLastUsed(nil)
        }
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        // 只改变中心点，保持当前的缩放级别（span）
        withAnimation(settings.dampedAnimations ? .spring(response: 0.45, dampingFraction: 0.75) : .default) {
            mapRegion = MKCoordinateRegion(center: coordinate, span: mapRegion.span)
        }
        lastMapCenter = coordinate
    }
}

struct MapStatus {
    var title: String
    var detail: String
    var isActive: Bool
}

struct SearchResult: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem

    init(mapItem: MKMapItem) {
        self.mapItem = mapItem
    }

    var title: String {
        mapItem.name ?? "未知地点"
    }

    var subtitle: String {
        mapItem.placemark.title ?? ""
    }
}
