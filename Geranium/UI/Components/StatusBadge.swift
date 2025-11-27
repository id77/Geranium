//
//  StatusBadge.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import SwiftUI

struct StatusBadge: View {
    var status: MapStatus

    var body: some View {
        HStack {
            Image(systemName: status.isActive ? "location.fill" : "location.slash")
                .font(.headline)
                .foregroundStyle(status.isActive ? Color.green : Color.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(status.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }
}
