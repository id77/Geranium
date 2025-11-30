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

        locationAuthorizer.$currentLocation
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] location in
                guard let self else { return }
                if !hasCenteredOnUser {
                    hasCenteredOnUser = true
                    centerMap(on: location.coordinate)
                }
            }
            .store(in: &cancellables)
    }

    func requestLocationPermission() {
        locationAuthorizer.requestAuthorisation(always: true)
    }

    func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        selectedLocation = LocationPoint(coordinate: coordinate, label: nil)
        if settings.autoCenterOnSelection {
            centerMap(on: coordinate)
        }
    }

    func updateMapCenter(_ coordinate: CLLocationCoordinate2D) {
        lastMapCenter = coordinate
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
        bookmarkStore.markAsLastUsed(nil)
    }

    func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            searchResults = []
            showSearchResults = false
            return
        }

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

    func selectSearchResult(_ result: SearchResult) {
        let coordinate = result.mapItem.placemark.coordinate
        selectedLocation = LocationPoint(coordinate: coordinate, label: result.title, note: result.subtitle)
        centerMap(on: coordinate)
        showSearchResults = false
        searchResults = []
        searchText = result.title
    }

    func clearSearch() {
        searchText = ""
        searchResults = []
        showSearchResults = false
        isSearching = false
        searchTask?.cancel()
    }

    func centerOnCurrentLocation() {
        guard let location = locationAuthorizer.currentLocation else {
            errorMessage = "无法获取当前位置，请确保已授予位置权限"
            showErrorAlert = true
            return
        }
        centerMap(on: location.coordinate)
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
