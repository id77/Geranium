//
//  BookmarksScreen.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import SwiftUI

struct BookmarksScreen: View {
    @ObservedObject var viewModel: BookmarksViewModel
    @EnvironmentObject private var bookmarkStore: BookmarkStore

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    bookmarksList
                }
            } else {
                NavigationView {
                    bookmarksList
                }
            }
        }
        .sheet(item: $viewModel.editorMode) { mode in
            BookmarkEditorView(mode: mode, onSave: { name, coordinate, note in
                viewModel.saveBookmark(name: name, coordinate: coordinate, note: note)
            }, onCancel: {
                viewModel.dismissEditor()
            })
        }
        .onAppear {
            // 刷新收藏列表，确保显示最新数据
            bookmarkStore.reload()
        }
    }

    private var bookmarksList: some View {
        List {
            Section {
                if bookmarkStore.bookmarks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("暂无收藏")
                            .font(.headline)
                        Text("在地图上放置定位点或使用右上角的 + 号即可保存常用位置。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(bookmarkStore.bookmarks) { bookmark in
                        BookmarkCardView(bookmark: bookmark,
                                         isActive: bookmark.id == bookmarkStore.lastUsedBookmarkID,
                                         action: {
                            viewModel.select(bookmark)
                        })
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.delete(bookmark)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }

                            Button {
                                viewModel.edit(bookmark)
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                    .onMove(perform: viewModel.moveBookmarks)
                    .onDelete(perform: viewModel.deleteBookmarks)
                }
            } header: {
                Text("收藏的地点")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("收藏")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !bookmarkStore.bookmarks.isEmpty {
                    EditButton()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: viewModel.addBookmark) {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel(Text("新增收藏"))
            }
        }
    }
}
