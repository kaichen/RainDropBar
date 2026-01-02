//
//  RaindropRow.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import SwiftUI
import SwiftData

struct RaindropRow: View {
    let raindrop: Raindrop
    let collectionTitle: String?
    
    var body: some View {
        HStack(spacing: 10) {
            // Type icon
            Image(systemName: raindrop.important ? "star.fill" : TypeIcon.systemName(for: raindrop.type))
                .foregroundStyle(raindrop.important ? .yellow : .secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                // Title
                Text(raindrop.title)
                    .lineLimit(1)
                    .font(.body)
                
                // Subtitle: domain · collection
                HStack(spacing: 4) {
                    Text(raindrop.domain)
                        .lineLimit(1)
                    
                    if let collection = collectionTitle {
                        Text("·")
                        Text(collection)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            openURL()
        }
    }
    
    private func openURL() {
        guard let url = URL(string: raindrop.link) else { return }
        NSWorkspace.shared.open(url)
    }
}
