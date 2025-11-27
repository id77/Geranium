//
//  BookmarkCardView.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import SwiftUI

struct BookmarkCardView: View {
    var bookmark: Bookmark
    var isActive: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(bookmark.name)
                        .font(.headline)
                    Spacer()

                    if isActive {
                        Label("正在使用", systemImage: "dot.radiowaves.right")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2), in: Capsule())
                    }
                }

                if let note = bookmark.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(bookmark.coordinateDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05))
            }
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}
