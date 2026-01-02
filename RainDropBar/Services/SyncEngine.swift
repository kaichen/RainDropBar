//
//  SyncEngine.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import Foundation
import SwiftData

actor SyncEngine {
    private let container: ModelContainer
    
    init(container: ModelContainer) {
        self.container = container
        debugLog(.sync, "SyncEngine initialized")
    }
    
    func syncCollections(_ responses: [CollectionResponse]) throws {
        let context = ModelContext(container)
        debugLog(.sync, "SyncEngine: syncing \(responses.count) collections")
        try syncCollectionsInternal(responses, in: context)
        try context.save()
    }
    
    func applyRaindropPage(
        _ raindrops: [RaindropResponse],
        existingIndex: inout [Int: Raindrop]
    ) throws {
        let context = ModelContext(container)
        
        if existingIndex.isEmpty {
            let existing = try context.fetch(FetchDescriptor<Raindrop>())
            existingIndex = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
            debugLog(.sync, "SyncEngine: built index with \(existingIndex.count) existing raindrops")
        }
        
        try applyRaindrops(raindrops, index: &existingIndex, in: context)
        try context.save()
    }
    
    func getRaindropCount() throws -> Int {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Raindrop>()
        return try context.fetchCount(descriptor)
    }
    
    func getMaxLastUpdate() throws -> Date? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Raindrop>(sortBy: [SortDescriptor(\.lastUpdate, order: .reverse)])
        descriptor.fetchLimit = 1
        let results = try context.fetch(descriptor)
        return results.first?.lastUpdate
    }
    
    private func syncCollectionsInternal(_ responses: [CollectionResponse], in context: ModelContext) throws {
        let existingCollections = try context.fetch(FetchDescriptor<RaindropCollection>())
        let existingByID = Dictionary(uniqueKeysWithValues: existingCollections.map { ($0.id, $0) })
        
        let remoteIDs = Set(responses.map { $0.id })
        var inserted = 0
        var updated = 0
        
        for response in responses {
            if let existing = existingByID[response.id] {
                existing.title = response.title
                existing.count = response.count
                existing.cover = response.cover.first ?? ""
                existing.color = response.color ?? ""
                existing.parentID = response.parent?.id
                existing.sortOrder = response.sort
                existing.view = response.view
                existing.isPublic = response.public
                existing.expanded = response.expanded
                existing.lastUpdate = response.lastUpdate
                updated += 1
            } else {
                let collection = RaindropCollection(
                    id: response.id,
                    title: response.title,
                    count: response.count,
                    cover: response.cover.first ?? "",
                    color: response.color ?? "",
                    parentID: response.parent?.id,
                    sortOrder: response.sort,
                    view: response.view,
                    isPublic: response.public,
                    expanded: response.expanded,
                    lastUpdate: response.lastUpdate
                )
                context.insert(collection)
                inserted += 1
            }
        }
        
        var deleted = 0
        for existing in existingCollections {
            if !remoteIDs.contains(existing.id) {
                context.delete(existing)
                deleted += 1
            }
        }
        
        debugLog(.swiftdata, "Collections: \(inserted) inserted, \(updated) updated, \(deleted) deleted")
    }
    
    private func applyRaindrops(
        _ responses: [RaindropResponse],
        index: inout [Int: Raindrop],
        in context: ModelContext
    ) throws {
        var inserted = 0
        var updated = 0
        
        for response in responses {
            if let existing = index[response.id] {
                if response.lastUpdate > existing.lastUpdate {
                    existing.title = response.title
                    existing.link = response.link
                    existing.excerpt = response.excerpt
                    existing.note = response.note
                    existing.domain = response.domain
                    existing.cover = response.cover
                    existing.type = response.type
                    existing.tags = response.tags
                    existing.important = response.important
                    existing.collectionID = response.collection.id
                    existing.created = response.created
                    existing.lastUpdate = response.lastUpdate
                    updated += 1
                }
            } else {
                let raindrop = Raindrop(
                    id: response.id,
                    title: response.title,
                    link: response.link,
                    excerpt: response.excerpt,
                    note: response.note,
                    domain: response.domain,
                    cover: response.cover,
                    type: response.type,
                    tags: response.tags,
                    important: response.important,
                    collectionID: response.collection.id,
                    created: response.created,
                    lastUpdate: response.lastUpdate
                )
                context.insert(raindrop)
                index[response.id] = raindrop
                inserted += 1
            }
        }
        
        debugLog(.swiftdata, "Raindrops page: \(inserted) inserted, \(updated) updated")
    }
}
