//
//  RaindropCollection.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import Foundation
import SwiftData

@Model
final class RaindropCollection {
    @Attribute(.unique) var id: Int
    var title: String
    var count: Int
    var cover: String
    var color: String
    var parentID: Int?
    var sortOrder: Int
    var view: String  // list, simple, grid, masonry
    var isPublic: Bool
    var expanded: Bool
    var lastUpdate: Date
    
    init(
        id: Int,
        title: String,
        count: Int = 0,
        cover: String = "",
        color: String = "",
        parentID: Int? = nil,
        sortOrder: Int = 0,
        view: String = "list",
        isPublic: Bool = false,
        expanded: Bool = true,
        lastUpdate: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.count = count
        self.cover = cover
        self.color = color
        self.parentID = parentID
        self.sortOrder = sortOrder
        self.view = view
        self.isPublic = isPublic
        self.expanded = expanded
        self.lastUpdate = lastUpdate
    }
}

// System collection IDs
extension RaindropCollection {
    static let unsortedID = -1
    static let trashID = -99
}
