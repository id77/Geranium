//
//  MapScreen.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import SwiftUI
import MapKit
#if canImport(UIKit)
import UIKit
#endif

struct MapScreen: View {
    @ObservedObject var viewModel: MapViewModel
    @EnvironmentObject private var bookmarkStore: BookmarkStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            MapCanvasView(region: $viewModel.mapRegion,
                          selectedCoordinate: viewModel.selectedLocation?.coordinate,
                          activeCoordinate: viewModel.activeLocation?.coordinate,
                          onTap: { coordinate in
                              dismissKeyboard()
                              viewModel.handleMapTap(coordinate)
                          },
                          onLongPress: { coordinate in
                              dismissKeyboard()
                              viewModel.handleMapLongPress(coordinate)
                          },
                          onRegionChange: viewModel.updateMapCenter,
                          onUserLocationUpdate: viewModel.updateMapUserLocation)
            .ignoresSafeArea(edges: [.top])

            VStack(spacing: 12) {
                searchBar
                    .padding(.top, 50)

                if viewModel.isSearching {
                    ProgressView("正在搜索…")
                        .padding(.horizontal)
                } else if viewModel.showSearchResults && !viewModel.searchResults.isEmpty {
                    SearchResultList(results: viewModel.searchResults, onSelect: { result in
                        dismissKeyboard()
                        viewModel.selectSearchResult(result)
                    })
                        .padding(.horizontal)
                }

                Spacer()
            }

            VStack {
                Spacer()
                MapControlPanel(viewModel: viewModel)
                    .padding()
            }

            FloatingLocationButton(
                action: viewModel.centerOnCurrentLocation,
                isSpoofing: viewModel.activeLocation != nil
            )
            FloatingAddButton(action: viewModel.openBookmarkCreator)
        }
        .alert(isPresented: $viewModel.showErrorAlert) {
            Alert(
                title: Text(""),
                message: Text(viewModel.errorMessage ?? "发生未知错误"),
                primaryButton: .default(Text("去设置"), action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }),
                secondaryButton: .cancel(Text("取消"))
            )
        }
        .sheet(item: $viewModel.editorMode, onDismiss: {
            viewModel.completeEditorFlow()
        }) { mode in
            BookmarkEditorView(mode: mode,
                               onSave: { name, coordinate, note in
                                   bookmarkStore.addBookmark(name: name, coordinate: coordinate, note: note)
                                   viewModel.completeEditorFlow()
                               },
                               onCancel: {
                                   viewModel.completeEditorFlow()
                               })
        }
        .onChange(of: viewModel.searchText) { newValue in
            if newValue.isEmpty {
                viewModel.clearSearch()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    dismissKeyboard()
                }
            }
        }
        .onAppear {
            viewModel.requestLocationPermission()
        }
    }

    private func dismissKeyboard() {
        searchFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil,
                                        from: nil,
                                        for: nil)
        #endif
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索地点", text: $viewModel.searchText, onCommit: {
                dismissKeyboard()
                viewModel.performSearch()
            })
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .focused($searchFocused)
            .submitLabel(.search)

            if !viewModel.searchText.isEmpty {
                Button(action: viewModel.clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }
}

private struct MapControlPanel: View {
    @ObservedObject var viewModel: MapViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.headline)
                if let location = viewModel.selectedLocation {
                    Text(location.coordinateDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    // 如果有详细地址备注，也显示出来
                    if let note = location.note, !note.isEmpty {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                } else {
                    Text("点击地图即可放置定位点")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: viewModel.toggleSpoofing) {
                Text(viewModel.primaryButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.primaryButtonDisabled ? Color.gray.opacity(0.3) : Color.accentColor)
                    .foregroundColor(viewModel.primaryButtonDisabled ? .secondary : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(viewModel.primaryButtonDisabled)

        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        }
    }

    private var displayTitle: String {
        guard let location = viewModel.selectedLocation else {
            return "当前预览"
        }

        // 如果有 label 且不是"正在获取地址..."和"选中位置"这类临时文本，则显示 label
        if let label = location.label, !label.isEmpty,
           label != "正在获取地址...", label != "选中位置" {
            return label
        }

        // 否则显示"当前选点"
        return "当前选点"
    }
}

private struct FloatingAddButton: View {
    var action: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(14)
                        .background(Color.accentColor, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 125)
            }
        }
    }
}

private struct FloatingLocationButton: View {
    var action: () -> Void
    var isSpoofing: Bool

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: action) {
                    Image(systemName: "location.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(14)
                        .background(isSpoofing ? Color.blue : Color.red, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 185)
            }
        }
    }
}

private struct SearchResultList: View {
    var results: [SearchResult]
    var onSelect: (SearchResult) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(results) { result in
                    Button(action: { onSelect(result) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
        .frame(maxHeight: 240)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
