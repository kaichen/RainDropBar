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
    var onOpen: (() -> Void)?
    
    private var hasMetadata: Bool {
        collectionTitle != nil || !raindrop.tags.isEmpty
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: raindrop.important ? "star.fill" : TypeIcon.systemName(for: raindrop.type))
                .foregroundStyle(raindrop.important ? .yellow : .secondary)
                .font(.system(size: 14))
                .frame(width: 20, height: 20)
                .padding(.top, 1)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(raindrop.title)
                    .lineLimit(1)
                    .font(.body)
                
                Text(raindrop.domain)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if hasMetadata {
                    HStack(spacing: 6) {
                        if let collection = collectionTitle {
                            Label(collection, systemImage: "folder")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                                .lineLimit(1)
                        }
                        
                        ForEach(raindrop.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.1), in: Capsule())
                                .lineLimit(1)
                        }
                        
                        if raindrop.tags.count > 3 {
                            Text("+\(raindrop.tags.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            openURL()
        }
    }
    
    private func openURL() {
        guard let url = URL(string: raindrop.link),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return
        }
        
        onOpen?()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSWorkspace.shared.open(url)
        }
    }
}
